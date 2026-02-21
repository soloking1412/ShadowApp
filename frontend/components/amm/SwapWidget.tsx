'use client';

import { useState } from 'react';
import { formatUnits, parseUnits } from 'viem';
import { useGetAmountOut, useSwap, useGetPool } from '@/hooks/contracts/useUniversalAMM';

interface SwapWidgetProps {
  poolId: bigint;
  poolExists?: boolean;
}

export function SwapWidget({ poolId, poolExists = true }: SwapWidgetProps) {
  const [amountIn, setAmountIn] = useState('');
  const [slippage, setSlippage] = useState('0.5');

  const { data: pool } = useGetPool(poolId);
  const poolData = pool as any;

  const { data: amountOut } = useGetAmountOut(
    poolId,
    poolData?.token0 as `0x${string}`,
    amountIn ? parseUnits(amountIn, 18) : undefined
  );
  const { swap, isPending, isConfirming, isSuccess } = useSwap();

  const handleSwap = () => {
    if (!poolData || !amountIn) return;

    const amountInWei = parseUnits(amountIn, 18);
    const slippageBps = parseFloat(slippage) * 100;
    const minAmountOut = typeof amountOut === 'bigint'
      ? (amountOut * BigInt(10000 - slippageBps)) / 10000n
      : 0n;

    swap(poolId, poolData.token0 as `0x${string}`, amountInWei, minAmountOut);
  };

  if (!poolExists) {
    return (
      <div className="p-8 text-center bg-white/5 border border-white/10 rounded-lg">
        <div className="text-4xl mb-3">🔄</div>
        <p className="text-gray-300 font-medium mb-1">No pools created yet</p>
        <p className="text-gray-500 text-sm">Switch to the "+ Create Pool" tab to create the first AMM pool.</p>
      </div>
    );
  }

  if (!poolData || !poolData.token0) {
    return (
      <div className="p-6 text-center bg-white/5 border border-white/10 rounded-lg">
        <p className="text-gray-400 text-sm">Pool #{poolId.toString()} not found. Enter a valid pool ID above.</p>
      </div>
    );
  }

  const token0Short = String(poolData.token0).slice(0, 6) + '…' + String(poolData.token0).slice(-4);
  const token1Short = String(poolData.token1).slice(0, 6) + '…' + String(poolData.token1).slice(-4);

  return (
    <div className="max-w-md space-y-4">
      <div className="space-y-2">
        <label className="text-sm font-medium text-gray-300">From</label>
        <div className="flex gap-2">
          <input
            type="number"
            value={amountIn}
            onChange={(e) => setAmountIn(e.target.value)}
            placeholder="0.0"
            className="flex-1 bg-white/5 border border-white/10 rounded-lg px-4 py-2 text-white placeholder-gray-600 focus:outline-none focus:border-green-500"
          />
          <div className="px-3 py-2 bg-white/10 rounded-lg text-gray-300 text-xs font-mono" title={poolData.token0}>
            {token0Short}
          </div>
        </div>
      </div>

      <div className="flex justify-center text-gray-400 text-xl">↓</div>

      <div className="space-y-2">
        <label className="text-sm font-medium text-gray-300">To (estimated)</label>
        <div className="flex gap-2">
          <input
            type="text"
            value={typeof amountOut === 'bigint' ? formatUnits(amountOut, 18) : '0.0'}
            readOnly
            className="flex-1 bg-white/5 border border-white/10 rounded-lg px-4 py-2 text-gray-300"
          />
          <div className="px-3 py-2 bg-white/10 rounded-lg text-gray-300 text-xs font-mono" title={poolData.token1}>
            {token1Short}
          </div>
        </div>
      </div>

      <div className="space-y-2">
        <label className="text-sm font-medium text-gray-300">Slippage Tolerance</label>
        <div className="flex gap-2">
          {['0.1', '0.5', '1.0'].map((s) => (
            <button
              key={s}
              onClick={() => setSlippage(s)}
              className={`px-3 py-1 rounded text-sm ${slippage === s ? 'bg-green-600 text-white' : 'bg-white/5 text-gray-400 hover:bg-white/10'}`}
            >
              {s}%
            </button>
          ))}
          <input
            type="number"
            value={slippage}
            onChange={(e) => setSlippage(e.target.value)}
            step="0.1"
            className="w-16 bg-white/5 border border-white/10 rounded-lg px-2 py-1 text-white text-sm focus:outline-none focus:border-green-500"
          />
        </div>
      </div>

      {poolData.feeBasisPoints !== undefined && (
        <div className="flex justify-between text-xs text-gray-500 px-1">
          <span>Pool fee</span>
          <span>{(Number(poolData.feeBasisPoints) / 100).toFixed(2)}%</span>
        </div>
      )}

      <button
        onClick={handleSwap}
        disabled={!amountIn || isPending || isConfirming}
        className="w-full py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed font-medium transition-all"
      >
        {isPending ? 'Confirm in Wallet...' : isConfirming ? 'Swapping...' : isSuccess ? 'Swap Complete!' : 'Swap'}
      </button>

      {isSuccess && (
        <div className="p-3 bg-green-500/10 border border-green-500/30 rounded-lg text-green-400 text-sm">
          Swap completed successfully!
        </div>
      )}
    </div>
  );
}
