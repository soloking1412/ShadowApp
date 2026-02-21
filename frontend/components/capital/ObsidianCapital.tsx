'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatUnits } from 'viem';
import {
  useAUM, useNAVPerShare, useManagementFee, usePerformanceFee,
  useInvestorInfo, useDepositToFund, useWithdrawFromFund
} from '@/hooks/contracts/useObsidianCapital';
import { CONTRACTS } from '@/lib/contracts';

const STRATEGIES = ['MacroPlay', 'CurrencyArbitrage', 'EmergingMarkets', 'InfrastructureFinancing', 'DarkPoolTrading', 'Quant', 'LongShort', 'EventDriven'];

export default function ObsidianCapitalDashboard() {
  const { address } = useAccount();
  const [depositAmount, setDepositAmount] = useState('');
  const [tab, setTab] = useState<'invest' | 'positions'>('invest');

  const { data: aum } = useAUM();
  const { data: navPerShare } = useNAVPerShare();
  const { data: mgmtFee } = useManagementFee();
  const { data: perfFee } = usePerformanceFee();
  const { data: investorInfo } = useInvestorInfo(address);
  const { deposit, isPending: depositing, isSuccess: deposited } = useDepositToFund();

  const notDeployed = !CONTRACTS.ObsidianCapital;

  const info = investorInfo as any;

  return (
    <div className="space-y-6">
      <div className="glass rounded-xl p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-br from-slate-700 to-slate-900 border border-white/20 rounded-lg flex items-center justify-center text-xl">💎</div>
            <div>
              <h2 className="text-2xl font-bold text-white">Obsidian Capital</h2>
              <p className="text-gray-400 text-sm">Institutional hedge fund — multi-strategy DeFi</p>
            </div>
          </div>
          {notDeployed && (
            <span className="px-3 py-1 bg-yellow-500/20 text-yellow-400 rounded-full text-xs">Not Deployed</span>
          )}
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          {[
            { label: 'Total AUM', value: aum ? `$${parseFloat(formatUnits(aum as bigint, 18)).toLocaleString()}` : '—', icon: '💰' },
            { label: 'NAV / Share', value: navPerShare ? formatUnits(navPerShare as bigint, 18) : '—', icon: '📈' },
            { label: 'Mgmt Fee', value: mgmtFee ? `${Number(mgmtFee) / 100}%` : '—', icon: '📋' },
            { label: 'Perf Fee', value: perfFee ? `${Number(perfFee) / 100}%` : '—', icon: '🎯' },
          ].map(({ label, value, icon }) => (
            <div key={label} className="p-4 bg-white/5 rounded-lg border border-white/10">
              <div className="flex items-center gap-2 mb-2">
                <span>{icon}</span>
                <p className="text-xs text-gray-400">{label}</p>
              </div>
              <p className="text-xl font-bold text-white">{value}</p>
            </div>
          ))}
        </div>

        {info && (
          <div className="p-4 bg-indigo-500/10 border border-indigo-500/30 rounded-lg mb-6">
            <h3 className="text-indigo-300 font-medium mb-2">Your Position</h3>
            <div className="grid grid-cols-3 gap-4 text-sm">
              <div>
                <p className="text-gray-400">Invested</p>
                <p className="text-white font-bold">{formatUnits(info.totalInvested || 0n, 18)} ETH</p>
              </div>
              <div>
                <p className="text-gray-400">Shares</p>
                <p className="text-white font-bold">{formatUnits(info.shares || 0n, 18)}</p>
              </div>
              <div>
                <p className="text-gray-400">Lock Until</p>
                <p className="text-white font-bold">
                  {info.lockUntil ? new Date(Number(info.lockUntil) * 1000).toLocaleDateString() : '—'}
                </p>
              </div>
            </div>
          </div>
        )}

        <div className="flex gap-2 mb-4">
          {(['invest', 'positions'] as const).map((t) => (
            <button key={t} onClick={() => setTab(t)} className={`px-4 py-2 rounded-lg capitalize transition-all ${tab === t ? 'bg-slate-600 text-white' : 'text-gray-400 hover:bg-white/5'}`}>
              {t === 'invest' ? 'Invest' : 'Strategies'}
            </button>
          ))}
        </div>

        {tab === 'invest' ? (
          <div className="space-y-4">
            <div>
              <label className="block text-sm text-gray-400 mb-2">Deposit Amount (ETH) — 90-day lockup</label>
              <input
                value={depositAmount}
                onChange={(e) => setDepositAmount(e.target.value)}
                placeholder="0.1"
                type="number"
                step="0.01"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-slate-500"
              />
            </div>
            <button
              onClick={() => deposit(depositAmount)}
              disabled={!depositAmount || depositing || notDeployed}
              className="px-6 py-3 bg-slate-600 hover:bg-slate-500 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-medium transition-all"
            >
              {depositing ? 'Investing...' : deposited ? '✓ Invested!' : 'Invest'}
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            {STRATEGIES.map((s) => (
              <div key={s} className="p-3 bg-white/5 rounded-lg border border-white/10 text-center">
                <p className="text-sm font-medium text-white">{s}</p>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
