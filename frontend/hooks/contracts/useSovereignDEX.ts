'use client';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { SovereignDEXABI } from '@/lib/abis';

const cfg = { address: CONTRACTS.SovereignDEX, abi: SovereignDEXABI } as const;

// ─── READ HOOKS ───────────────────────────────────────────────────────────────

export function useSwapCounter() {
  return useReadContract({ ...cfg, functionName: 'swapCounter' });
}

export function useTotalVolumeUSD() {
  return useReadContract({ ...cfg, functionName: 'totalVolumeUSD' });
}

export function useActiveSwaps() {
  return useReadContract({ ...cfg, functionName: 'activeSwaps' });
}

export function useSettledSwaps() {
  return useReadContract({ ...cfg, functionName: 'settledSwaps' });
}

export function useGetSwap(swapId: bigint) {
  return useReadContract({
    ...cfg,
    functionName: 'getSwap',
    args: [swapId],
    query: { enabled: swapId > 0n },
  });
}

export function useGetUserSwaps(user: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getUserSwaps',
    args: user ? [user] : undefined,
    query: { enabled: !!user },
  });
}

export function useGetPairStats(offerCcy: string, requestCcy: string) {
  return useReadContract({
    ...cfg,
    functionName: 'getPairStats',
    args: [offerCcy, requestCcy],
    query: { enabled: !!offerCcy && !!requestCcy },
  });
}

// ─── WRITE HOOKS ──────────────────────────────────────────────────────────────

export function useCreateSwap() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const createSwap = (
    offerCurrency: string,
    requestCurrency: string,
    offerAmount: bigint,
    requestAmount: bigint,
    expirySeconds: bigint,
  ) => writeContract({ ...cfg, functionName: 'createSwap', args: [offerCurrency, requestCurrency, offerAmount, requestAmount, expirySeconds] });

  return { createSwap, hash, isPending, isConfirming, isSuccess, error };
}

export function useMatchSwap() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const matchSwap = (swapId: bigint) =>
    writeContract({ ...cfg, functionName: 'matchSwap', args: [swapId] });

  return { matchSwap, hash, isPending, isConfirming, isSuccess, error };
}

export function useDepositConfirmation() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const depositConfirmation = (swapId: bigint) =>
    writeContract({ ...cfg, functionName: 'depositConfirmation', args: [swapId] });

  return { depositConfirmation, hash, isPending, isConfirming, isSuccess, error };
}

export function useCancelSwap() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const cancelSwap = (swapId: bigint) =>
    writeContract({ ...cfg, functionName: 'cancelSwap', args: [swapId] });

  return { cancelSwap, hash, isPending, isConfirming, isSuccess, error };
}

export function useExpireSwap() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const expireSwap = (swapId: bigint) =>
    writeContract({ ...cfg, functionName: 'expireSwap', args: [swapId] });

  return { expireSwap, hash, isPending, isConfirming, isSuccess, error };
}
