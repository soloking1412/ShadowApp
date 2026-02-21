import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { DigitalTradeBlocksABI } from '@/lib/abis';

export function useBlockCounter() {
  return useReadContract({
    address: CONTRACTS.DigitalTradeBlocks,
    abi: DigitalTradeBlocksABI,
    functionName: 'blockCounter',
    query: { refetchInterval: 30000 },
  });
}

export function useTotalTradeBlockValue() {
  return useReadContract({
    address: CONTRACTS.DigitalTradeBlocks,
    abi: DigitalTradeBlocksABI,
    functionName: 'totalTradeBlockValue',
    query: { refetchInterval: 15000 },
  });
}

export function useGetTradeBlock(tokenId: bigint | undefined) {
  return useReadContract({
    address: CONTRACTS.DigitalTradeBlocks,
    abi: DigitalTradeBlocksABI,
    functionName: 'getTradeBlock',
    args: tokenId !== undefined ? [tokenId] : undefined,
    query: { enabled: tokenId !== undefined },
  });
}

export function useGetOwnerBlocks(owner: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.DigitalTradeBlocks,
    abi: DigitalTradeBlocksABI,
    functionName: 'getOwnerBlocks',
    args: owner ? [owner] : undefined,
    query: { enabled: !!owner, refetchInterval: 30000 },
  });
}

export function useCreateTradeBlock() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const createTradeBlock = (
    blockType: number,
    name: string,
    description: string,
    faceValue: bigint,
    maturityDate: bigint,
    yieldRate: bigint,
    underlyingAssets: string,
    minimumInvestment: bigint,
    jurisdiction: string,
    fractional: boolean,
  ) => {
    writeContract({
      address: CONTRACTS.DigitalTradeBlocks,
      abi: DigitalTradeBlocksABI,
      functionName: 'createTradeBlock',
      args: [blockType, name, description, faceValue, maturityDate, yieldRate, underlyingAssets, minimumInvestment, jurisdiction, fractional],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  return { createTradeBlock, hash, error, isPending, isConfirming, isSuccess };
}

export function useOfferTradeBlock() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const offerTradeBlock = (tokenId: bigint, price: bigint, expiryDays: bigint) => {
    writeContract({
      address: CONTRACTS.DigitalTradeBlocks,
      abi: DigitalTradeBlocksABI,
      functionName: 'offerTradeBlock',
      args: [tokenId, price, expiryDays],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  return { offerTradeBlock, hash, error, isPending, isConfirming, isSuccess };
}

export const BLOCK_TYPES = ['Infrastructure', 'Commodities', 'Energy', 'Technology', 'Agriculture', 'Logistics'] as const;
