'use client';
import { useState, useEffect } from 'react';
import { useAccount } from 'wagmi';
import {
  useSGMXTotalSupply, useSGMXTotalInvestors, useSGMXCirculating, useSGMXOICDPairRate,
  useSGMXTransfersEnabled, useSGMXCapTable, useSGMXDividendCounter,
  useSGMXInvestor, useSGMXRegistered, useSGMXWhitelisted, useSGMXDividend,
  useSGMXRegisterInvestor, useSGMXClaimDividend,
} from '@/hooks/contracts/useSGMXToken';

type Tab = 'overview' | 'register' | 'dividends' | 'captable' | 'compliance';

const fmt18 = (v: unknown) => {
  if (typeof v !== 'bigint') return '—';
  const n = Number(v) / 1e18;
  if (n >= 1e15) return (n / 1e15).toFixed(2) + 'Q';  // quadrillion
  if (n >= 1e12) return (n / 1e12).toFixed(2) + 'T';
  if (n >= 1e9)  return (n / 1e9).toFixed(2) + 'B';
  if (n >= 1e6)  return (n / 1e6).toFixed(2) + 'M';
  return n.toFixed(4);
};

const SHARE_CLASSES = ['Common', 'Preferred', 'Institutional'] as const;
const JURISDICTIONS = ['GB', 'US', 'AE', 'DE', 'FR', 'GH', 'LK', 'ID', 'CO', 'SA', 'SG', 'JP', 'NG', 'ZA'];

export default function SGMXTokenDashboard() {
  const { address, isConnected } = useAccount();
  const [tab, setTab] = useState<Tab>('overview');

  // Reads
  const { data: totalInvestors }   = useSGMXTotalInvestors();
  const { data: circulating }      = useSGMXCirculating();
  const { data: oicdRate }         = useSGMXOICDPairRate();
  const { data: transfersEnabled } = useSGMXTransfersEnabled();
  const { data: capTable }         = useSGMXCapTable();
  const { data: dividendCounter }  = useSGMXDividendCounter();
  const { data: investor }         = useSGMXInvestor(address);
  const { data: isRegistered }     = useSGMXRegistered(address);
  const { data: isWhitelisted }    = useSGMXWhitelisted(address);

  // Dividend lookup
  const [divLookupId,  setDivLookupId]  = useState('');
  const { data: dividend }              = useSGMXDividend(divLookupId ? BigInt(divLookupId) : 0n);

  // Writes
  const { registerInvestor, isPending: regPending, isSuccess: regDone, error: regErr   } = useSGMXRegisterInvestor();
  const { claimDividend,    isPending: claimPending,                   error: claimErr } = useSGMXClaimDividend();

  // Tx feedback
  const [txError,   setTxError]   = useState<string | null>(null);
  const [txSuccess, setTxSuccess] = useState<string | null>(null);

  useEffect(() => {
    const err = regErr ?? claimErr;
    if (!err) return;
    const msg = (err as { shortMessage?: string })?.shortMessage ?? err.message ?? 'Transaction failed';
    setTxError(msg.length > 120 ? msg.slice(0, 120) + '…' : msg);
    const t = setTimeout(() => setTxError(null), 7000);
    return () => clearTimeout(t);
  }, [regErr, claimErr]);

  useEffect(() => {
    if (!regDone) return;
    setTxSuccess('Investor registered successfully');
    const t = setTimeout(() => setTxSuccess(null), 5000);
    return () => clearTimeout(t);
  }, [regDone]);

  // Form
  const [jurisdiction, setJurisdiction] = useState('GB');
  const [shareClass,   setShareClass]   = useState('0');
  const [claimId,      setClaimId]      = useState('');

  const cap = capTable as { founders?: bigint; pub?: bigint; reserved?: bigint; circulating?: bigint } | undefined;
  const total = Number(250_000_000_000_000_000n);
  const foundersPct  = cap ? ((Number(cap.founders  ?? 0n) / 1e18) / 250_000_000_000_000_000 * 100).toFixed(1) : '40.0';
  const publicPct    = cap ? ((Number(cap.pub       ?? 0n) / 1e18) / 250_000_000_000_000_000 * 100).toFixed(1) : '20.0';
  const reservedPct  = cap ? ((Number(cap.reserved  ?? 0n) / 1e18) / 250_000_000_000_000_000 * 100).toFixed(1) : '40.0';

  const tc = (active: boolean) =>
    `px-4 py-2 rounded-lg text-sm font-medium transition-all ${active ? 'bg-blue-600 text-white shadow-lg' : 'text-gray-400 hover:bg-white/5 hover:text-white'}`;

  const inv = investor as { balance?: bigint; kycVerified?: boolean; accredited?: boolean; jurisdiction?: string; investmentOICD?: bigint; shareClass?: bigint; registeredAt?: bigint; dividendsAccrued?: bigint } | undefined;
  const div = dividend as { id?: bigint; amountPerShare?: bigint; snapshotAt?: bigint; totalDistributed?: bigint; declared?: boolean } | undefined;

  return (
    <div className="space-y-6">
      {/* Tx feedback */}
      {txError && (
        <div className="flex items-start gap-3 px-4 py-3 bg-red-900/40 border border-red-500/40 rounded-xl text-sm">
          <span className="text-red-400 text-base shrink-0 mt-0.5">✕</span>
          <div>
            <p className="font-semibold text-red-300">Transaction failed</p>
            <p className="text-red-400/80 text-xs mt-0.5">{txError}</p>
            {txError.includes('connection') || txError.includes('refused') ? (
              <p className="text-red-400/60 text-[11px] mt-1">Is Anvil running? Run: <code className="bg-red-900/40 px-1 rounded">docker compose up --force-recreate deployer</code></p>
            ) : null}
          </div>
          <button onClick={() => setTxError(null)} className="ml-auto text-red-500 hover:text-red-300 text-xs shrink-0">dismiss</button>
        </div>
      )}
      {txSuccess && (
        <div className="flex items-center gap-3 px-4 py-3 bg-green-900/30 border border-green-500/30 rounded-xl text-sm">
          <span className="text-green-400 text-base shrink-0">✓</span>
          <p className="text-green-300 font-semibold">{txSuccess}</p>
        </div>
      )}

      {/* Header */}
      <div className="glass rounded-xl p-6">
        <div className="flex items-start justify-between">
          <div>
            <div className="flex items-center gap-3 mb-1">
              <div className="w-10 h-10 bg-gradient-to-br from-blue-500 to-cyan-600 rounded-xl flex items-center justify-center text-xl font-bold text-white">SX</div>
              <div>
                <h2 className="text-2xl font-bold text-white">SGMX Token <span className="text-blue-400">$SGMX</span></h2>
                <p className="text-xs text-gray-500">Security Token · Samuel Global Market Xchange Inc. · Paired to OICD</p>
              </div>
            </div>
            <p className="text-sm text-gray-400 max-w-2xl">A regulated security token representing equity in Samuel Global Market Xchange Inc. Transfer-restricted pending KYC/accreditation. Dividends paid in OICD. 250 Quadrillion total supply.</p>
          </div>
          <div className="text-right space-y-1">
            <div className="text-xs text-gray-500">1 SGMX =</div>
            <div className="text-lg font-bold text-blue-400 font-mono">
              {typeof oicdRate === 'bigint' ? (Number(oicdRate) / 1e18).toFixed(6) : '—'} OICD
            </div>
            <div className={`text-[10px] px-2 py-0.5 rounded font-semibold ${transfersEnabled ? 'bg-green-500/20 text-green-400' : 'bg-yellow-500/20 text-yellow-400'}`}>
              Transfers {transfersEnabled ? 'Enabled' : 'Locked'}
            </div>
          </div>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-5 gap-3 mt-4">
          {[
            { label: 'Total Supply',   value: '250 Quadrillion', icon: '🪙' },
            { label: 'Circulating',    value: fmt18(circulating), icon: '🔄' },
            { label: 'Investors',      value: String(totalInvestors ?? 0), icon: '👤' },
            { label: 'Dividends',      value: String(dividendCounter ?? 0), icon: '💰' },
            { label: 'KYC Required',   value: 'Yes',             icon: '🛡️' },
          ].map(({ label, value, icon }) => (
            <div key={label} className="bg-white/5 border border-white/5 rounded-xl p-3 text-center">
              <div className="text-lg mb-1">{icon}</div>
              <div className="text-white font-bold text-sm">{value}</div>
              <div className="text-gray-500 text-[10px]">{label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Status banner */}
      {isConnected && (
        <div className={`glass rounded-xl p-4 border flex items-center gap-3 ${isWhitelisted ? 'border-green-500/30' : 'border-yellow-500/30'}`}>
          <span className="text-2xl">{isWhitelisted ? '✅' : '⏳'}</span>
          <div>
            <p className="text-white font-semibold text-sm">{isWhitelisted ? 'KYC Verified — Accredited Investor' : isRegistered ? 'Pending KYC Verification' : 'Not Registered'}</p>
            <p className="text-gray-400 text-xs">{isWhitelisted ? 'You may receive shares and claim dividends' : 'Register and complete KYC to access SGMX shares'}</p>
          </div>
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-2 flex-wrap">
        {(['overview','register','dividends','captable','compliance'] as Tab[]).map(t => (
          <button key={t} onClick={() => setTab(t)} className={tc(tab === t)}>
            {t === 'captable' ? 'Cap Table' : t.charAt(0).toUpperCase() + t.slice(1)}
          </button>
        ))}
      </div>

      {/* ── Overview ── */}
      {tab === 'overview' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="glass rounded-xl p-5 space-y-3">
            <h3 className="text-white font-bold">About SGMX</h3>
            {[
              { icon: '🏢', title: 'Security Token',        desc: 'Represents equity ownership in Samuel Global Market Xchange Inc.' },
              { icon: '💰', title: 'Dividend Rights',       desc: 'Proportional dividends declared in OICD by the board of directors' },
              { icon: '🛡️', title: 'KYC / Accreditation', desc: 'SEC-equivalent OZF accreditation required. Verified by owner.' },
              { icon: '🔒', title: 'Transfer Restrictions', desc: 'Whitelist-gated transfers. Only verified investors may hold SGMX.' },
              { icon: '📋', title: 'Corporate Actions',     desc: 'Splits, rights issues, and mergers filed on-chain as corporate actions.' },
            ].map(({ icon, title, desc }) => (
              <div key={title} className="flex gap-3">
                <span className="text-lg shrink-0">{icon}</span>
                <div><p className="text-sm font-medium text-white">{title}</p><p className="text-xs text-gray-500">{desc}</p></div>
              </div>
            ))}
          </div>

          <div className="glass rounded-xl p-5 space-y-3">
            <h3 className="text-white font-bold">My Holdings</h3>
            {isConnected && inv?.balance !== undefined ? (
              <div className="space-y-2">
                {[
                  { label: 'SGMX Balance',     value: fmt18(inv?.balance),         color: 'text-blue-400' },
                  { label: 'Share Class',      value: SHARE_CLASSES[Number(inv?.shareClass ?? 0n)], color: 'text-white' },
                  { label: 'Jurisdiction',     value: inv?.jurisdiction || '—',    color: 'text-white' },
                  { label: 'OICD Invested',    value: fmt18(inv?.investmentOICD) + ' OICD', color: 'text-cyan-400' },
                  { label: 'Dividends Earned', value: fmt18(inv?.dividendsAccrued) + ' OICD', color: 'text-green-400' },
                  { label: 'KYC Verified',     value: inv?.kycVerified ? '✓ Yes' : '✗ Pending', color: inv?.kycVerified ? 'text-green-400' : 'text-yellow-400' },
                ].map(({ label, value, color }) => (
                  <div key={label} className="flex justify-between items-center p-2.5 bg-white/5 rounded-lg">
                    <span className="text-xs text-gray-400">{label}</span>
                    <span className={`text-sm font-mono font-bold ${color}`}>{value}</span>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-gray-500 text-sm">Connect wallet to view holdings</p>
            )}
          </div>
        </div>
      )}

      {/* ── Register ── */}
      {tab === 'register' && (
        <div className="glass rounded-xl p-5 max-w-md space-y-4">
          <h3 className="text-white font-bold">Register as SGMX Investor</h3>
          <div className="bg-blue-500/5 border border-blue-500/20 rounded-lg p-3 text-xs text-gray-400">
            <p className="font-semibold text-blue-400 mb-1">Registration Process</p>
            <ol className="space-y-1 list-decimal pl-4">
              <li>Submit registration with your jurisdiction</li>
              <li>KYC/AML verification by SGMX compliance team</li>
              <li>Accreditation check (net worth / income thresholds)</li>
              <li>Whitelist approval — shares can be issued</li>
            </ol>
          </div>
          <div>
            <label className="text-xs text-gray-500 mb-1 block">Jurisdiction (ISO Country Code)</label>
            <select value={jurisdiction} onChange={e => setJurisdiction(e.target.value)}
              className="w-full bg-white/5 border border-white/10 rounded px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500">
              {JURISDICTIONS.map(j => <option key={j} value={j} className="bg-gray-900">{j}</option>)}
            </select>
          </div>
          <div>
            <label className="text-xs text-gray-500 mb-1 block">Share Class</label>
            <select value={shareClass} onChange={e => setShareClass(e.target.value)}
              className="w-full bg-white/5 border border-white/10 rounded px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500">
              {SHARE_CLASSES.map((c, i) => <option key={c} value={i} className="bg-gray-900">{c}</option>)}
            </select>
          </div>
          <button onClick={() => registerInvestor(jurisdiction, BigInt(shareClass))}
            disabled={!isConnected || !!isRegistered || regPending}
            className="w-full bg-blue-600 hover:bg-blue-500 disabled:opacity-40 text-white py-2 rounded-lg text-sm font-bold transition-all">
            {regPending ? 'Registering…' : regDone ? '✓ Registered — Pending KYC' : isRegistered ? 'Already Registered' : 'Register as Investor'}
          </button>
        </div>
      )}

      {/* ── Dividends ── */}
      {tab === 'dividends' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="glass rounded-xl p-5 space-y-4">
            <h3 className="text-white font-bold">Claim Dividend</h3>
            <div className="bg-green-500/5 border border-green-500/20 rounded-lg p-3 text-xs">
              <div className="flex justify-between mb-1"><span className="text-gray-400">Dividends Declared</span><span className="text-white">{String(dividendCounter ?? 0)}</span></div>
              <div className="flex justify-between"><span className="text-gray-400">Paid in</span><span className="text-cyan-400">OICD</span></div>
            </div>
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Dividend ID</label>
              <input value={claimId} onChange={e => setClaimId(e.target.value)} placeholder="e.g. 1"
                className="w-full bg-white/5 border border-white/10 rounded px-3 py-2 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-blue-500" />
            </div>
            <button onClick={() => claimDividend(BigInt(claimId || '0'))}
              disabled={!isConnected || !isRegistered || claimPending || !claimId}
              className="w-full bg-green-600 hover:bg-green-500 disabled:opacity-40 text-white py-2 rounded-lg text-sm font-bold transition-all">
              {claimPending ? 'Claiming…' : 'Claim Dividend'}
            </button>
          </div>

          <div className="glass rounded-xl p-5 space-y-3">
            <h3 className="text-white font-bold">Lookup Dividend</h3>
            <input value={divLookupId} onChange={e => setDivLookupId(e.target.value)} placeholder="Dividend ID"
              className="w-full bg-white/5 border border-white/10 rounded px-3 py-2 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-blue-500" />
            {!!div?.declared && (
              <div className="bg-white/5 rounded-lg p-3 space-y-2 text-xs">
                <div className="flex justify-between"><span className="text-gray-400">Dividend #</span><span className="text-white font-mono">{String(div.id ?? 0n)}</span></div>
                <div className="flex justify-between"><span className="text-gray-400">Per Share (OICD)</span><span className="text-green-400 font-mono">{(Number(div.amountPerShare ?? 0n) / 1e18).toFixed(8)}</span></div>
                <div className="flex justify-between"><span className="text-gray-400">Total Distributed</span><span className="text-white">{fmt18(div.totalDistributed)} OICD</span></div>
                <div className="flex justify-between"><span className="text-gray-400">Status</span><span className="text-blue-400">{div.declared ? 'Declared' : '—'}</span></div>
              </div>
            )}
            <div className="text-[10px] text-gray-600">Dividends are proportional to your SGMX balance at snapshot time</div>
          </div>
        </div>
      )}

      {/* ── Cap Table ── */}
      {tab === 'captable' && (
        <div className="glass rounded-xl p-6 space-y-5">
          <h3 className="text-white font-bold">SGMX Cap Table — Samuel Global Market Xchange Inc.</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {[
              { label: 'Founders / Team',    pct: foundersPct,  color: 'bg-purple-500', amount: fmt18(cap?.founders) },
              { label: 'Public Float',        pct: publicPct,    color: 'bg-blue-500',   amount: fmt18(cap?.pub) },
              { label: 'Reserved / Treasury', pct: reservedPct,  color: 'bg-gray-500',   amount: fmt18(cap?.reserved) },
            ].map(({ label, pct, color, amount }) => (
              <div key={label} className="bg-white/5 rounded-xl p-4 space-y-3">
                <div className="flex items-center gap-2">
                  <div className={`w-3 h-3 rounded-full ${color}`} />
                  <p className="text-sm font-semibold text-white">{label}</p>
                </div>
                <p className="text-2xl font-bold text-white">{pct}%</p>
                <p className="text-xs text-gray-500">{amount} SGMX</p>
                <div className="h-2 bg-white/5 rounded-full overflow-hidden">
                  <div className={`h-full rounded-full ${color}`} style={{ width: `${pct}%` }} />
                </div>
              </div>
            ))}
          </div>
          <div className="bg-white/5 rounded-lg p-4 text-xs space-y-1 text-gray-400">
            <p><span className="text-white font-semibold">Total Supply:</span> 250,000,000,000,000,000 SGMX (250 Quadrillion)</p>
            <p><span className="text-white font-semibold">Circulating:</span> {fmt18(circulating)} SGMX (20% public float)</p>
            <p><span className="text-white font-semibold">Transfer Status:</span> {transfersEnabled ? 'Enabled — secondary market open' : 'Locked — private placement phase'}</p>
            <p><span className="text-white font-semibold">Issuer:</span> Samuel Global Market Xchange Inc. (SGMX Inc.)</p>
          </div>
        </div>
      )}

      {/* ── Compliance ── */}
      {tab === 'compliance' && (
        <div className="glass rounded-xl p-6 space-y-4">
          <h3 className="text-white font-bold">Compliance & Regulatory Framework</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {[
              { icon: '🛡️', title: 'KYC/AML',         desc: 'Full Know Your Customer and Anti-Money Laundering compliance. Verified by SGMX Inc. compliance team.' },
              { icon: '📋', title: 'Accreditation',    desc: 'SEC Rule 506(b) equivalent OZF standard. Net worth > $1M or income > $200K/yr required for institutional class.' },
              { icon: '🌍', title: 'Jurisdiction',     desc: '14 supported jurisdictions: GB, US, AE, DE, FR, GH, LK, ID, CO, SA, SG, JP, NG, ZA. More pending.' },
              { icon: '🔒', title: 'Transfer Gate',    desc: 'Whitelist-only transfers. P2P secondary market opens when owner enables transfersEnabled flag.' },
              { icon: '💼', title: 'Corporate Actions', desc: 'Splits, rights issues, mergers, buybacks filed as on-chain CorporateAction records with full audit trail.' },
              { icon: '⚖️', title: 'Governing Law',    desc: 'OZF Security Token Framework v2.0 · Ozhumanill Zayed Federation sovereignty.' },
            ].map(({ icon, title, desc }) => (
              <div key={title} className="bg-white/5 rounded-xl p-4 flex gap-3">
                <span className="text-xl shrink-0">{icon}</span>
                <div><p className="text-sm font-semibold text-white mb-1">{title}</p><p className="text-xs text-gray-400">{desc}</p></div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
