'use client';

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits } from 'viem';
import { CONTRACTS } from '@/lib/contracts';
import LiquidityAsAServiceABI from '@/lib/abis/LiquidityAsAService.json';

const contract = {
  address: CONTRACTS.LiquidityAsAService,
  abi: LiquidityAsAServiceABI,
};

export function useLaaSPool(poolId?: bigint) {
  return useReadContract({
    ...contract,
    functionName: 'getPool',
    args: poolId !== undefined ? [poolId] : undefined,
    query: { enabled: poolId !== undefined && !!CONTRACTS.LiquidityAsAService },
  });
}

export function useLaaSPoolCounter() {
  return useReadContract({
    ...contract,
    functionName: 'poolCounter',
    query: { enabled: !!CONTRACTS.LiquidityAsAService },
  });
}

export function useProviderInfo(poolId?: bigint, address?: `0x${string}`) {
  return useReadContract({
    ...contract,
    functionName: 'getProviderInfo',
    args: poolId !== undefined && address ? [poolId, address] : undefined,
    query: { enabled: poolId !== undefined && !!address && !!CONTRACTS.LiquidityAsAService },
  });
}

export function useCreateLaaSPool() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const createPool = (
    poolType: number,
    baseCurrency: string,
    quoteCurrency: string,
    targetLiquidity: string,
    feeBps: number
  ) => {
    writeContract({
      ...contract,
      functionName: 'createPool',
      args: [BigInt(poolType), baseCurrency, quoteCurrency, parseUnits(targetLiquidity, 18), BigInt(feeBps)],
    });
  };

  return { createPool, isPending, isConfirming, isSuccess, error };
}

export function useProvideLiquidity() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const provideLiquidity = (poolId: bigint, amountEth: string) => {
    writeContract({
      ...contract,
      functionName: 'provideLiquidity',
      args: [poolId],
      value: parseUnits(amountEth, 18),
    });
  };

  return { provideLiquidity, isPending, isConfirming, isSuccess, error };
}

export function useWithdrawLiquidity() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const withdrawLiquidity = (poolId: bigint) => {
    writeContract({
      ...contract,
      functionName: 'withdrawLiquidity',
      args: [poolId],
    });
  };

  return { withdrawLiquidity, isPending, isConfirming, isSuccess, error };
}

export const POOL_TYPES = ['FX', 'Commodities', 'Securities', 'Derivatives', 'CrossBorder', 'DarkPool'] as const;
