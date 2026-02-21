'use client';

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import InviteManagerABI from '@/lib/abis/InviteManager.json';

const contract = {
  address: CONTRACTS.InviteManager,
  abi: InviteManagerABI,
};

export function useIsWhitelisted(address?: `0x${string}`) {
  return useReadContract({
    ...contract,
    functionName: 'isWhitelisted',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!CONTRACTS.InviteManager },
  });
}

export function useInviteCode(code?: string) {
  return useReadContract({
    ...contract,
    functionName: 'getInviteCode',
    args: code ? [code] : undefined,
    query: { enabled: !!code && !!CONTRACTS.InviteManager },
  });
}

export function useIssueInvite() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // ABI: issueInvite(invitee: address, tier: uint8, allowedContracts: string[]) → bytes32 code
  const issueInvite = (
    invitee: `0x${string}`,
    tier: number,
    allowedContracts: string[] = [],
  ) => {
    writeContract({
      ...contract,
      functionName: 'issueInvite',
      args: [invitee, BigInt(tier), allowedContracts],
    });
  };

  return { issueInvite, isPending, isConfirming, isSuccess, error };
}

export function useAcceptInvite() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const acceptInvite = (code: `0x${string}` | string) => {
    writeContract({
      ...contract,
      functionName: 'acceptInvite',
      args: [code as `0x${string}`],
    });
  };

  return { acceptInvite, isPending, isConfirming, isSuccess, error };
}

export function useRevokeWhitelist() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const revokeWhitelist = (address: `0x${string}`) => {
    writeContract({
      ...contract,
      functionName: 'revokeWhitelist',
      args: [address],
    });
  };

  return { revokeWhitelist, isPending, isConfirming, isSuccess, error };
}
