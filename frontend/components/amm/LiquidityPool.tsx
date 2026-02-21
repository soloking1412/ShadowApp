'use client';

import { useState } from 'react';
import { formatUnits, parseUnits } from 'viem';
import { useGetPool, useGetReserves, useAddLiquidity, useRemoveLiquidity, useGetUserLiquidity } from '@/hooks/contracts/useUniversalAMM';
import { useAccount } from 'wagmi';

interface LiquidityPoolProps {
  poolId: bigint;
  poolExists?: boolean;
}

export function LiquidityPool({ poolId, poolExists = true }: LiquidityPoolProps) {
  const [amount0, setAmount0] = useState('');
  const [amount1, setAmount1] = useState('');
  const [sharesAmount, setSharesAmount] = useState('');
  const [mode, setMode] = useState<'add' | 'remove'>('add');

  const { address } = useAccount();
  const { data: pool } = useGetPool(poolId);
  const { data: reserves } = useGetReserves(poolId);
  const { data: userLiquidity } = useGetUserLiquidity(poolId, address);
  const { addLiquidity, isPending: isAdding, isSuccess: addSuccess } = useAddLiquidity();
  const { removeLiquidity, isPending: isRemoving, isSuccess: removeSuccess } = useRemoveLiquidity();

  const reserve0 = reserves && Array.isArray(reserves) && reserves.length >= 2 ? reserves[0] : 0n;
  const reserve1 = reserves && Array.isArray(reserves) && reserves.length >= 2 ? reserves[1] : 0n;

  const handleAddLiquidity = () => {
    if (!amount0 || !amount1) return;

    const amount0Wei = parseUnits(amount0, 18);
    const amount1Wei = parseUnits(amount1, 18);
    const minShares = 0n; // Could calculate based on slippage

    addLiquidity(poolId, amount0Wei, amount1Wei, minShares);
  };

  const handleRemoveLiquidity = () => {
    if (!sharesAmount) return;

    const sharesWei = parseUnits(sharesAmount, 18);
    const minAmount0 = 0n; // Could calculate based on slippage
    const minAmount1 = 0n;

    removeLiquidity(poolId, sharesWei, minAmount0, minAmount1);
  };

  const poolData = pool as any;

  if (!poolExists) {
    return (
      <div className="p-8 text-center bg-white/5 border border-white/10 rounded-lg">
        <div className="text-4xl mb-3">💧</div>
        <p className="text-gray-300 font-medium mb-1">No pools created yet</p>
        <p className="text-gray-500 text-sm">Switch to the "+ Create Pool" tab to create the first AMM pool.</p>
      </div>
    );
  }

  if (!pool) {
    return (
      <div className="p-6 text-center bg-white/5 border border-white/10 rounded-lg">
        <p className="text-gray-400 text-sm">Pool #{poolId.toString()} not found. Enter a valid pool ID above.</p>
      </div>
    );
  }

  return (
    <div className="border rounded-lg p-6 space-y-4 max-w-2xl">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-bold">Liquidity Pool #{poolId.toString()}</h2>
        {poolData?.active ? (
          <span className="px-3 py-1 bg-green-100 text-green-800 rounded-full text-sm">
            Active
          </span>
        ) : (
          <span className="px-3 py-1 bg-gray-100 text-gray-800 rounded-full text-sm">
            Inactive
          </span>
        )}
      </div>

      <div className="grid grid-cols-2 gap-4 p-4 bg-gray-50 rounded-lg">
        <div>
          <p className="text-sm text-gray-500">Reserve 0</p>
          <p className="text-lg font-semibold">{formatUnits(reserve0, 18)}</p>
        </div>
        <div>
          <p className="text-sm text-gray-500">Reserve 1</p>
          <p className="text-lg font-semibold">{formatUnits(reserve1, 18)}</p>
        </div>
        <div>
          <p className="text-sm text-gray-500">Total Shares</p>
          <p className="text-lg font-semibold">{formatUnits(poolData?.totalShares || 0n, 18)}</p>
        </div>
        <div>
          <p className="text-sm text-gray-500">Fee</p>
          <p className="text-lg font-semibold">{(Number(poolData?.feeBasisPoints || 0) / 100).toFixed(2)}%</p>
        </div>
      </div>

      {typeof userLiquidity === 'bigint' && userLiquidity > 0n ? (
        <div className="p-4 bg-blue-50 rounded-lg">
          <p className="text-sm text-blue-600">Your Liquidity</p>
          <p className="text-xl font-bold text-blue-900">{formatUnits(userLiquidity, 18)} shares</p>
        </div>
      ) : null}

      <div className="flex gap-2 border-b">
        <button
          onClick={() => setMode('add')}
          className={`px-4 py-2 font-medium ${
            mode === 'add'
              ? 'border-b-2 border-blue-600 text-blue-600'
              : 'text-gray-500'
          }`}
        >
          Add Liquidity
        </button>
        <button
          onClick={() => setMode('remove')}
          className={`px-4 py-2 font-medium ${
            mode === 'remove'
              ? 'border-b-2 border-blue-600 text-blue-600'
              : 'text-gray-500'
          }`}
        >
          Remove Liquidity
        </button>
      </div>

      {mode === 'add' ? (
        <div className="space-y-4">
          <div className="space-y-2">
            <label className="text-sm font-medium">Amount Token 0</label>
            <input
              type="number"
              value={amount0}
              onChange={(e) => setAmount0(e.target.value)}
              placeholder="0.0"
              className="w-full px-4 py-2 border rounded-lg"
            />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">Amount Token 1</label>
            <input
              type="number"
              value={amount1}
              onChange={(e) => setAmount1(e.target.value)}
              placeholder="0.0"
              className="w-full px-4 py-2 border rounded-lg"
            />
          </div>

          <button
            onClick={handleAddLiquidity}
            disabled={!amount0 || !amount1 || isAdding}
            className="w-full py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed font-medium"
          >
            {isAdding ? 'Adding...' : addSuccess ? 'Added!' : 'Add Liquidity'}
          </button>
        </div>
      ) : (
        <div className="space-y-4">
          <div className="space-y-2">
            <label className="text-sm font-medium">Shares to Remove</label>
            <input
              type="number"
              value={sharesAmount}
              onChange={(e) => setSharesAmount(e.target.value)}
              placeholder="0.0"
              className="w-full px-4 py-2 border rounded-lg"
            />
          </div>

          <button
            onClick={handleRemoveLiquidity}
            disabled={!sharesAmount || isRemoving}
            className="w-full py-3 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:bg-gray-300 disabled:cursor-not-allowed font-medium"
          >
            {isRemoving ? 'Removing...' : removeSuccess ? 'Removed!' : 'Remove Liquidity'}
          </button>
        </div>
      )}
    </div>
  );
}
