import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { OZFParliamentABI } from '@/lib/abis';

export function useParliamentStats() {
  const seats = useReadContract({
    address: CONTRACTS.OZFParliament,
    abi: OZFParliamentABI,
    functionName: 'activeSeats',
    query: { refetchInterval: 60000 },
  });
  const proposals = useReadContract({
    address: CONTRACTS.OZFParliament,
    abi: OZFParliamentABI,
    functionName: 'proposalCounter',
    query: { refetchInterval: 30000 },
  });
  return { activeSeats: seats.data, proposalCount: proposals.data };
}

export function useGetSeat(seatNumber: bigint | undefined) {
  return useReadContract({
    address: CONTRACTS.OZFParliament,
    abi: OZFParliamentABI,
    functionName: 'getSeat',
    args: seatNumber !== undefined ? [seatNumber] : undefined,
    query: { enabled: seatNumber !== undefined },
  });
}

export function useChairman() {
  return useReadContract({
    address: CONTRACTS.OZFParliament,
    abi: OZFParliamentABI,
    functionName: 'chairman',
  });
}

export function useCreateParliamentProposal() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const createProposal = (
    proposalType: number,
    title: string,
    description: string,
    tradeBlockInvolved: string,
    fundingAmount: bigint,
    executionData: `0x${string}`,
  ) => {
    writeContract({
      address: CONTRACTS.OZFParliament,
      abi: OZFParliamentABI,
      functionName: 'createProposal',
      args: [proposalType, title, description, tradeBlockInvolved, fundingAmount, executionData],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  return { createProposal, hash, error, isPending, isConfirming, isSuccess };
}

export function useVoteOnParliamentProposal() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const voteOnProposal = (proposalId: bigint, support: boolean) => {
    writeContract({
      address: CONTRACTS.OZFParliament,
      abi: OZFParliamentABI,
      functionName: 'voteOnProposal',
      args: [proposalId, support],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  return { voteOnProposal, hash, error, isPending, isConfirming, isSuccess };
}

export function useAssignSeat() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const assignSeat = (
    seatNumber: bigint,
    holder: `0x${string}`,
    delegationName: string,
    tradeBlockName: string,
    jurisdiction: string,
  ) => {
    writeContract({
      address: CONTRACTS.OZFParliament,
      abi: OZFParliamentABI,
      functionName: 'assignSeat',
      args: [seatNumber, holder, delegationName, tradeBlockName, jurisdiction],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  return { assignSeat, hash, error, isPending, isConfirming, isSuccess };
}

export const PROPOSAL_TYPES = ['Legislative', 'Budget', 'Treaty', 'Emergency', 'Constitutional', 'Trade'] as const;
