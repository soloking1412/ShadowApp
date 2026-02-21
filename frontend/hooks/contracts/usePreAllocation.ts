'use client';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { PreAllocationABI } from '@/lib/abis';

const cfg = { address: CONTRACTS.PreAllocation, abi: PreAllocationABI } as const;

export function usePreAllocTotalValidators() {
  return useReadContract({ ...cfg, functionName: 'totalValidators' });
}

export function usePreAllocTotalShareholders() {
  return useReadContract({ ...cfg, functionName: 'totalShareholders' });
}

export function usePreAllocTotalMembers() {
  return useReadContract({ ...cfg, functionName: 'totalMembersRegistered' });
}

export function usePreAllocMember(addr: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getMember',
    args: addr ? [addr] : undefined,
    query: { enabled: !!addr },
  });
}

export function usePreAllocNextClaimAmount(addr: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getNextClaimAmount',
    args: addr ? [addr] : undefined,
    query: { enabled: !!addr },
  });
}

export function usePreAllocValidatorSchedule() {
  return useReadContract({ ...cfg, functionName: 'getValidatorSchedule' });
}

export function usePreAllocShareholderSchedule() {
  return useReadContract({ ...cfg, functionName: 'getShareholderSchedule' });
}

export function usePreAllocNetworkStats() {
  return useReadContract({ ...cfg, functionName: 'networkStats' });
}

export function usePreAllocRegisterAsValidator() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const registerAsValidator = (country: string) =>
    writeContract({ ...cfg, functionName: 'registerAsValidator', args: [country] });

  return { registerAsValidator, hash, isPending, isConfirming, isSuccess, error };
}

export function usePreAllocRegisterAsShareholder() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const registerAsShareholder = (country: string) =>
    writeContract({ ...cfg, functionName: 'registerAsShareholder', args: [country] });

  return { registerAsShareholder, hash, isPending, isConfirming, isSuccess, error };
}

export function usePreAllocClaimSignupBonus() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const claimSignupBonus = () =>
    writeContract({ ...cfg, functionName: 'claimSignupBonus' });

  return { claimSignupBonus, hash, isPending, isConfirming, isSuccess, error };
}

export function usePreAllocClaimMonthly() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const claimMonthlyAllocation = () =>
    writeContract({ ...cfg, functionName: 'claimMonthlyAllocation' });

  return { claimMonthlyAllocation, hash, isPending, isConfirming, isSuccess, error };
}

export function usePreAllocExitEarly() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const exitEarly = () =>
    writeContract({ ...cfg, functionName: 'exitEarly' });

  return { exitEarly, hash, isPending, isConfirming, isSuccess, error };
}
