'use client';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { OTDTokenABI } from '@/lib/abis';

const cfg = { address: CONTRACTS.OTDToken, abi: OTDTokenABI } as const;

// ─── READ HOOKS ───────────────────────────────────────────────────────────────

export function useOTDTotalSupply() {
  return useReadContract({ ...cfg, functionName: 'OTD_TOTAL_SUPPLY' });
}

export function useOTDTotalHolders() {
  return useReadContract({ ...cfg, functionName: 'totalHolders' });
}

export function useOTDTotalVotes() {
  return useReadContract({ ...cfg, functionName: 'totalVotesCreated' });
}

export function useOTDHolder(addr: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getHolder',
    args: addr ? [addr] : undefined,
    query: { enabled: !!addr },
  });
}

export function useOTDVote(voteId: bigint) {
  return useReadContract({
    ...cfg,
    functionName: 'getVote',
    args: [voteId],
    query: { enabled: voteId > 0n },
  });
}

export function useOTDCountryAllocation(code: string) {
  return useReadContract({
    ...cfg,
    functionName: 'getCountryAllocation',
    args: [code],
    query: { enabled: !!code },
  });
}

// ─── WRITE HOOKS ──────────────────────────────────────────────────────────────

export function useOTDRegisterAsValidator() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const registerAsValidator = () =>
    writeContract({ ...cfg, functionName: 'registerAsValidator' });

  return { registerAsValidator, hash, isPending, isConfirming, isSuccess, error };
}

export function useOTDRegisterAsShareholder() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const registerAsShareholder = () =>
    writeContract({ ...cfg, functionName: 'registerAsShareholder' });

  return { registerAsShareholder, hash, isPending, isConfirming, isSuccess, error };
}

export function useOTDAllocate() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const allocateOTD = (recipient: `0x${string}`, amount: bigint, allocationType: number) =>
    writeContract({ ...cfg, functionName: 'allocateOTD', args: [recipient, amount, allocationType] });

  return { allocateOTD, hash, isPending, isConfirming, isSuccess, error };
}

export function useOTDCreateGovernanceVote() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const createGovernanceVote = (title: string, description: string, expiryDays: bigint) =>
    writeContract({ ...cfg, functionName: 'createGovernanceVote', args: [title, description, expiryDays] });

  return { createGovernanceVote, hash, isPending, isConfirming, isSuccess, error };
}

export function useOTDCastVote() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const castVote = (voteId: bigint, support: boolean) =>
    writeContract({ ...cfg, functionName: 'castVote', args: [voteId, support] });

  return { castVote, hash, isPending, isConfirming, isSuccess, error };
}

export function useOTDExecuteVote() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const executeVote = (voteId: bigint) =>
    writeContract({ ...cfg, functionName: 'executeVote', args: [voteId] });

  return { executeVote, hash, isPending, isConfirming, isSuccess, error };
}
