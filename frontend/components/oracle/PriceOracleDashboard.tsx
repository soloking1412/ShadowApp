'use client';
import { useState } from 'react';
import { useAccount } from 'wagmi';
import {
  useGetRegisteredAssets,
  useGetLatestPrice,
  useGetAggregatedPrice,
  useIsPriceStale,
  useRegisterPriceFeed,
  useAddBackupFeed,
} from '@/hooks/contracts/usePriceOracle';

type Tab = 'glte' | 'feeds' | 'lookup' | 'admin';

const tc = (a: boolean) =>
  a ? 'px-4 py-2 rounded-t text-sm font-medium bg-indigo-600 text-white'
    : 'px-4 py-2 rounded-t text-sm font-medium text-gray-400 hover:text-white';

// GLTE variables that map to PriceOracleAggregator feeds
const GLTE_VARS = [
  { symbol: 'χ (amplification)',    key: 'chi',     desc: 'Capital amplification factor — stored in HFTEngine',           value: '75,834.34%', source: 'HFTEngine param', color: 'text-yellow-400' },
  { symbol: 'γ (yuan parity)',       key: 'gamma',   desc: 'OICD/CNY parity coefficient — 1 yuan ≅ 1 OICD',               value: '1.0000',      source: 'OICDTreasury',  color: 'text-green-400'  },
  { symbol: 'LIBOR / SOFR',          key: 'libor',   desc: 'London/Secured Overnight Financing Rate benchmark',            value: '5.33%',       source: 'Chainlink feed', color: 'text-blue-400'   },
  { symbol: 'σ_VIX(Oil)',            key: 'vix',     desc: 'CBOE Oil VIX — commodity volatility trigger for L_out shift', value: '28.4',        source: 'Pyth Network',  color: 'text-red-400'    },
  { symbol: 'V_Delhi (NSE VIX)',     key: 'delhi',   desc: 'Indian NSE volatility index — Asia equity risk gauge',         value: '13.8',        source: 'OZF relayer',   color: 'text-purple-400' },
  { symbol: 'E_Malaysia (Bursa)',    key: 'malaysia', desc: 'Malaysia Bursa expected inflow projection',                   value: '1.024×',      source: 'OZF relayer',   color: 'text-teal-400'   },
  { symbol: 'F_Tadawul (Saudi)',     key: 'tadawul', desc: 'Saudi Tadawul futures factor — GCC corridor weight',           value: '12,301.5',    source: 'OZF relayer',   color: 'text-orange-400' },
  { symbol: 'B_Tirana (Albania)',    key: 'tirana',  desc: 'Tirana Stock Exchange bond index — SEZ bond yield signal',     value: '1,842.7',     source: 'OZF relayer',   color: 'text-pink-400'   },
  { symbol: 'B_BR (Brazil B3)',      key: 'b3',      desc: 'Brazil B3 bourse weighting for LatAm corridor allocation',    value: '124,215',     source: 'OZF relayer',   color: 'text-cyan-400'   },
];

const INFLOW_FORMULA  = 'L_in  = W_g × χ( r_jcp^(38,34,34%) · LIBOR ) · ( V_Delhi ~ E_Malaysia )';
const OUTFLOW_FORMULA = 'L_out = W_t/E[L_in] × r_(cc)^(75,834.34%) × OICD/197#$ + [ B_Tirana + (F_Tadawul × σ_VIX(Oil)) ] × γ';

function fmtPrice(raw: unknown): string {
  if (raw === undefined || raw === null) return '—';
  try {
    const n = Number(raw);
    if (Number.isNaN(n)) return '—';
    return (n / 1e8).toLocaleString('en-US', { maximumFractionDigits: 6 });
  } catch { return '—'; }
}

function isHex(s: string): s is `0x${string}` {
  return /^0x[0-9a-fA-F]{40}$/.test(s);
}

export default function PriceOracleDashboard() {
  const { isConnected } = useAccount();
  const [tab, setTab] = useState<Tab>('glte');

  // Feed registry
  const { data: registeredAssets } = useGetRegisteredAssets();

  // Lookup state
  const [lookupAddr, setLookupAddr] = useState('');
  const validAddr = isHex(lookupAddr) ? lookupAddr : undefined;
  const { data: latestPrice }     = useGetLatestPrice(validAddr);
  const { data: aggregatedPrice } = useGetAggregatedPrice(validAddr);
  const { data: isStale }         = useIsPriceStale(validAddr);

  // Register feed form
  const [regAsset, setRegAsset]         = useState('');
  const [regFeed, setRegFeed]           = useState('');
  const [regHeartbeat, setRegHeartbeat] = useState('3600');
  const { registerFeed, isPending: regPending, isSuccess: regDone } = useRegisterPriceFeed();

  // Backup feed form
  const [bkpAsset, setBkpAsset] = useState('');
  const [bkpFeed, setBkpFeed]   = useState('');
  const { addBackupFeed, isPending: bkpPending, isSuccess: bkpDone } = useAddBackupFeed();

  const feeds = (registeredAssets as `0x${string}`[] | undefined) ?? [];

  const TABS: { id: Tab; label: string }[] = [
    { id: 'glte',  label: 'GLTE Variables' },
    { id: 'feeds', label: 'Feed Registry'  },
    { id: 'lookup', label: 'Price Lookup'  },
    { id: 'admin', label: 'Admin'          },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Price Oracle Aggregator</h2>
        <p className="text-gray-400 mt-1 text-sm">
          Multi-source price aggregation feeding the GLTE · Chainlink + Pyth + OZF relayers
        </p>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 flex-wrap border-b border-white/10 pb-2">
        {TABS.map(t => <button key={t.id} onClick={() => setTab(t.id)} className={tc(tab === t.id)}>{t.label}</button>)}
      </div>

      {/* GLTE Variables */}
      {tab === 'glte' && (
        <div className="space-y-6">
          {/* Formula display */}
          <div className="bg-white/5 rounded-xl p-5 space-y-3">
            <p className="text-xs text-indigo-400 font-semibold uppercase tracking-wider">Global Liquidity Transformation Equation</p>
            <div className="space-y-2">
              <p className="text-xs text-gray-500 font-medium">INFLOW</p>
              <code className="block text-sm text-yellow-300 font-mono bg-black/30 rounded p-3 overflow-x-auto whitespace-nowrap">{INFLOW_FORMULA}</code>
              <p className="text-xs text-gray-500 font-medium mt-2">OUTFLOW</p>
              <code className="block text-sm text-green-300 font-mono bg-black/30 rounded p-3 overflow-x-auto whitespace-nowrap">{OUTFLOW_FORMULA}</code>
            </div>
          </div>

          {/* Variables grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {GLTE_VARS.map(v => (
              <div key={v.key} className="bg-white/5 rounded-xl p-4 border border-white/5">
                <div className="flex items-start justify-between mb-2">
                  <code className={`text-sm font-bold font-mono ${v.color}`}>{v.symbol}</code>
                  <span className="text-xs text-gray-500 bg-black/20 px-2 py-0.5 rounded">{v.source}</span>
                </div>
                <p className="text-xl font-bold text-white mb-1">{v.value}</p>
                <p className="text-xs text-gray-500">{v.desc}</p>
              </div>
            ))}
          </div>

          {/* Phase label */}
          <div className="bg-indigo-500/10 border border-indigo-500/20 rounded-lg p-4 text-sm text-indigo-300">
            <p className="font-semibold mb-1">Phase 2A Note</p>
            <p className="text-xs text-indigo-400">
              Values above are Phase 2A targets. On local Anvil, the PriceOracleAggregator stores submitted prices.
              Production feeds (Chainlink, Pyth, OZF relayer) activate on Arbitrum mainnet.
            </p>
          </div>
        </div>
      )}

      {/* Feed Registry */}
      {tab === 'feeds' && (
        <div className="space-y-4">
          <div className="bg-white/5 rounded-xl p-5">
            <h3 className="text-white font-semibold mb-4">Registered Asset Feeds ({feeds.length})</h3>
            {feeds.length === 0 ? (
              <div className="text-center py-8">
                <p className="text-4xl mb-3">📡</p>
                <p className="text-gray-400 text-sm">No feeds registered yet.</p>
                <p className="text-gray-500 text-xs mt-1">Register price feeds via the Admin tab (owner only).</p>
              </div>
            ) : (
              <div className="space-y-2">
                {feeds.map((addr, i) => (
                  <div key={addr} className="flex items-center gap-3 bg-black/20 rounded-lg p-3">
                    <span className="text-xs text-gray-500 w-6">#{i + 1}</span>
                    <code className="text-xs text-indigo-300 font-mono flex-1 truncate">{addr}</code>
                    <button
                      onClick={() => { setLookupAddr(addr); setTab('lookup'); }}
                      className="text-xs text-indigo-400 hover:text-indigo-300 px-2 py-0.5 rounded border border-indigo-500/30"
                    >
                      Lookup →
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Data source overview */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {[
              { name: 'Chainlink',   color: 'blue',   feeds: 'ETH/USD, BTC/USD, EUR/USD, major FX pairs', status: 'Production' },
              { name: 'Pyth Network', color: 'purple', feeds: 'VIX Oil, equity indices, sub-second updates', status: 'Production' },
              { name: 'OZF Relayer', color: 'yellow',  feeds: 'Tirana, Tadawul, B3, NSE/BSE, Bursa Malaysia', status: 'Phase 2A' },
            ].map(s => (
              <div key={s.name} className={`bg-${s.color}-500/10 border border-${s.color}-500/20 rounded-xl p-4`}>
                <div className="flex items-center justify-between mb-2">
                  <p className={`text-${s.color}-300 font-semibold text-sm`}>{s.name}</p>
                  <span className={`text-xs px-2 py-0.5 rounded-full ${s.status === 'Production' ? 'bg-green-500/20 text-green-400' : 'bg-yellow-500/20 text-yellow-400'}`}>
                    {s.status}
                  </span>
                </div>
                <p className="text-xs text-gray-400">{s.feeds}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Price Lookup */}
      {tab === 'lookup' && (
        <div className="space-y-4 max-w-lg">
          <div className="bg-white/5 rounded-xl p-5 space-y-4">
            <h3 className="text-white font-semibold">Look Up Asset Price</h3>
            <input
              className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500 font-mono"
              placeholder="Asset contract address (0x...)"
              value={lookupAddr}
              onChange={e => setLookupAddr(e.target.value.trim())}
            />
            {validAddr && (
              <div className="space-y-3 pt-2">
                <div className="flex justify-between py-2 border-b border-white/5">
                  <span className="text-gray-400 text-sm">Latest Price</span>
                  <span className="text-white font-bold">{fmtPrice(latestPrice)}</span>
                </div>
                <div className="flex justify-between py-2 border-b border-white/5">
                  <span className="text-gray-400 text-sm">Aggregated Price</span>
                  <span className="text-white font-bold">{fmtPrice(aggregatedPrice)}</span>
                </div>
                <div className="flex justify-between py-2">
                  <span className="text-gray-400 text-sm">Staleness</span>
                  <span className={`text-sm font-semibold ${isStale ? 'text-red-400' : 'text-green-400'}`}>
                    {isStale === undefined ? '—' : isStale ? '⚠ Stale' : '✓ Fresh'}
                  </span>
                </div>
              </div>
            )}
            {lookupAddr && !validAddr && (
              <p className="text-xs text-red-400">Enter a valid 0x... address (42 chars)</p>
            )}
          </div>
        </div>
      )}

      {/* Admin */}
      {tab === 'admin' && (
        <div className="space-y-6 max-w-md">
          {!isConnected && (
            <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-3 text-sm text-yellow-400">
              Connect wallet to register feeds (owner only)
            </div>
          )}

          {/* Register primary feed */}
          <div className="bg-white/5 rounded-xl p-5 space-y-3">
            <h3 className="text-white font-semibold">Register Price Feed</h3>
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500 font-mono"
              placeholder="Asset contract address" value={regAsset} onChange={e => setRegAsset(e.target.value)} />
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500 font-mono"
              placeholder="Chainlink / Pyth feed address" value={regFeed} onChange={e => setRegFeed(e.target.value)} />
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500"
              placeholder="Heartbeat (seconds, default 3600)" value={regHeartbeat} onChange={e => setRegHeartbeat(e.target.value)} />
            <button
              onClick={() => {
                if (isHex(regAsset) && isHex(regFeed)) {
                  const hb = (() => { try { return BigInt(regHeartbeat || '3600'); } catch { return 3600n; } })();
                  registerFeed(regAsset, regFeed, hb);
                }
              }}
              disabled={!isConnected || regPending || !isHex(regAsset) || !isHex(regFeed)}
              className="w-full bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium"
            >
              {regPending ? 'Registering…' : regDone ? '✓ Registered' : 'Register Feed'}
            </button>
          </div>

          {/* Add backup feed */}
          <div className="bg-white/5 rounded-xl p-5 space-y-3">
            <h3 className="text-white font-semibold">Add Backup Feed</h3>
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500 font-mono"
              placeholder="Asset contract address" value={bkpAsset} onChange={e => setBkpAsset(e.target.value)} />
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500 font-mono"
              placeholder="Backup feed address" value={bkpFeed} onChange={e => setBkpFeed(e.target.value)} />
            <button
              onClick={() => { if (isHex(bkpAsset) && isHex(bkpFeed)) addBackupFeed(bkpAsset, bkpFeed); }}
              disabled={!isConnected || bkpPending || !isHex(bkpAsset) || !isHex(bkpFeed)}
              className="w-full bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium"
            >
              {bkpPending ? 'Adding…' : bkpDone ? '✓ Added' : 'Add Backup Feed'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
