'use client';
import { useState, useEffect } from 'react';
import { useAccount } from 'wagmi';
import {
  useSGMTotalMembers, useSGMTotalStaked, useSGMCirculating, useSGMOICDPairRate,
  useSGMYieldPool, useSGMMember, useSGMRegistered, useSGMPool,
  useSGMRegister, useSGMStake, useSGMUnstake, useSGMClaimYield,
  useSGMCreateProposal, useSGMVote, useSGMExecuteProposal, useSGMDepositToPool,
  useSGMProposal,
} from '@/hooks/contracts/useSGMToken';

type Tab = 'overview' | 'staking' | 'invest' | 'governance' | 'liquidity';

const fmt18 = (v: unknown) => {
  if (typeof v !== 'bigint') return '—';
  const n = Number(v) / 1e18;
  if (n >= 1e9)  return (n / 1e9).toFixed(2) + 'B';
  if (n >= 1e6)  return (n / 1e6).toFixed(2) + 'M';
  if (n >= 1e3)  return (n / 1e3).toFixed(2) + 'K';
  return n.toFixed(4);
};

const fmtRate = (v: unknown) => {
  if (typeof v !== 'bigint') return '—';
  return (Number(v) / 1e18).toFixed(6) + ' OICD';
};

export default function SGMTokenDashboard() {
  const { address, isConnected } = useAccount();
  const [tab, setTab] = useState<Tab>('overview');

  // Reads
  const { data: totalMembers }  = useSGMTotalMembers();
  const { data: totalStaked }   = useSGMTotalStaked();
  const { data: circulating }   = useSGMCirculating();
  const { data: oicdRate }      = useSGMOICDPairRate();
  const { data: yieldPool }     = useSGMYieldPool();
  const { data: member }        = useSGMMember(address);
  const { data: isRegistered }  = useSGMRegistered(address);
  const { data: pool1 }         = useSGMPool(1n);
  const { data: pool2 }         = useSGMPool(2n);
  const { data: pool3 }         = useSGMPool(3n);

  // Governance lookup
  const [lookupId, setLookupId] = useState('');
  const { data: proposal }      = useSGMProposal(lookupId ? BigInt(lookupId) : 0n);

  // Writes
  const { register,    isPending: regPending,   isSuccess: regDone,   error: regErr     } = useSGMRegister();
  const { stake,       isPending: stakePending,  isSuccess: stakeDone, error: stakeErr   } = useSGMStake();
  const { unstake,     isPending: unstakePending,                      error: unstakeErr } = useSGMUnstake();
  const { claimYield,  isPending: yieldPending,  isSuccess: yieldDone, error: yieldErr  } = useSGMClaimYield();
  const { createProposal, isPending: propPending,                      error: propErr   } = useSGMCreateProposal();
  const { vote,           isPending: votePending,                      error: voteErr   } = useSGMVote();
  const { executeProposal, isPending: execPending,                     error: execErr   } = useSGMExecuteProposal();
  const { depositToPool,   isPending: depositPending,                  error: depositErr} = useSGMDepositToPool();

  // Collect latest tx error for display
  const [txError, setTxError] = useState<string | null>(null);
  const [txSuccess, setTxSuccess] = useState<string | null>(null);

  useEffect(() => {
    const err = regErr ?? stakeErr ?? unstakeErr ?? yieldErr ?? propErr ?? voteErr ?? execErr ?? depositErr;
    if (!err) return;
    const msg = (err as { shortMessage?: string })?.shortMessage ?? err.message ?? 'Transaction failed';
    setTxError(msg.length > 120 ? msg.slice(0, 120) + '…' : msg);
    const t = setTimeout(() => setTxError(null), 7000);
    return () => clearTimeout(t);
  }, [regErr, stakeErr, unstakeErr, yieldErr, propErr, voteErr, execErr, depositErr]);

  useEffect(() => {
    const msgs: [boolean, string][] = [
      [regDone,   'Registered as SGM Member'],
      [stakeDone, 'Stake confirmed'],
      [yieldDone, 'Yield claimed'],
    ];
    const done = msgs.find(([ok]) => ok);
    if (!done) return;
    setTxSuccess(done[1]);
    const t = setTimeout(() => setTxSuccess(null), 5000);
    return () => clearTimeout(t);
  }, [regDone, stakeDone, yieldDone]);

  // Form state
  const [stakeAmt,  setStakeAmt]  = useState('');
  const [propTitle, setPropTitle] = useState('');
  const [propDesc,  setPropDesc]  = useState('');
  const [propType,  setPropType]  = useState('governance');
  const [propDays,  setPropDays]  = useState('7');
  const [voteId,    setVoteId]    = useState('');
  const [support,   setSupport]   = useState(true);
  const [poolId,    setPoolId]    = useState('1');
  const [poolAmt,   setPoolAmt]   = useState('');

  const tabs: { id: Tab; label: string; icon: string }[] = [
    { id: 'overview',    label: 'Overview',    icon: '📊' },
    { id: 'staking',     label: 'Staking',     icon: '🔒' },
    { id: 'invest',      label: 'Investment',  icon: '💼' },
    { id: 'governance',  label: 'Governance',  icon: '⚖️' },
    { id: 'liquidity',   label: 'Liquidity',   icon: '💧' },
  ];

  const tc = (active: boolean) =>
    `flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-medium transition-all ${active ? 'bg-purple-600 text-white shadow-lg' : 'text-gray-400 hover:bg-white/5 hover:text-white'}`;

  const pools = [
    { id: 1, data: pool1, name: 'OZF Infrastructure Fund', color: 'blue' },
    { id: 2, data: pool2, name: 'SGM Growth Portfolio',     color: 'green' },
    { id: 3, data: pool3, name: 'OICD Liquidity Pool',      color: 'purple' },
  ];

  return (
    <div className="space-y-6">
      {/* Tx feedback toasts */}
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
              <div className="w-10 h-10 bg-gradient-to-br from-purple-500 to-pink-600 rounded-xl flex items-center justify-center text-xl font-bold text-white">S</div>
              <div>
                <h2 className="text-2xl font-bold text-white">SGM Token <span className="text-purple-400">$SGM</span></h2>
                <p className="text-xs text-gray-500">Samuel Global Market Xchange Inc. · Paired to OICD</p>
              </div>
            </div>
            <p className="text-sm text-gray-400 max-w-2xl">The primary governance token of the SGMX ecosystem. Vote on corporate decisions, invest in OZF-backed pools, earn yield through staking, and provide liquidity to the SGM/OICD pair.</p>
          </div>
          <div className="text-right space-y-1">
            <div className="text-xs text-gray-500">1 SGM =</div>
            <div className="text-lg font-bold text-purple-400 font-mono">{fmtRate(oicdRate)}</div>
            <div className="text-[10px] text-gray-600">Live OICD pair rate</div>
          </div>
        </div>

        {/* Stats row */}
        <div className="grid grid-cols-2 md:grid-cols-5 gap-3 mt-4">
          {[
            { label: 'Total Supply',  value: '250 Billion SGM',      icon: '🪙' },
            { label: 'Circulating',   value: fmt18(circulating),      icon: '🔄' },
            { label: 'Total Staked',  value: fmt18(totalStaked),      icon: '🔒' },
            { label: 'Members',       value: String(totalMembers ?? 0), icon: '👥' },
            { label: 'Yield Rate',    value: `${Number((yieldPool as { rewardRate?: bigint })?.rewardRate ?? 0n) / 100}%`, icon: '📈' },
          ].map(({ label, value, icon }) => (
            <div key={label} className="bg-white/5 border border-white/5 rounded-xl p-3 text-center">
              <div className="text-lg mb-1">{icon}</div>
              <div className="text-white font-bold text-sm">{value}</div>
              <div className="text-gray-500 text-[10px]">{label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Registration banner */}
      {isConnected && !isRegistered && (
        <div className="glass rounded-xl p-4 border border-purple-500/30 flex items-center justify-between">
          <div>
            <p className="text-white font-semibold text-sm">Register as SGM Member</p>
            <p className="text-gray-400 text-xs">Required to access staking, voting, and investment pools</p>
          </div>
          <button onClick={() => register()} disabled={regPending}
            className="bg-purple-600 hover:bg-purple-500 disabled:opacity-50 text-white px-4 py-2 rounded-lg text-sm font-semibold transition-all">
            {regPending ? 'Registering…' : regDone ? '✓ Done' : 'Register Free'}
          </button>
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-2 flex-wrap">
        {tabs.map(t => <button key={t.id} onClick={() => setTab(t.id)} className={tc(tab === t.id)}><span>{t.icon}</span>{t.label}</button>)}
      </div>

      {/* ── Overview ── */}
      {tab === 'overview' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="glass rounded-xl p-5">
            <h3 className="text-white font-bold mb-3">Token Features</h3>
            {[
              { icon: '⚖️', title: 'Governance Voting',   desc: '1 person = 1 vote on investment, yield, and liquidity decisions' },
              { icon: '🏢', title: 'Corporate Governance', desc: 'Participate in SGMX Inc. board decisions and strategic direction' },
              { icon: '💼', title: 'Investment Pools',     desc: 'Access 3 curated OZF-backed investment pools with 4%–12% target returns' },
              { icon: '📈', title: 'Yield / Staking',      desc: '2.5% yield on staked SGM · compounds per epoch' },
              { icon: '💧', title: 'Liquidity Provider',   desc: 'Provide SGM/OICD liquidity and earn LP rewards' },
            ].map(({ icon, title, desc }) => (
              <div key={title} className="flex gap-3 mb-3">
                <span className="text-lg shrink-0">{icon}</span>
                <div><p className="text-sm font-medium text-white">{title}</p><p className="text-xs text-gray-500">{desc}</p></div>
              </div>
            ))}
          </div>

          <div className="glass rounded-xl p-5">
            <h3 className="text-white font-bold mb-3">My Portfolio</h3>
            {isConnected && member ? (
              <div className="space-y-3">
                {[
                  { label: 'Available Balance', value: fmt18((member as { balance?: bigint })?.balance), color: 'text-white' },
                  { label: 'Staked Balance',    value: fmt18((member as { stakedBalance?: bigint })?.stakedBalance), color: 'text-blue-400' },
                  { label: 'Yield Accrued',     value: fmt18((member as { yieldAccrued?: bigint })?.yieldAccrued), color: 'text-green-400' },
                  { label: 'Invested',          value: fmt18((member as { investmentBalance?: bigint })?.investmentBalance), color: 'text-purple-400' },
                  { label: 'G-Score',           value: String((member as { gScore?: bigint })?.gScore ?? 0), color: 'text-yellow-400' },
                ].map(({ label, value, color }) => (
                  <div key={label} className="flex justify-between items-center p-2.5 bg-white/5 rounded-lg">
                    <span className="text-xs text-gray-400">{label}</span>
                    <span className={`text-sm font-mono font-bold ${color}`}>{value} SGM</span>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-gray-500 text-sm">Connect wallet to view portfolio</p>
            )}
          </div>
        </div>
      )}

      {/* ── Staking ── */}
      {tab === 'staking' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="glass rounded-xl p-5 space-y-4">
            <h3 className="text-white font-bold">Stake SGM</h3>
            <div className="bg-green-500/5 border border-green-500/20 rounded-lg p-3 text-xs space-y-1">
              <div className="flex justify-between"><span className="text-gray-400">APY</span><span className="text-green-400 font-bold">2.5%</span></div>
              <div className="flex justify-between"><span className="text-gray-400">Pool Total</span><span className="text-white">{fmt18(totalStaked)} SGM</span></div>
              <div className="flex justify-between"><span className="text-gray-400">Reward</span><span className="text-purple-400">SGM tokens</span></div>
            </div>
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Amount (SGM)</label>
              <input value={stakeAmt} onChange={e => setStakeAmt(e.target.value)} placeholder="e.g. 1000"
                className="w-full bg-white/5 border border-white/10 rounded px-3 py-2 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-purple-500" />
            </div>
            <div className="flex gap-2">
              <button onClick={() => stake(BigInt(Math.round(parseFloat(stakeAmt || '0') * 1e18)))}
                disabled={!isConnected || !isRegistered || stakePending || !stakeAmt}
                className="flex-1 bg-purple-600 hover:bg-purple-500 disabled:opacity-40 text-white py-2 rounded-lg text-sm font-bold transition-all">
                {stakePending ? 'Staking…' : stakeDone ? '✓ Staked' : 'Stake SGM'}
              </button>
              <button onClick={() => unstake(BigInt(Math.round(parseFloat(stakeAmt || '0') * 1e18)))}
                disabled={!isConnected || !isRegistered || unstakePending || !stakeAmt}
                className="flex-1 bg-white/10 hover:bg-white/20 disabled:opacity-40 text-white py-2 rounded-lg text-sm font-bold transition-all">
                {unstakePending ? 'Unstaking…' : 'Unstake'}
              </button>
            </div>
          </div>

          <div className="glass rounded-xl p-5 space-y-4">
            <h3 className="text-white font-bold">Claim Yield</h3>
            <div className="bg-yellow-500/5 border border-yellow-500/20 rounded-lg p-4 text-center">
              <p className="text-xs text-gray-500 mb-1">Pending Yield</p>
              <p className="text-2xl font-bold text-yellow-400 font-mono">
                {fmt18((member as { yieldAccrued?: bigint })?.yieldAccrued)} <span className="text-sm">SGM</span>
              </p>
            </div>
            <button onClick={() => claimYield()} disabled={!isConnected || !isRegistered || yieldPending}
              className="w-full bg-yellow-600 hover:bg-yellow-500 disabled:opacity-40 text-white py-2 rounded-lg text-sm font-bold transition-all">
              {yieldPending ? 'Claiming…' : yieldDone ? '✓ Claimed' : 'Claim Yield'}
            </button>
            <div className="text-[10px] text-gray-600 text-center">Yield converts to SGM balance · No lock-up</div>
          </div>
        </div>
      )}

      {/* ── Investment Pools ── */}
      {tab === 'invest' && (
        <div className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {pools.map(({ id, data, name }) => {
              const p = data as { totalDeposited?: bigint; targetReturn?: bigint; minDeposit?: bigint; active?: boolean } | undefined;
              const ret = Number(p?.targetReturn ?? 0n) / 100;
              return (
                <div key={id} className="glass rounded-xl p-4 space-y-2 border border-white/5">
                  <div className="flex items-center gap-2">
                    <div className="w-8 h-8 bg-gradient-to-br from-purple-500 to-blue-600 rounded-lg flex items-center justify-center text-xs font-bold text-white">P{id}</div>
                    <div><p className="text-sm font-bold text-white">{name}</p><p className="text-[10px] text-gray-500">Pool #{id}</p></div>
                  </div>
                  <div className="space-y-1 text-xs">
                    <div className="flex justify-between"><span className="text-gray-500">Target Return</span><span className="text-green-400 font-bold">{ret}%</span></div>
                    <div className="flex justify-between"><span className="text-gray-500">Total Deposited</span><span className="text-white">{fmt18(p?.totalDeposited)} SGM</span></div>
                    <div className="flex justify-between"><span className="text-gray-500">Min Deposit</span><span className="text-white">{fmt18(p?.minDeposit)} SGM</span></div>
                    <div className="flex justify-between"><span className="text-gray-500">Status</span><span className={p?.active ? 'text-green-400' : 'text-red-400'}>{p?.active ? '✓ Active' : 'Closed'}</span></div>
                  </div>
                </div>
              );
            })}
          </div>

          <div className="glass rounded-xl p-5 max-w-md space-y-3">
            <h3 className="text-white font-bold">Deposit to Investment Pool</h3>
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Pool</label>
              <select value={poolId} onChange={e => setPoolId(e.target.value)}
                className="w-full bg-white/5 border border-white/10 rounded px-3 py-2 text-sm text-white focus:outline-none focus:border-purple-500">
                {pools.map(p => <option key={p.id} value={p.id} className="bg-gray-900">Pool #{p.id} — {p.name}</option>)}
              </select>
            </div>
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Amount (SGM)</label>
              <input value={poolAmt} onChange={e => setPoolAmt(e.target.value)} placeholder="e.g. 5000"
                className="w-full bg-white/5 border border-white/10 rounded px-3 py-2 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-purple-500" />
            </div>
            <button onClick={() => depositToPool(BigInt(poolId), BigInt(Math.round(parseFloat(poolAmt || '0') * 1e18)))}
              disabled={!isConnected || !isRegistered || depositPending || !poolAmt}
              className="w-full bg-blue-600 hover:bg-blue-500 disabled:opacity-40 text-white py-2 rounded-lg text-sm font-bold transition-all">
              {depositPending ? 'Depositing…' : 'Deposit to Pool'}
            </button>
          </div>
        </div>
      )}

      {/* ── Governance ── */}
      {tab === 'governance' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="glass rounded-xl p-5 space-y-3">
            <h3 className="text-white font-bold">Create Proposal</h3>
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Title</label>
              <input value={propTitle} onChange={e => setPropTitle(e.target.value)} placeholder="Proposal title"
                className="w-full bg-white/5 border border-white/10 rounded px-3 py-2 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-purple-500" />
            </div>
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Description</label>
              <textarea value={propDesc} onChange={e => setPropDesc(e.target.value)} placeholder="Detailed description..."
                className="w-full bg-white/5 border border-white/10 rounded px-3 py-2 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-purple-500 h-20 resize-none" />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs text-gray-500 mb-1 block">Type</label>
                <select value={propType} onChange={e => setPropType(e.target.value)}
                  className="w-full bg-white/5 border border-white/10 rounded px-3 py-2 text-sm text-white focus:outline-none focus:border-purple-500">
                  {['governance','investment','yield','liquidity'].map(t => <option key={t} value={t} className="bg-gray-900">{t}</option>)}
                </select>
              </div>
              <div>
                <label className="text-xs text-gray-500 mb-1 block">Duration (days)</label>
                <input value={propDays} onChange={e => setPropDays(e.target.value)} type="number"
                  className="w-full bg-white/5 border border-white/10 rounded px-3 py-2 text-sm text-white focus:outline-none focus:border-purple-500" />
              </div>
            </div>
            <button onClick={() => createProposal(propTitle, propDesc, propType, BigInt(propDays || '7'))}
              disabled={!isConnected || !isRegistered || propPending || !propTitle}
              className="w-full bg-purple-600 hover:bg-purple-500 disabled:opacity-40 text-white py-2 rounded-lg text-sm font-bold transition-all">
              {propPending ? 'Creating…' : 'Create Proposal'}
            </button>
          </div>

          <div className="glass rounded-xl p-5 space-y-4">
            <h3 className="text-white font-bold">Vote on Proposal</h3>
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Proposal ID</label>
              <input value={voteId} onChange={e => setVoteId(e.target.value)} placeholder="e.g. 1"
                className="w-full bg-white/5 border border-white/10 rounded px-3 py-2 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-purple-500" />
            </div>
            <div className="flex gap-2">
              <button onClick={() => setSupport(true)} className={`flex-1 py-2 rounded-lg text-sm font-bold transition-all ${support ? 'bg-green-600 text-white' : 'bg-white/5 text-gray-400'}`}>✓ For</button>
              <button onClick={() => setSupport(false)} className={`flex-1 py-2 rounded-lg text-sm font-bold transition-all ${!support ? 'bg-red-600 text-white' : 'bg-white/5 text-gray-400'}`}>✗ Against</button>
            </div>
            <button onClick={() => vote(BigInt(voteId || '0'), support)}
              disabled={!isConnected || !isRegistered || votePending || !voteId}
              className="w-full bg-purple-600 hover:bg-purple-500 disabled:opacity-40 text-white py-2 rounded-lg text-sm font-bold transition-all">
              {votePending ? 'Voting…' : 'Cast Vote'}
            </button>

            <div className="border-t border-white/5 pt-3">
              <h4 className="text-xs text-gray-500 mb-2 font-semibold uppercase tracking-wider">Lookup Proposal</h4>
              <input value={lookupId} onChange={e => setLookupId(e.target.value)} placeholder="Proposal ID"
                className="w-full bg-white/5 border border-white/10 rounded px-3 py-2 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-purple-500 mb-2" />
              {!!proposal && (
                <div className="bg-white/5 rounded-lg p-3 text-xs space-y-1">
                  <p className="text-white font-semibold">{(proposal as { title?: string })?.title}</p>
                  <p className="text-gray-400">{(proposal as { description?: string })?.description}</p>
                  <div className="flex gap-4 mt-2">
                    <span className="text-green-400">For: {String((proposal as { votesFor?: bigint })?.votesFor ?? 0n)}</span>
                    <span className="text-red-400">Against: {String((proposal as { votesAgainst?: bigint })?.votesAgainst ?? 0n)}</span>
                    <span className={`ml-auto ${(proposal as { executed?: boolean })?.executed ? 'text-gray-400' : 'text-blue-400'}`}>
                      {(proposal as { executed?: boolean })?.executed ? ((proposal as { passed?: boolean })?.passed ? '✓ Passed' : '✗ Failed') : 'Active'}
                    </span>
                  </div>
                  {!(proposal as { executed?: boolean })?.executed && (
                    <button onClick={() => executeProposal(BigInt(lookupId))} disabled={execPending}
                      className="mt-2 w-full bg-white/10 hover:bg-white/20 text-white py-1 rounded text-xs font-medium transition-all">
                      {execPending ? 'Executing…' : 'Execute Proposal'}
                    </button>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ── Liquidity ── */}
      {tab === 'liquidity' && (
        <div className="glass rounded-xl p-6 space-y-4">
          <h3 className="text-white font-bold">SGM / OICD Liquidity Pool</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              { label: 'Pair',           value: 'SGM / OICD',    color: 'text-purple-400' },
              { label: 'SGM Reserve',    value: '~2.5B SGM',     color: 'text-white' },
              { label: 'OICD Reserve',   value: '~2.5M OICD',   color: 'text-cyan-400' },
              { label: 'LP Fee',         value: '0.3%',          color: 'text-green-400' },
            ].map(({ label, value, color }) => (
              <div key={label} className="bg-white/5 rounded-xl p-4 text-center">
                <p className="text-[10px] text-gray-500 mb-1">{label}</p>
                <p className={`font-bold text-sm ${color}`}>{value}</p>
              </div>
            ))}
          </div>
          <div className="bg-blue-500/5 border border-blue-500/20 rounded-lg p-4 text-sm text-gray-400">
            <p className="font-semibold text-white mb-1">How SGM/OICD Liquidity Works</p>
            <ul className="space-y-1 text-xs list-disc pl-4">
              <li>SGM is paired 1:1 with OICD at the initialized rate of 0.001 OICD/SGM</li>
              <li>Liquidity providers earn 0.3% trading fees + SGM yield rewards</li>
              <li>Price discovery follows the GLTE model across OZF DEX corridors</li>
              <li>SGM/OICD swaps are available on the Sovereign DEX</li>
            </ul>
          </div>
          <div className="text-xs text-gray-600 text-center">Liquidity management via owner functions · Contact SGMX Inc. to add liquidity</div>
        </div>
      )}
    </div>
  );
}
