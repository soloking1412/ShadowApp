'use client';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { BondAuctionHouseABI } from '@/lib/abis';

const cfg = { address: CONTRACTS.BondAuctionHouse, abi: BondAuctionHouseABI } as const;

// ─── READ HOOKS ───────────────────────────────────────────────────────────────

export function useAuctionCounter() {
  return useReadContract({ ...cfg, functionName: 'auctionCounter' });
}

export function useTotalCapitalRaised() {
  return useReadContract({ ...cfg, functionName: 'totalCapitalRaised' });
}

export function useGetAuction(auctionId: bigint) {
  return useReadContract({
    ...cfg,
    functionName: 'getAuction',
    args: [auctionId],
    query: { enabled: auctionId > 0n },
  });
}

export function useGetAuctionBids(auctionId: bigint) {
  return useReadContract({
    ...cfg,
    functionName: 'getAuctionBids',
    args: [auctionId],
    query: { enabled: auctionId > 0n },
  });
}

export function useGetIssuerAuctions(issuer: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getIssuerAuctions',
    args: issuer ? [issuer] : undefined,
    query: { enabled: !!issuer },
  });
}

export function useGetCurrentDutchPrice(auctionId: bigint) {
  return useReadContract({
    ...cfg,
    functionName: 'getCurrentDutchPrice',
    args: [auctionId],
    query: { enabled: auctionId > 0n },
  });
}

// ─── WRITE HOOKS ──────────────────────────────────────────────────────────────

export function useCreateDutchAuction() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const createDutchAuction = (
    bondName: string,
    bondISIN: string,
    faceValue: bigint,
    totalSupply: bigint,
    startPrice: bigint,
    minPrice: bigint,
    priceDecrement: bigint,
    decrementInterval: bigint,
    durationSeconds: bigint,
  ) => writeContract({
    ...cfg,
    functionName: 'createDutchAuction',
    args: [bondName, bondISIN, faceValue, totalSupply, startPrice, minPrice, priceDecrement, decrementInterval, durationSeconds],
  });

  return { createDutchAuction, hash, isPending, isConfirming, isSuccess, error };
}

export function useCreateSealedBidAuction() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const createSealedBidAuction = (
    bondName: string,
    bondISIN: string,
    faceValue: bigint,
    totalSupply: bigint,
    reservePrice: bigint,
    durationSeconds: bigint,
  ) => writeContract({
    ...cfg,
    functionName: 'createSealedBidAuction',
    args: [bondName, bondISIN, faceValue, totalSupply, reservePrice, durationSeconds],
  });

  return { createSealedBidAuction, hash, isPending, isConfirming, isSuccess, error };
}

export function useDutchBid() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const dutchBid = (auctionId: bigint, quantity: bigint) =>
    writeContract({ ...cfg, functionName: 'dutchBid', args: [auctionId, quantity] });

  return { dutchBid, hash, isPending, isConfirming, isSuccess, error };
}

export function useSealedBid() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const sealedBid = (auctionId: bigint, bidPrice: bigint, quantity: bigint) =>
    writeContract({ ...cfg, functionName: 'sealedBid', args: [auctionId, bidPrice, quantity] });

  return { sealedBid, hash, isPending, isConfirming, isSuccess, error };
}

export function useSettleSealedAuction() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const settleSealedAuction = (auctionId: bigint) =>
    writeContract({ ...cfg, functionName: 'settleSealedAuction', args: [auctionId] });

  return { settleSealedAuction, hash, isPending, isConfirming, isSuccess, error };
}

export function useCancelAuction() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const cancelAuction = (auctionId: bigint) =>
    writeContract({ ...cfg, functionName: 'cancelAuction', args: [auctionId] });

  return { cancelAuction, hash, isPending, isConfirming, isSuccess, error };
}
