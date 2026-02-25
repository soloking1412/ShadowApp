'use client';
import { useReadContract, useWriteContract } from 'wagmi';
import SGM_ABI from '@/lib/abis/SGMToken.json';
import { SGM_TOKEN_ADDRESS } from '@/lib/contracts';

const addr = SGM_TOKEN_ADDRESS;

// ── Read hooks ─────────────────────────────────────────────────────────────────

export function useSGMTotalSupply() {
  return useReadContract({ address: addr, abi: SGM_ABI, functionName: 'totalSupply' });
}

export function useSGMTotalMembers() {
  return useReadContract({ address: addr, abi: SGM_ABI, functionName: 'totalMembers' });
}

export function useSGMTotalStaked() {
  return useReadContract({ address: addr, abi: SGM_ABI, functionName: 'totalStaked' });
}

export function useSGMCirculating() {
  return useReadContract({ address: addr, abi: SGM_ABI, functionName: 'circulatingSupply' });
}

export function useSGMOICDPairRate() {
  return useReadContract({ address: addr, abi: SGM_ABI, functionName: 'oicdPairRate' });
}

export function useSGMYieldPool() {
  return useReadContract({ address: addr, abi: SGM_ABI, functionName: 'yieldPool' });
}

export function useSGMGlobalStats() {
  return useReadContract({ address: addr, abi: SGM_ABI, functionName: 'globalStats' });
}

export function useSGMMember(address: `0x${string}` | undefined) {
  return useReadContract({
    address: addr, abi: SGM_ABI, functionName: 'getMember',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });
}

export function useSGMPool(poolId: bigint) {
  return useReadContract({ address: addr, abi: SGM_ABI, functionName: 'getPool', args: [poolId] });
}

export function useSGMProposal(id: bigint) {
  return useReadContract({
    address: addr, abi: SGM_ABI, functionName: 'getProposal', args: [id],
    query: { enabled: id > 0n },
  });
}

export function useSGMRegistered(address: `0x${string}` | undefined) {
  return useReadContract({
    address: addr, abi: SGM_ABI, functionName: 'registered',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });
}

// ── Write hooks ────────────────────────────────────────────────────────────────

export function useSGMRegister() {
  const { writeContract, isPending, isSuccess, error } = useWriteContract();
  return {
    register: () => writeContract({ address: addr, abi: SGM_ABI, functionName: 'register' }),
    isPending, isSuccess, error,
  };
}

export function useSGMStake() {
  const { writeContract, isPending, isSuccess, error } = useWriteContract();
  return {
    stake: (amount: bigint) => writeContract({ address: addr, abi: SGM_ABI, functionName: 'stake', args: [amount] }),
    isPending, isSuccess, error,
  };
}

export function useSGMUnstake() {
  const { writeContract, isPending, isSuccess, error } = useWriteContract();
  return {
    unstake: (amount: bigint) => writeContract({ address: addr, abi: SGM_ABI, functionName: 'unstake', args: [amount] }),
    isPending, isSuccess, error,
  };
}

export function useSGMClaimYield() {
  const { writeContract, isPending, isSuccess, error } = useWriteContract();
  return {
    claimYield: () => writeContract({ address: addr, abi: SGM_ABI, functionName: 'claimYield' }),
    isPending, isSuccess, error,
  };
}

export function useSGMDepositToPool() {
  const { writeContract, isPending, isSuccess, error } = useWriteContract();
  return {
    depositToPool: (poolId: bigint, amount: bigint) =>
      writeContract({ address: addr, abi: SGM_ABI, functionName: 'depositToPool', args: [poolId, amount] }),
    isPending, isSuccess, error,
  };
}

export function useSGMCreateProposal() {
  const { writeContract, isPending, isSuccess, error } = useWriteContract();
  return {
    createProposal: (title: string, description: string, proposalType: string, durationDays: bigint) =>
      writeContract({ address: addr, abi: SGM_ABI, functionName: 'createProposal', args: [title, description, proposalType, durationDays] }),
    isPending, isSuccess, error,
  };
}

export function useSGMVote() {
  const { writeContract, isPending, isSuccess, error } = useWriteContract();
  return {
    vote: (proposalId: bigint, support: boolean) =>
      writeContract({ address: addr, abi: SGM_ABI, functionName: 'vote', args: [proposalId, support] }),
    isPending, isSuccess, error,
  };
}

export function useSGMExecuteProposal() {
  const { writeContract, isPending, isSuccess, error } = useWriteContract();
  return {
    executeProposal: (proposalId: bigint) =>
      writeContract({ address: addr, abi: SGM_ABI, functionName: 'executeProposal', args: [proposalId] }),
    isPending, isSuccess, error,
  };
}
