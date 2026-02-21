'use client';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { HFTEngineABI } from '@/lib/abis';

const cfg = { address: CONTRACTS.HFTEngine, abi: HFTEngineABI } as const;

// ─── READ HOOKS ───────────────────────────────────────────────────────────────

export function useOrderCounter() {
  return useReadContract({ ...cfg, functionName: 'orderCounter' });
}

export function useTotalOrdersProcessed() {
  return useReadContract({ ...cfg, functionName: 'totalOrdersProcessed' });
}

export function useTotalVolumeTraded() {
  return useReadContract({ ...cfg, functionName: 'totalVolumeTraded' });
}

export function useComputeGLTE() {
  return useReadContract({ ...cfg, functionName: 'computeGLTE' });
}

export function useLatestSignal() {
  return useReadContract({ ...cfg, functionName: 'getLatestSignal' });
}

export function useGLTEParams() {
  return useReadContract({ ...cfg, functionName: 'getGLTEParams' });
}

// Prefixed to avoid collision with useDarkPool's useGetOrder
export function useHFTGetOrder(orderId: bigint) {
  return useReadContract({
    ...cfg,
    functionName: 'getOrder',
    args: [orderId],
    query: { enabled: orderId > 0n },
  });
}

export function useGetTraderOrders(trader: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getTraderOrders',
    args: trader ? [trader] : undefined,
    query: { enabled: !!trader },
  });
}

export function useGetTraderStats(trader: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getTraderStats',
    args: trader ? [trader] : undefined,
    query: { enabled: !!trader },
  });
}

// ─── WRITE HOOKS ──────────────────────────────────────────────────────────────

// Prefixed to avoid collision with useDarkPool's usePlaceOrder
export function useHFTPlaceOrder() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const placeOrder = (
    orderType: number,
    direction: number,
    baseCurrency: string,
    quoteCurrency: string,
    quantity: bigint,
    limitPrice: bigint,
    stopPrice: bigint,
    expirySeconds: bigint,
    useGLTE: boolean,
  ) => writeContract({
    ...cfg,
    functionName: 'placeOrder',
    args: [orderType, direction, baseCurrency, quoteCurrency, quantity, limitPrice, stopPrice, expirySeconds, useGLTE],
  });

  return { placeOrder, hash, isPending, isConfirming, isSuccess, error };
}

// Prefixed to avoid collision with useDarkPool's useCancelOrder
export function useHFTCancelOrder() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const cancelOrder = (orderId: bigint) =>
    writeContract({ ...cfg, functionName: 'cancelOrder', args: [orderId] });

  return { cancelOrder, hash, isPending, isConfirming, isSuccess, error };
}

export function useEmitGLTESignal() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const emitGLTESignal = () =>
    writeContract({ ...cfg, functionName: 'emitGLTESignal' });

  return { emitGLTESignal, hash, isPending, isConfirming, isSuccess, error };
}
