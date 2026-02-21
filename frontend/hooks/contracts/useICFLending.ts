'use client';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { ICFLendingABI } from '@/lib/abis';

const cfg = { address: CONTRACTS.ICFLending, abi: ICFLendingABI } as const;

export function useICFLoanCounter() {
  return useReadContract({ ...cfg, functionName: 'loanCounter' });
}

export function useICFTotalLoansIssued() {
  return useReadContract({ ...cfg, functionName: 'totalLoansIssued' });
}

export function useICFActiveLoans() {
  return useReadContract({ ...cfg, functionName: 'activeLoans' });
}

export function useICFGetLoan(loanId: bigint) {
  return useReadContract({
    ...cfg,
    functionName: 'getLoan',
    args: [loanId],
    query: { enabled: loanId > 0n },
  });
}

export function useICFBorrowerLoans(addr: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getBorrowerLoans',
    args: addr ? [addr] : undefined,
    query: { enabled: !!addr },
  });
}

export function useICFGScore(addr: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getGScore',
    args: addr ? [addr] : undefined,
    query: { enabled: !!addr },
  });
}

export function useICFPlatformStats() {
  return useReadContract({ ...cfg, functionName: 'platformStats' });
}

export function useICFApplyICFLoan() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const applyICFLoan = (tier: number, principalOICD: bigint, termChoice: number, purpose: string) =>
    writeContract({ ...cfg, functionName: 'applyICFLoan', args: [tier, principalOICD, termChoice, purpose] });

  return { applyICFLoan, hash, isPending, isConfirming, isSuccess, error };
}

export function useICFApplyFirst90() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const applyFirst90 = (principalOICD: bigint, purpose: string) =>
    writeContract({ ...cfg, functionName: 'applyFirst90', args: [principalOICD, purpose] });

  return { applyFirst90, hash, isPending, isConfirming, isSuccess, error };
}

export function useICFProveRevenue() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const proveRevenue = (loanId: bigint) =>
    writeContract({ ...cfg, functionName: 'proveRevenue', args: [loanId] });

  return { proveRevenue, hash, isPending, isConfirming, isSuccess, error };
}

export function useICFApplyFFE() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const applyFFE = (educationCostOICD: bigint, institution: string) =>
    writeContract({ ...cfg, functionName: 'applyFFE', args: [educationCostOICD, institution] });

  return { applyFFE, hash, isPending, isConfirming, isSuccess, error };
}

export function useICFConfirmEmployment() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const confirmEmployment = (loanId: bigint) =>
    writeContract({ ...cfg, functionName: 'confirmEmployment', args: [loanId] });

  return { confirmEmployment, hash, isPending, isConfirming, isSuccess, error };
}

export function useICFRepayLoan() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const repayLoan = (loanId: bigint, amountOICD: bigint) =>
    writeContract({ ...cfg, functionName: 'repayLoan', args: [loanId, amountOICD] });

  return { repayLoan, hash, isPending, isConfirming, isSuccess, error };
}
