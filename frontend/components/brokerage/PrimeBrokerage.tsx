'use client';

import { useState, useEffect } from 'react';
import { useAccount } from 'wagmi';
import { formatUnits } from 'viem';
import {
  useClientAccount, useClientRiskMetrics,
  useRegisterClient, useDepositCollateral, useRequestMarginLoan,
  CLIENT_TIERS
} from '@/hooks/contracts/usePrimeBrokerage';
import { CONTRACTS } from '@/lib/contracts';

export default function PrimeBrokerageDashboard() {
  const { address } = useAccount();
  const [selectedTier, setSelectedTier] = useState(0);
  const [collateralAmount, setCollateralAmount] = useState('');
  const [loanAmount, setLoanAmount] = useState('');
  const [tab, setTab] = useState<'account' | 'margin' | 'register'>('account');

  const { data: account } = useClientAccount(address);
  const { data: riskMetrics } = useClientRiskMetrics(address);
  const { registerClient, isPending: registering, isSuccess: registered, error: regErr } = useRegisterClient();
  const { depositCollateral, isPending: depositing, isSuccess: deposited, error: depositErr } = useDepositCollateral();
  const { requestLoan, isPending: loaning, isSuccess: loaned, error: loanErr } = useRequestMarginLoan();

  const [txError,   setTxError]   = useState<string | null>(null);
  const [txSuccess, setTxSuccess] = useState<string | null>(null);

  useEffect(() => {
    const err = regErr ?? depositErr ?? loanErr;
    if (!err) return;
    const msg = (err as { shortMessage?: string })?.shortMessage ?? err.message ?? 'Transaction failed';
    setTxError(msg.length > 120 ? msg.slice(0, 120) + '…' : msg);
    const t = setTimeout(() => setTxError(null), 7000);
    return () => clearTimeout(t);
  }, [regErr, depositErr, loanErr]);

  useEffect(() => {
    const msgs: [boolean, string][] = [[registered, 'Client registered'], [deposited, 'Collateral deposited'], [loaned, 'Loan requested']];
    const done = msgs.find(([ok]) => ok);
    if (!done) return;
    setTxSuccess(done[1]);
    const t = setTimeout(() => setTxSuccess(null), 5000);
    return () => clearTimeout(t);
  }, [registered, deposited, loaned]);

  const notDeployed = !CONTRACTS.PrimeBrokerage;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const acc = account as any;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const risk = riskMetrics as any;

  return (
    <div className="space-y-6">
      {txError && (
        <div className="flex items-start gap-3 px-4 py-3 bg-red-900/40 border border-red-500/40 rounded-xl text-sm">
          <span className="text-red-400 shrink-0 mt-0.5">✕</span>
          <div className="flex-1"><p className="font-semibold text-red-300">Transaction failed</p><p className="text-red-400/80 text-xs mt-0.5">{txError}</p></div>
          <button onClick={() => setTxError(null)} className="text-red-500 hover:text-red-300 text-xs shrink-0">dismiss</button>
        </div>
      )}
      {txSuccess && (
        <div className="flex items-center gap-2 px-4 py-3 bg-green-900/30 border border-green-500/30 rounded-xl text-sm">
          <span className="text-green-400">✓</span><p className="text-green-300 font-semibold">{txSuccess}</p>
        </div>
      )}
      <div className="glass rounded-xl p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-br from-amber-500 to-orange-600 rounded-lg flex items-center justify-center text-xl">🏦</div>
            <div>
              <h2 className="text-2xl font-bold text-white">Prime Brokerage</h2>
              <p className="text-gray-400 text-sm">Institutional margin lending & securities services</p>
            </div>
          </div>
          {notDeployed && (
            <span className="px-3 py-1 bg-yellow-500/20 text-yellow-400 rounded-full text-xs">Not Deployed</span>
          )}
        </div>

        {acc ? (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
            {[
              { label: 'Client Tier', value: CLIENT_TIERS[Number(acc.tier)] || '—', icon: '🎖️' },
              { label: 'Collateral', value: `${parseFloat(formatUnits(acc.collateral || 0n, 18)).toFixed(4)} ETH`, icon: '🔒' },
              { label: 'Loans Outstanding', value: `${parseFloat(formatUnits(acc.loansOutstanding || 0n, 18)).toFixed(4)} ETH`, icon: '💳' },
              { label: 'Margin Ratio', value: risk ? `${(Number(risk.maintenanceMargin) / 100).toFixed(1)}%` : '—', icon: '📊' },
            ].map(({ label, value, icon }) => (
              <div key={label} className="p-4 bg-white/5 rounded-lg border border-white/10">
                <div className="flex items-center gap-2 mb-1">
                  <span>{icon}</span>
                  <p className="text-xs text-gray-400">{label}</p>
                </div>
                <p className="text-lg font-bold text-white">{value}</p>
              </div>
            ))}
          </div>
        ) : (
          <div className="p-4 bg-amber-500/10 border border-amber-500/30 rounded-lg mb-6 text-amber-300 text-sm">
            No account found. Register as a client to access prime brokerage services.
          </div>
        )}

        <div className="flex gap-2 mb-4 flex-wrap">
          {(['account', 'margin', 'register'] as const).map((t) => (
            <button key={t} onClick={() => setTab(t)} className={`px-4 py-2 rounded-lg capitalize transition-all ${tab === t ? 'bg-amber-600 text-white' : 'text-gray-400 hover:bg-white/5'}`}>
              {t === 'account' ? 'Account' : t === 'margin' ? 'Margin Loan' : 'Register'}
            </button>
          ))}
        </div>

        {tab === 'account' && risk && (
          <div className="space-y-3">
            {[
              { label: 'Portfolio VaR (30d)', value: `${parseFloat(formatUnits(risk.var30d || 0n, 18)).toFixed(4)} ETH` },
              { label: 'Leverage Ratio', value: `${Number(risk.leverageRatio) / 100}x` },
              { label: 'Concentration Risk', value: `${Number(risk.concentrationRisk) / 100}%` },
              { label: 'Liquidity Ratio', value: `${Number(risk.liquidityRatio) / 100}%` },
            ].map(({ label, value }) => (
              <div key={label} className="flex justify-between items-center p-3 bg-white/5 rounded-lg">
                <span className="text-gray-400 text-sm">{label}</span>
                <span className="text-white font-medium">{value}</span>
              </div>
            ))}
          </div>
        )}

        {tab === 'margin' && (
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">Collateral (ETH)</label>
                <input
                  value={collateralAmount}
                  onChange={(e) => setCollateralAmount(e.target.value)}
                  placeholder="0.5"
                  type="number"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-amber-500"
                />
                <button
                  onClick={() => depositCollateral(collateralAmount)}
                  disabled={!collateralAmount || depositing || notDeployed}
                  className="mt-2 w-full py-2 bg-amber-600 hover:bg-amber-500 disabled:opacity-50 text-white rounded-lg text-sm font-medium transition-all"
                >
                  {depositing ? 'Depositing...' : deposited ? '✓ Deposited' : 'Deposit Collateral'}
                </button>
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-2">Loan Amount (ETH) — min 25% margin</label>
                <input
                  value={loanAmount}
                  onChange={(e) => setLoanAmount(e.target.value)}
                  placeholder="0.25"
                  type="number"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-amber-500"
                />
                <button
                  onClick={() => requestLoan(loanAmount, collateralAmount)}
                  disabled={!loanAmount || loaning || notDeployed}
                  className="mt-2 w-full py-2 bg-orange-600 hover:bg-orange-500 disabled:opacity-50 text-white rounded-lg text-sm font-medium transition-all"
                >
                  {loaning ? 'Requesting...' : loaned ? '✓ Approved' : 'Request Margin Loan'}
                </button>
              </div>
            </div>
          </div>
        )}

        {tab === 'register' && (
          <div className="space-y-4">
            <div>
              <label className="block text-sm text-gray-400 mb-2">Client Tier</label>
              <div className="grid grid-cols-3 gap-3">
                {CLIENT_TIERS.map((t, i) => (
                  <button
                    key={t}
                    onClick={() => setSelectedTier(i)}
                    className={`p-3 rounded-lg text-sm font-medium transition-all ${selectedTier === i ? 'bg-amber-600 text-white' : 'bg-white/5 text-gray-300 hover:bg-white/10'}`}
                  >
                    {t}
                  </button>
                ))}
              </div>
            </div>
            <button
              onClick={() => registerClient(selectedTier)}
              disabled={registering || notDeployed}
              className="px-6 py-3 bg-amber-600 hover:bg-amber-500 disabled:opacity-50 text-white rounded-lg font-medium transition-all"
            >
              {registering ? 'Registering...' : registered ? '✓ Registered!' : `Register as ${CLIENT_TIERS[selectedTier]}`}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
