'use client';

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import SovereignInvestmentDAOABI from '@/lib/abis/SovereignInvestmentDAO.json';

const contract = {
  address: CONTRACTS.SovereignInvestmentDAO,
  abi: SovereignInvestmentDAOABI,
};

export function useProposalCounter() {
  return useReadContract({
    ...contract,
    functionName: 'proposalCounter',
    query: { enabled: !!CONTRACTS.SovereignInvestmentDAO },
  });
}

export function useGetProposal(id?: bigint) {
  return useReadContract({
    ...contract,
    functionName: 'getProposal',
    args: id !== undefined ? [id] : undefined,
    query: { enabled: id !== undefined && !!CONTRACTS.SovereignInvestmentDAO },
  });
}

export function useGetAllMinistries() {
  return useReadContract({
    ...contract,
    functionName: 'getAllMinistries',
    query: { enabled: !!CONTRACTS.SovereignInvestmentDAO },
  });
}

export function useGetMinistry(id?: bigint) {
  return useReadContract({
    ...contract,
    functionName: 'getMinistry',
    args: id !== undefined ? [id] : undefined,
    query: { enabled: id !== undefined && !!CONTRACTS.SovereignInvestmentDAO },
  });
}

export function useGetProposalState(id?: bigint) {
  return useReadContract({
    ...contract,
    functionName: 'getProposalState',
    args: id !== undefined ? [id] : undefined,
    query: { enabled: id !== undefined && !!CONTRACTS.SovereignInvestmentDAO },
  });
}

export function usePropose() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const propose = (
    targets: `0x${string}`[],
    values: bigint[],
    calldatas: `0x${string}`[],
    description: string,
    category: number,
  ) => {
    writeContract({
      ...contract,
      functionName: 'propose',
      args: [targets, values, calldatas, description, category],
    });
  };

  return { propose, isPending, isConfirming, isSuccess, error };
}

export function useCastDAOVote() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const castDAOVote = (proposalId: bigint, support: number) => {
    writeContract({
      ...contract,
      functionName: 'castVote',
      args: [proposalId, support],
    });
  };

  return { castDAOVote, isPending, isConfirming, isSuccess, error };
}

export function useCastMinistryVote() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const castMinistryVote = (proposalId: bigint, ministryId: bigint, support: number) => {
    writeContract({
      ...contract,
      functionName: 'castMinistryVote',
      args: [proposalId, ministryId, support],
    });
  };

  return { castMinistryVote, isPending, isConfirming, isSuccess, error };
}

export function useRegisterMinistry() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const registerMinistry = (
    name: string,
    ministryType: number,
    wallet: `0x${string}`,
    votingWeight: bigint,
  ) => {
    writeContract({
      ...contract,
      functionName: 'registerMinistry',
      args: [name, ministryType, wallet, votingWeight],
    });
  };

  return { registerMinistry, isPending, isConfirming, isSuccess, error };
}

export const DAO_PROPOSAL_CATEGORIES = {
  Treasury: 0,
  Infrastructure: 1,
  Policy: 2,
  Emergency: 3,
  Upgrade: 4,
  Parameter: 5,
  Ministry: 6,
} as const;

export const DAO_VOTE_SUPPORT = {
  Against: 0,
  For: 1,
  Abstain: 2,
} as const;
