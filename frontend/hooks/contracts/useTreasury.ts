'use client';

import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { parseEther, formatEther, keccak256, toHex } from 'viem';
import { CONTRACTS, CURRENCIES, CURRENCY_NAMES } from '@/lib/contracts';
import OICDTreasuryABI from '@/lib/abis/OICDTreasury.json';
import { useCallback, useMemo } from 'react';

// Role constants (keccak256 hashes)
export const ROLES = {
  ADMIN_ROLE: keccak256(toHex('ADMIN_ROLE')),
  ACTIVE_TRADER_ROLE: keccak256(toHex('ACTIVE_TRADER_ROLE')),
  MINTER_ROLE: keccak256(toHex('MINTER_ROLE')),
  BURNER_ROLE: keccak256(toHex('BURNER_ROLE')),
  GOVERNMENT_ROLE: keccak256(toHex('GOVERNMENT_ROLE')),
} as const;

// Scalp trade interface matching contract struct
export interface ScalpTrade {
  tradeId: bigint;
  poolId: bigint;
  tokenIn: `0x${string}`;
  tokenOut: `0x${string}`;
  amountIn: bigint;
  amountOut: bigint;
  profit: bigint;
  timestamp: bigint;
  executor: `0x${string}`;
}

// Currency interface matching contract struct
export interface Currency {
  currencyId: bigint;
  symbol: string;
  name: string;
  totalSupply: bigint;
  reserveBalance: bigint;
  reserveRatio: bigint;
  dailyMintLimit: bigint;
  dailyMinted: bigint;
  lastMintReset: bigint;
  active: boolean;
  oracle: `0x${string}`;
}

// Trading stats interface
export interface TradingStats {
  totalTrades: bigint;
  todayVolume: bigint;
  maxAmount: bigint;
  dailyLimit: bigint;
}

/**
 * Hook to check if user has Active Trader role
 */
export function useHasActiveTraderRole() {
  const { address } = useAccount();

  return useReadContract({
    address: CONTRACTS.OICDTreasury,
    abi: OICDTreasuryABI,
    functionName: 'hasRole',
    args: address ? [ROLES.ACTIVE_TRADER_ROLE, address] : undefined,
    query: { enabled: !!address },
  });
}

/**
 * Hook to check if user has Admin role
 */
export function useHasAdminRole() {
  const { address } = useAccount();

  return useReadContract({
    address: CONTRACTS.OICDTreasury,
    abi: OICDTreasuryABI,
    functionName: 'hasRole',
    args: address ? [ROLES.ADMIN_ROLE, address] : undefined,
    query: { enabled: !!address },
  });
}

/**
 * Hook to execute a scalp trade (Active Trader only)
 */
export function useExecuteScalp() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const executeScalp = useCallback((
    poolId: bigint,
    tokenIn: `0x${string}`,
    tokenOut: `0x${string}`,
    amountIn: string,
    minReturn: string
  ) => {
    writeContract({
      address: CONTRACTS.OICDTreasury,
      abi: OICDTreasuryABI,
      functionName: 'executeScalp',
      args: [poolId, tokenIn, tokenOut, parseEther(amountIn), parseEther(minReturn)],
    });
  }, [writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return { executeScalp, hash, error, isPending, isConfirming, isSuccess };
}

/**
 * Hook to rebalance portfolio (Active Trader only)
 */
export function useRebalancePortfolio() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const rebalance = useCallback(() => {
    writeContract({
      address: CONTRACTS.OICDTreasury,
      abi: OICDTreasuryABI,
      functionName: 'rebalancePortfolio',
    });
  }, [writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return { rebalance, hash, error, isPending, isConfirming, isSuccess };
}

/**
 * Hook to get a specific scalp trade
 */
export function useGetScalpTrade(tradeId: bigint | undefined) {
  const result = useReadContract({
    address: CONTRACTS.OICDTreasury,
    abi: OICDTreasuryABI,
    functionName: 'getScalpTrade',
    args: tradeId !== undefined ? [tradeId] : undefined,
    query: { enabled: tradeId !== undefined },
  });

  const trade = useMemo((): ScalpTrade | null => {
    if (!result.data) return null;
    const data = result.data as [bigint, bigint, `0x${string}`, `0x${string}`, bigint, bigint, bigint, bigint, `0x${string}`];
    return {
      tradeId: data[0],
      poolId: data[1],
      tokenIn: data[2],
      tokenOut: data[3],
      amountIn: data[4],
      amountOut: data[5],
      profit: data[6],
      timestamp: data[7],
      executor: data[8],
    };
  }, [result.data]);

  return { ...result, trade };
}

/**
 * Hook to get recent scalp trades
 */
export function useRecentScalpTrades(count: number = 10) {
  const result = useReadContract({
    address: CONTRACTS.OICDTreasury,
    abi: OICDTreasuryABI,
    functionName: 'getRecentScalpTrades',
    args: [BigInt(count)],
    query: { refetchInterval: 30000 },
  });

  const trades = useMemo((): ScalpTrade[] => {
    if (!result.data) return [];
    const data = result.data as Array<[bigint, bigint, `0x${string}`, `0x${string}`, bigint, bigint, bigint, bigint, `0x${string}`]>;
    return data.map(d => ({
      tradeId: d[0],
      poolId: d[1],
      tokenIn: d[2],
      tokenOut: d[3],
      amountIn: d[4],
      amountOut: d[5],
      profit: d[6],
      timestamp: d[7],
      executor: d[8],
    }));
  }, [result.data]);

  return { ...result, trades };
}

/**
 * Hook to get trading statistics
 */
export function useTradingStats() {
  const result = useReadContract({
    address: CONTRACTS.OICDTreasury,
    abi: OICDTreasuryABI,
    functionName: 'getTradingStats',
    query: { refetchInterval: 15000 },
  });

  const stats = useMemo((): TradingStats | null => {
    if (!result.data) return null;
    const data = result.data as [bigint, bigint, bigint, bigint];
    return {
      totalTrades: data[0],
      todayVolume: data[1],
      maxAmount: data[2],
      dailyLimit: data[3],
    };
  }, [result.data]);

  return { ...result, stats };
}

/**
 * Hook to get scalp trade counter
 */
export function useScalpTradeCounter() {
  return useReadContract({
    address: CONTRACTS.OICDTreasury,
    abi: OICDTreasuryABI,
    functionName: 'scalpTradeCounter',
    query: { refetchInterval: 30000 },
  });
}

/**
 * Hook to get currency details
 */
export function useGetCurrency(currencyId: number) {
  const result = useReadContract({
    address: CONTRACTS.OICDTreasury,
    abi: OICDTreasuryABI,
    functionName: 'getCurrency',
    args: [BigInt(currencyId)],
    query: { refetchInterval: 60000 },
  });

  const currency = useMemo((): Currency | null => {
    if (!result.data) return null;
    const data = result.data as [bigint, string, string, bigint, bigint, bigint, bigint, bigint, bigint, boolean, `0x${string}`];
    return {
      currencyId: data[0],
      symbol: data[1],
      name: data[2],
      totalSupply: data[3],
      reserveBalance: data[4],
      reserveRatio: data[5],
      dailyMintLimit: data[6],
      dailyMinted: data[7],
      lastMintReset: data[8],
      active: data[9],
      oracle: data[10],
    };
  }, [result.data]);

  return { ...result, currency };
}

/**
 * Hook to get user's balance for a currency
 */
export function useCurrencyBalance(currencyId: number) {
  const { address } = useAccount();

  return useReadContract({
    address: CONTRACTS.OICDTreasury,
    abi: OICDTreasuryABI,
    functionName: 'balanceOf',
    args: address ? [address, BigInt(currencyId)] : undefined,
    query: { enabled: !!address, refetchInterval: 15000 },
  });
}

/**
 * Hook to get multiple currency balances
 */
export function useMultipleCurrencyBalances(currencyIds: number[]) {
  const { address } = useAccount();

  const results = currencyIds.map(id =>
    // eslint-disable-next-line react-hooks/rules-of-hooks
    useReadContract({
      address: CONTRACTS.OICDTreasury,
      abi: OICDTreasuryABI,
      functionName: 'balanceOf',
      args: address ? [address, BigInt(id)] : undefined,
      query: { enabled: !!address, refetchInterval: 30000 },
    })
  );

  const balances = useMemo(() => {
    return currencyIds.reduce((acc, id, index) => {
      acc[id] = results[index].data as bigint | undefined;
      return acc;
    }, {} as Record<number, bigint | undefined>);
  }, [currencyIds, results]);

  const isLoading = results.some(r => r.isLoading);

  return { balances, isLoading };
}

/**
 * Hook to mint currency (Minter role only)
 */
export function useMintCurrency() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const mint = useCallback((to: `0x${string}`, currencyId: number, amount: string) => {
    writeContract({
      address: CONTRACTS.OICDTreasury,
      abi: OICDTreasuryABI,
      functionName: 'mint',
      args: [to, BigInt(currencyId), parseEther(amount), '0x'],
    });
  }, [writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return { mint, hash, error, isPending, isConfirming, isSuccess };
}

/**
 * Hook to set target allocation (Admin only)
 */
export function useSetTargetAllocation() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const setAllocation = useCallback((currencyId: number, targetBps: number) => {
    writeContract({
      address: CONTRACTS.OICDTreasury,
      abi: OICDTreasuryABI,
      functionName: 'setTargetAllocation',
      args: [BigInt(currencyId), BigInt(targetBps)],
    });
  }, [writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return { setAllocation, hash, error, isPending, isConfirming, isSuccess };
}

/**
 * Hook to set trading limits (Admin only)
 */
export function useSetTradingLimits() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const setLimits = useCallback((maxScalpAmount: string, dailyLimit: string) => {
    writeContract({
      address: CONTRACTS.OICDTreasury,
      abi: OICDTreasuryABI,
      functionName: 'setTradingLimits',
      args: [parseEther(maxScalpAmount), parseEther(dailyLimit)],
    });
  }, [writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return { setLimits, hash, error, isPending, isConfirming, isSuccess };
}

/**
 * Hook to set Universal AMM address (Admin only)
 */
export function useSetUniversalAMM() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const setAMM = useCallback((ammAddress: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.OICDTreasury,
      abi: OICDTreasuryABI,
      functionName: 'setUniversalAMM',
      args: [ammAddress],
    });
  }, [writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return { setAMM, hash, error, isPending, isConfirming, isSuccess };
}

/**
 * Hook to get total reserve value
 */
export function useTotalReserveValue() {
  return useReadContract({
    address: CONTRACTS.OICDTreasury,
    abi: OICDTreasuryABI,
    functionName: 'totalReserveValue',
    query: { refetchInterval: 60000 },
  });
}

/**
 * Hook to check emergency mode
 */
export function useEmergencyMode() {
  return useReadContract({
    address: CONTRACTS.OICDTreasury,
    abi: OICDTreasuryABI,
    functionName: 'emergencyMode',
    query: { refetchInterval: 30000 },
  });
}

/**
 * Hook to get transaction history
 */
export function useTransactionHistory(startId: number, count: number) {
  return useReadContract({
    address: CONTRACTS.OICDTreasury,
    abi: OICDTreasuryABI,
    functionName: 'getTransactionHistory',
    args: [BigInt(startId), BigInt(count)],
    query: { refetchInterval: 60000 },
  });
}

/**
 * Hook to get target allocation for a currency
 */
export function useTargetAllocation(currencyId: number) {
  return useReadContract({
    address: CONTRACTS.OICDTreasury,
    abi: OICDTreasuryABI,
    functionName: 'targetAllocations',
    args: [BigInt(currencyId)],
    query: { refetchInterval: 60000 },
  });
}

/**
 * Format currency amount for display
 */
export function formatCurrencyAmount(amount: bigint, decimals: number = 18): string {
  return formatEther(amount);
}

/**
 * Get currency name from ID
 */
export function getCurrencyName(currencyId: number): string {
  return CURRENCY_NAMES[currencyId] || `Currency ${currencyId}`;
}

/**
 * Calculate profit percentage
 */
export function calculateProfitPercentage(amountIn: bigint, amountOut: bigint): number {
  if (amountIn === 0n) return 0;
  const profit = amountOut - amountIn;
  return Number((profit * 10000n) / amountIn) / 100;
}
