'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatUnits } from 'viem';
import {
  useLaaSPool, useLaaSPoolCounter,
  useCreateLaaSPool, useProvideLiquidity, useWithdrawLiquidity,
  POOL_TYPES
} from '@/hooks/contracts/useLiquidityAsAService';
import { CONTRACTS } from '@/lib/contracts';

const POOL_ICONS = ['💱', '🛢️', '📈', '🔀', '🌐', '🌑'];

export default function LiquidityServiceDashboard() {
  const { address } = useAccount();
  const [tab, setTab] = useState<'pools' | 'create' | 'provide'>('pools');
  const [viewPoolId, setViewPoolId] = useState<bigint>(0n);
  const [newPool, setNewPool] = useState({ type: 0, base: 'USD', quote: 'EUR', target: '1000', fee: 30 });
  const [providePoolId, setProvidePoolId] = useState('');
  const [provideAmount, setProvideAmount] = useState('');

  const { data: poolCount } = useLaaSPoolCounter();
  const { data: viewPool } = useLaaSPool(viewPoolId);
  const { createPool, isPending: creating, isSuccess: created } = useCreateLaaSPool();
  const { provideLiquidity, isPending: providing, isSuccess: provided } = useProvideLiquidity();
  const { withdrawLiquidity, isPending: withdrawing } = useWithdrawLiquidity();

  const notDeployed = !CONTRACTS.LiquidityAsAService;
  const pool = viewPool as any;

  return (
    <div className="space-y-6">
      <div className="glass rounded-xl p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-br from-cyan-500 to-blue-600 rounded-lg flex items-center justify-center text-xl">💧</div>
            <div>
              <h2 className="text-2xl font-bold text-white">Liquidity as a Service</h2>
              <p className="text-gray-400 text-sm">Market-making across FX, commodities, securities & dark pool</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            {notDeployed && <span className="px-3 py-1 bg-yellow-500/20 text-yellow-400 rounded-full text-xs">Not Deployed</span>}
            <div className="px-4 py-2 bg-cyan-500/10 border border-cyan-500/30 rounded-lg">
              <p className="text-xs text-gray-400">Total Pools</p>
              <p className="text-xl font-bold text-cyan-400">{poolCount !== undefined ? Number(poolCount) : '—'}</p>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-3 md:grid-cols-6 gap-3 mb-6">
          {POOL_TYPES.map((type, i) => (
            <div key={type} className="p-3 bg-white/5 rounded-lg text-center border border-white/10">
              <div className="text-2xl mb-1">{POOL_ICONS[i]}</div>
              <p className="text-xs text-gray-400">{type}</p>
            </div>
          ))}
        </div>

        <div className="flex gap-2 mb-4 flex-wrap">
          {(['pools', 'create', 'provide'] as const).map((t) => (
            <button key={t} onClick={() => setTab(t)} className={`px-4 py-2 rounded-lg capitalize transition-all ${tab === t ? 'bg-cyan-600 text-white' : 'text-gray-400 hover:bg-white/5'}`}>
              {t === 'pools' ? 'View Pools' : t === 'create' ? 'Create Pool' : 'Provide Liquidity'}
            </button>
          ))}
        </div>

        {tab === 'pools' && (
          <div className="space-y-4">
            <div className="flex gap-2">
              <input
                value={viewPoolId.toString()}
                onChange={(e) => setViewPoolId(BigInt(e.target.value || '0'))}
                type="number"
                min="0"
                placeholder="Pool ID"
                className="w-32 bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-cyan-500"
              />
            </div>
            {pool ? (
              <div className="p-4 bg-white/5 rounded-lg border border-white/10 space-y-2">
                <div className="flex justify-between">
                  <span className="text-gray-400 text-sm">Type</span>
                  <span className="text-white font-medium">{POOL_TYPES[Number(pool.poolType)] || '—'}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400 text-sm">Pair</span>
                  <span className="text-white font-medium">{pool.baseCurrency}/{pool.quoteCurrency}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400 text-sm">Total Liquidity</span>
                  <span className="text-white font-medium">{formatUnits(pool.totalLiquidity || 0n, 18)} ETH</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400 text-sm">Status</span>
                  <span className={pool.active ? 'text-green-400' : 'text-red-400'}>{pool.active ? 'Active' : 'Inactive'}</span>
                </div>
              </div>
            ) : (
              <p className="text-gray-500 text-sm">No pool found at this ID</p>
            )}
          </div>
        )}

        {tab === 'create' && (
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">Pool Type</label>
                <select
                  value={newPool.type}
                  onChange={(e) => setNewPool({ ...newPool, type: parseInt(e.target.value) })}
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                >
                  {POOL_TYPES.map((t, i) => <option key={t} value={i} className="bg-gray-800">{t}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-2">Fee (bps)</label>
                <input
                  value={newPool.fee}
                  onChange={(e) => setNewPool({ ...newPool, fee: parseInt(e.target.value) })}
                  type="number"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-2">Base Currency</label>
                <input
                  value={newPool.base}
                  onChange={(e) => setNewPool({ ...newPool, base: e.target.value })}
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-2">Quote Currency</label>
                <input
                  value={newPool.quote}
                  onChange={(e) => setNewPool({ ...newPool, quote: e.target.value })}
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                />
              </div>
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-2">Target Liquidity (ETH)</label>
              <input
                value={newPool.target}
                onChange={(e) => setNewPool({ ...newPool, target: e.target.value })}
                type="number"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
              />
            </div>
            <button
              onClick={() => createPool(newPool.type, newPool.base, newPool.quote, newPool.target, newPool.fee)}
              disabled={creating || notDeployed}
              className="px-6 py-3 bg-cyan-600 hover:bg-cyan-500 disabled:opacity-50 text-white rounded-lg font-medium transition-all"
            >
              {creating ? 'Creating...' : created ? '✓ Pool Created!' : 'Create Liquidity Pool'}
            </button>
          </div>
        )}

        {tab === 'provide' && (
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">Pool ID</label>
                <input
                  value={providePoolId}
                  onChange={(e) => setProvidePoolId(e.target.value)}
                  type="number"
                  placeholder="0"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-2">Amount (ETH) — 30-day lockup</label>
                <input
                  value={provideAmount}
                  onChange={(e) => setProvideAmount(e.target.value)}
                  type="number"
                  step="0.01"
                  placeholder="0.5"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                />
              </div>
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => provideLiquidity(BigInt(providePoolId || '0'), provideAmount)}
                disabled={!providePoolId || !provideAmount || providing || notDeployed}
                className="px-6 py-3 bg-cyan-600 hover:bg-cyan-500 disabled:opacity-50 text-white rounded-lg font-medium transition-all"
              >
                {providing ? 'Providing...' : provided ? '✓ Provided!' : 'Provide Liquidity'}
              </button>
              <button
                onClick={() => withdrawLiquidity(BigInt(providePoolId || '0'))}
                disabled={!providePoolId || withdrawing || notDeployed}
                className="px-6 py-3 bg-white/10 hover:bg-white/20 disabled:opacity-50 text-white rounded-lg font-medium transition-all"
              >
                {withdrawing ? 'Withdrawing...' : 'Withdraw'}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
