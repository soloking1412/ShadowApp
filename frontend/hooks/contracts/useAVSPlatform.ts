'use client';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { AVSPlatformABI } from '@/lib/abis';

const cfg = { address: CONTRACTS.AVSPlatform, abi: AVSPlatformABI } as const;

// ─── READ HOOKS ───────────────────────────────────────────────────────────────

export function useAVSTotalAssets() {
  return useReadContract({ ...cfg, functionName: 'totalAssets' });
}

export function useAVSTotalCountries() {
  return useReadContract({ ...cfg, functionName: 'totalCountries' });
}

export function useAVSTotalVolumeOICD() {
  return useReadContract({ ...cfg, functionName: 'totalVolumeOICD' });
}

export function useAVSAsset(assetId: bigint) {
  return useReadContract({
    ...cfg,
    functionName: 'getAsset',
    args: [assetId],
    query: { enabled: assetId > 0n },
  });
}

export function useAVSCountryProfile(code: string) {
  return useReadContract({
    ...cfg,
    functionName: 'getCountryProfile',
    args: [code],
    query: { enabled: !!code },
  });
}

export function useAVSAssetsByCountry(code: string) {
  return useReadContract({
    ...cfg,
    functionName: 'getAssetsByCountry',
    args: [code],
    query: { enabled: !!code },
  });
}

export function useAVSPlatformStats() {
  return useReadContract({ ...cfg, functionName: 'platformStats' });
}

// ─── WRITE HOOKS ──────────────────────────────────────────────────────────────

export function useAVSRegisterCountry() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const registerCountry = (code: string, name: string, debtCapacityOICD: bigint) =>
    writeContract({ ...cfg, functionName: 'registerCountry', args: [code, name, debtCapacityOICD] });

  return { registerCountry, hash, isPending, isConfirming, isSuccess, error };
}

export function useAVSIssueAllocation() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const issueAllocation = (countryCode: string, multiplierBps: bigint) =>
    writeContract({ ...cfg, functionName: 'issueAllocation', args: [countryCode, multiplierBps] });

  return { issueAllocation, hash, isPending, isConfirming, isSuccess, error };
}

export function useAVSListAsset() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const listAsset = (
    countryCode: string,
    assetType: number,
    name: string,
    totalUnits: bigint,
    pricePerUnitOICD: bigint,
    instrumentType: number,
    description: string,
    ipfsMetadata: string,
  ) => writeContract({
    ...cfg,
    functionName: 'listAsset',
    args: [countryCode, assetType, name, totalUnits, pricePerUnitOICD, instrumentType, description, ipfsMetadata],
  });

  return { listAsset, hash, isPending, isConfirming, isSuccess, error };
}

export function useAVSPurchaseAsset() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const purchaseAsset = (assetId: bigint, units: bigint) =>
    writeContract({ ...cfg, functionName: 'purchaseAsset', args: [assetId, units] });

  return { purchaseAsset, hash, isPending, isConfirming, isSuccess, error };
}

export function useAVSSettleRevenue() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const settleRevenue = (assetId: bigint) =>
    writeContract({ ...cfg, functionName: 'settleRevenue', args: [assetId] });

  return { settleRevenue, hash, isPending, isConfirming, isSuccess, error };
}
