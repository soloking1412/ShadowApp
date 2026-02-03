'use client';

import { useState } from 'react';
import { formatUnits, parseUnits } from 'viem';
import { useGetAmountOut, useSwap, useGetPool } from '@/hooks/contracts';

interface SwapWidgetProps {
  poolId: bigint;
}

export function SwapWidget({ poolId }: SwapWidgetProps) {
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
    const minAmountOut = typeof amountOut === "bigint"
      ? (amountOut * BigInt(10000 - slippageBps)) / 10000n
      : 0n;

    swap(poolId, poolData.token0 as `0x${string}`, amountInWei, minAmountOut);
  };

  if (!poolData) {
    return <div>Pool not found</div>;
  }

  return (
    <div className="border rounded-lg p-6 space-y-4 max-w-md">
      <h2 className="text-xl font-bold">Swap</h2>

      <div className="space-y-2">
        <label className="text-sm font-medium">From</label>
        <div className="flex gap-2">
          <input
            type="number"
            value={amountIn}
            onChange={(e) => setAmountIn(e.target.value)}
            placeholder="0.0"
            className="flex-1 px-4 py-2 border rounded-lg"
          />
          <div className="px-4 py-2 bg-gray-100 rounded-lg">
            Token 0
          </div>
        </div>
      </div>

      <div className="flex justify-center">
        <button className="p-2 hover:bg-gray-100 rounded-full">
          ↓
        </button>
      </div>

      <div className="space-y-2">
        <label className="text-sm font-medium">To (estimated)</label>
        <div className="flex gap-2">
          <input
            type="text"
            value={typeof amountOut === 'bigint' ? formatUnits(amountOut, 18) : '0.0'}
            readOnly
            className="flex-1 px-4 py-2 border rounded-lg bg-gray-50"
          />
          <div className="px-4 py-2 bg-gray-100 rounded-lg">
            Token 1
          </div>
        </div>
      </div>

      <div className="space-y-2">
        <label className="text-sm font-medium">Slippage Tolerance (%)</label>
        <input
          type="number"
          value={slippage}
          onChange={(e) => setSlippage(e.target.value)}
          step="0.1"
          className="w-full px-4 py-2 border rounded-lg"
        />
      </div>

      <button
        onClick={handleSwap}
        disabled={!amountIn || isPending || isConfirming}
        className="w-full py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed font-medium"
      >
        {isPending || isConfirming ? 'Swapping...' : isSuccess ? 'Swap Complete!' : 'Swap'}
      </button>

      {isSuccess && (
        <div className="p-3 bg-green-50 text-green-800 rounded-lg text-sm">
          Swap completed successfully!
        </div>
      )}
    </div>
  );
}
