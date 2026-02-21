'use client';

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits } from 'viem';
import { CONTRACTS } from '@/lib/contracts';
import ForexReservesTrackerABI from '@/lib/abis/ForexReservesTracker.json';

const safeUnits = (v: string, d = 18) => { try { return parseUnits(v || '0', d); } catch { return 0n; } };

const contract = {
  address: CONTRACTS.ForexReservesTracker,
  abi: ForexReservesTrackerABI,
};

export function useTotalGlobalReservesUSD() {
  return useReadContract({
    ...contract,
    functionName: 'totalGlobalReservesUSD',
    query: { enabled: !!CONTRACTS.ForexReservesTracker },
  });
}

export function useForexTradeCounter() {
  return useReadContract({
    ...contract,
    functionName: 'tradeCounter',
    query: { enabled: !!CONTRACTS.ForexReservesTracker },
  });
}

export function useGetAllCurrencies() {
  return useReadContract({
    ...contract,
    functionName: 'getAllCurrencies',
    query: { enabled: !!CONTRACTS.ForexReservesTracker },
  });
}

export function useGetReserve(currencyId?: bigint) {
  return useReadContract({
    ...contract,
    functionName: 'getReserve',
    args: currencyId !== undefined ? [currencyId] : undefined,
    query: { enabled: currencyId !== undefined && !!CONTRACTS.ForexReservesTracker },
  });
}

export function useGetForexCorridor(fromId?: bigint, toId?: bigint) {
  return useReadContract({
    ...contract,
    functionName: 'getCorridor',
    args: fromId !== undefined && toId !== undefined ? [fromId, toId] : undefined,
    query: { enabled: fromId !== undefined && toId !== undefined && !!CONTRACTS.ForexReservesTracker },
  });
}

export function useGetActiveOpportunities() {
  return useReadContract({
    ...contract,
    functionName: 'getActiveOpportunities',
    query: { enabled: !!CONTRACTS.ForexReservesTracker },
  });
}

export function useUpdateReserve() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const updateReserve = (
    currencyId: bigint,
    amountUSD: string,
    reserveType: number,
    note: string,
  ) => {
    writeContract({
      ...contract,
      functionName: 'updateReserve',
      args: [currencyId, safeUnits(amountUSD), reserveType, note],
    });
  };

  return { updateReserve, isPending, isConfirming, isSuccess, error };
}

export function useUpdateCorridor() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const updateCorridor = (fromId: bigint, toId: bigint, rate: bigint, volume: bigint) => {
    writeContract({
      ...contract,
      functionName: 'updateCorridor',
      args: [fromId, toId, rate, volume],
    });
  };

  return { updateCorridor, isPending, isConfirming, isSuccess, error };
}

export function useRecordForexTrade() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const recordTrade = (
    fromId: bigint,
    toId: bigint,
    fromAmount: bigint,
    toAmount: bigint,
    counterparty: `0x${string}`,
  ) => {
    writeContract({
      ...contract,
      functionName: 'recordTrade',
      args: [fromId, toId, fromAmount, toAmount, counterparty],
    });
  };

  return { recordTrade, isPending, isConfirming, isSuccess, error };
}
