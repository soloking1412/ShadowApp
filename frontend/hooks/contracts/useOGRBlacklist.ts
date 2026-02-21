'use client';

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import OGRBlacklistABI from '@/lib/abis/OGRBlacklist.json';

const contract = {
  address: CONTRACTS.OGRBlacklist,
  abi: OGRBlacklistABI,
};

export function useIsBlacklisted(address?: `0x${string}`) {
  return useReadContract({
    ...contract,
    functionName: 'isBlacklisted',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!CONTRACTS.OGRBlacklist },
  });
}

export function useIsCompanyBlacklisted(name?: string) {
  return useReadContract({
    ...contract,
    functionName: 'isCompanyBlacklisted',
    args: name ? [name] : undefined,
    query: { enabled: !!name && !!CONTRACTS.OGRBlacklist },
  });
}

export function useIsCountryBlacklisted(code?: string) {
  return useReadContract({
    ...contract,
    functionName: 'isCountryBlacklisted',
    args: code ? [code] : undefined,
    query: { enabled: !!code && !!CONTRACTS.OGRBlacklist },
  });
}

export function useBlacklistAddressCount() {
  return useReadContract({
    ...contract,
    functionName: 'getBlacklistedAddressCount',
    query: { enabled: !!CONTRACTS.OGRBlacklist },
  });
}

export function useBlacklistCompanyCount() {
  return useReadContract({
    ...contract,
    functionName: 'getBlacklistedCompanyCount',
    query: { enabled: !!CONTRACTS.OGRBlacklist },
  });
}

export function useBlacklistCountryCount() {
  return useReadContract({
    ...contract,
    functionName: 'getBlacklistedCountryCount',
    query: { enabled: !!CONTRACTS.OGRBlacklist },
  });
}

export function useAddToBlacklist() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const addToBlacklist = (entityType: number, identifier: string, reason: string) => {
    writeContract({
      ...contract,
      functionName: 'addToBlacklist',
      args: [entityType, identifier, reason],
    });
  };

  return { addToBlacklist, isPending, isConfirming, isSuccess, error };
}

export function useAddAddressToBlacklist() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const addAddressToBlacklist = (addr: `0x${string}`, reason: string) => {
    writeContract({
      ...contract,
      functionName: 'addAddressToBlacklist',
      args: [addr, reason],
    });
  };

  return { addAddressToBlacklist, isPending, isConfirming, isSuccess, error };
}

export function useRemoveFromBlacklist() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const removeFromBlacklist = (entityType: number, identifier: string) => {
    writeContract({
      ...contract,
      functionName: 'removeFromBlacklist',
      args: [entityType, identifier],
    });
  };

  return { removeFromBlacklist, isPending, isConfirming, isSuccess, error };
}

export function useRemoveAddressFromBlacklist() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const removeAddressFromBlacklist = (addr: `0x${string}`) => {
    writeContract({
      ...contract,
      functionName: 'removeAddressFromBlacklist',
      args: [addr],
    });
  };

  return { removeAddressFromBlacklist, isPending, isConfirming, isSuccess, error };
}
