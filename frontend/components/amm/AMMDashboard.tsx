'use client';

import { useState } from 'react';
import { parseUnits } from 'viem';

const safeUnits = (v: string, d = 18) => { try { return parseUnits(v || '0', d); } catch { return 0n; } };
const safeBig   = (v: string)         => { try { return v ? BigInt(v) : 0n; }   catch { return 0n; } };
import { SwapWidget } from './SwapWidget';
import { LiquidityPool } from './LiquidityPool';
import { usePoolCounter, useCreatePool } from '@/hooks/contracts/useUniversalAMM';
import { CONTRACTS } from '@/lib/contracts';

export default function AMMDashboard() {
  const [tab, setTab] = useState<'swap' | 'liquidity' | 'create'>('swap');
  const [poolId, setPoolId] = useState<bigint>(0n);

  // Create pool form state
  const [token0, setToken0] = useState('');
  const [tokenId0, setTokenId0] = useState('0');
  const [token1, setToken1] = useState('');
  const [tokenId1, setTokenId1] = useState('0');
  const [initAmount0, setInitAmount0] = useState('');
  const [initAmount1, setInitAmount1] = useState('');
  const [feeBps, setFeeBps] = useState('30');

  const { data: poolCount } = usePoolCounter();
  const { createPool, isPending: isCreating, isConfirming, isSuccess: createSuccess, error: createError } = useCreatePool();
  const notDeployed = !CONTRACTS.UniversalAMM;

  const poolCountNum = poolCount !== undefined ? Number(poolCount) : 0;
  const hasPools = poolCountNum > 0;

  const handleCreatePool = () => {
    if (!token0 || !token1 || !initAmount0 || !initAmount1) return;
    if (!token0.startsWith('0x') || !token1.startsWith('0x')) return;

    createPool(
      token0 as `0x${string}`,
      safeBig(tokenId0 || '0'),
      token1 as `0x${string}`,
      safeBig(tokenId1 || '0'),
      safeUnits(initAmount0),
      safeUnits(initAmount1),
      safeBig(feeBps || '30'),
    );
  };

  return (
    <div className="space-y-6">
      <div className="glass rounded-xl p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-br from-green-500 to-emerald-600 rounded-lg flex items-center justify-center text-xl">🔄</div>
            <div>
              <h2 className="text-2xl font-bold text-white">Universal AMM</h2>
              <p className="text-gray-400 text-sm">Constant-product swap — ERC20 & ERC1155 token pools</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            {notDeployed && <span className="px-3 py-1 bg-yellow-500/20 text-yellow-400 rounded-full text-xs">Not Deployed</span>}
            <div className="px-4 py-2 bg-green-500/10 border border-green-500/30 rounded-lg">
              <p className="text-xs text-gray-400">Total Pools</p>
              <p className="text-xl font-bold text-green-400">{poolCount !== undefined ? Number(poolCount) : '—'}</p>
            </div>
          </div>
        </div>

        {notDeployed && (
          <div className="p-4 bg-yellow-500/10 border border-yellow-500/30 rounded-lg mb-4 text-yellow-300 text-sm">
            UniversalAMM not deployed yet. Run the deployer to enable swaps and liquidity.
          </div>
        )}

        <div className="flex gap-2 mb-6">
          {(['swap', 'liquidity', 'create'] as const).map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`px-4 py-2 rounded-lg transition-all ${tab === t ? 'bg-green-600 text-white' : 'text-gray-400 hover:bg-white/5'}`}
            >
              {t === 'create' ? '+ Create Pool' : t === 'swap' ? 'Swap' : 'Liquidity'}
            </button>
          ))}
        </div>

        <div className={notDeployed ? 'opacity-50 pointer-events-none' : ''}>
          {/* Pool selector for swap and liquidity tabs */}
          {tab !== 'create' && (
            <div className="flex items-center gap-3 mb-4">
              <label className="text-sm text-gray-400">Pool ID:</label>
              <input
                value={poolId.toString()}
                onChange={(e) => {
                  const v = e.target.value;
                  if (v === '' || /^\d+$/.test(v)) setPoolId(BigInt(v || '0'));
                }}
                type="number"
                min="0"
                max={hasPools ? poolCountNum - 1 : 0}
                className="w-24 bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-green-500"
              />
              {!hasPools && (
                <span className="text-xs text-yellow-400">
                  No pools exist yet —{' '}
                  <button onClick={() => setTab('create')} className="underline hover:text-yellow-300">
                    create one first
                  </button>
                </span>
              )}
              {hasPools && (
                <span className="text-xs text-gray-500">Pool 0 – {poolCountNum - 1} available</span>
              )}
            </div>
          )}

          {tab === 'swap' && <SwapWidget poolId={poolId} poolExists={hasPools} />}
          {tab === 'liquidity' && <LiquidityPool poolId={poolId} poolExists={hasPools} />}

          {tab === 'create' && (
            <div className="max-w-lg space-y-4">
              <p className="text-sm text-gray-400 mb-2">
                Create a new constant-product AMM pool. For plain ERC20 tokens leave Token ID as 0.
                For ERC1155 tokens (e.g. OICD currency IDs), set the Token ID accordingly.
              </p>

              <div className="space-y-4">
                <div className="grid grid-cols-3 gap-3">
                  <div className="col-span-2 space-y-1">
                    <label className="text-sm font-medium text-gray-300">Token 0 Address</label>
                    <input
                      type="text"
                      value={token0}
                      onChange={(e) => setToken0(e.target.value)}
                      placeholder="0x..."
                      className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-green-500"
                    />
                  </div>
                  <div className="space-y-1">
                    <label className="text-sm font-medium text-gray-300">Token ID 0</label>
                    <input
                      type="number"
                      value={tokenId0}
                      onChange={(e) => setTokenId0(e.target.value)}
                      min="0"
                      className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-green-500"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-3">
                  <div className="col-span-2 space-y-1">
                    <label className="text-sm font-medium text-gray-300">Token 1 Address</label>
                    <input
                      type="text"
                      value={token1}
                      onChange={(e) => setToken1(e.target.value)}
                      placeholder="0x..."
                      className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-green-500"
                    />
                  </div>
                  <div className="space-y-1">
                    <label className="text-sm font-medium text-gray-300">Token ID 1</label>
                    <input
                      type="number"
                      value={tokenId1}
                      onChange={(e) => setTokenId1(e.target.value)}
                      min="0"
                      className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-green-500"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-1">
                    <label className="text-sm font-medium text-gray-300">Initial Amount Token 0</label>
                    <input
                      type="number"
                      value={initAmount0}
                      onChange={(e) => setInitAmount0(e.target.value)}
                      placeholder="0.0"
                      className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-green-500"
                    />
                  </div>
                  <div className="space-y-1">
                    <label className="text-sm font-medium text-gray-300">Initial Amount Token 1</label>
                    <input
                      type="number"
                      value={initAmount1}
                      onChange={(e) => setInitAmount1(e.target.value)}
                      placeholder="0.0"
                      className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-green-500"
                    />
                  </div>
                </div>

                <div className="space-y-1">
                  <label className="text-sm font-medium text-gray-300">
                    Fee Basis Points
                    <span className="text-gray-500 font-normal ml-2">
                      ({feeBps ? (Number(feeBps) / 100).toFixed(2) : '0.00'}%)
                    </span>
                  </label>
                  <input
                    type="number"
                    value={feeBps}
                    onChange={(e) => setFeeBps(e.target.value)}
                    min="1"
                    max="1000"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-green-500"
                  />
                  <p className="text-xs text-gray-500">Common: 10 = 0.1% · 30 = 0.3% · 100 = 1%</p>
                </div>
              </div>

              {createError && (
                <div className="p-3 bg-red-500/10 border border-red-500/30 rounded-lg text-red-400 text-sm break-all">
                  {String(createError.message).slice(0, 200)}
                </div>
              )}

              {createSuccess && (
                <div className="p-3 bg-green-500/10 border border-green-500/30 rounded-lg text-green-400 text-sm">
                  Pool created! New pool ID: {poolCountNum - 1}. Switch to Swap or Liquidity tab to use it.
                </div>
              )}

              <button
                onClick={handleCreatePool}
                disabled={!token0 || !token1 || !initAmount0 || !initAmount1 || isCreating || isConfirming}
                className="w-full py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed font-medium transition-all"
              >
                {isCreating ? 'Confirm in Wallet...' : isConfirming ? 'Creating Pool...' : 'Create Pool'}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
