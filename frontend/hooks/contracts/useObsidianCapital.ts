'use client';

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import { CONTRACTS } from '@/lib/contracts';
import ObsidianCapitalABI from '@/lib/abis/ObsidianCapital.json';

const contract = {
  address: CONTRACTS.ObsidianCapital,
  abi: ObsidianCapitalABI,
};

export function useAUM() {
  return useReadContract({
    ...contract,
    functionName: 'totalAUM',
    query: { enabled: !!CONTRACTS.ObsidianCapital },
  });
}

export function useNAVPerShare() {
  return useReadContract({
    ...contract,
    functionName: 'navPerShare',
    query: { enabled: !!CONTRACTS.ObsidianCapital },
  });
}

export function useManagementFee() {
  return useReadContract({
    ...contract,
    functionName: 'managementFee',
    query: { enabled: !!CONTRACTS.ObsidianCapital },
  });
}

export function usePerformanceFee() {
  return useReadContract({
    ...contract,
    functionName: 'performanceFee',
    query: { enabled: !!CONTRACTS.ObsidianCapital },
  });
}

export function useInvestorInfo(address?: `0x${string}`) {
  return useReadContract({
    ...contract,
    functionName: 'getInvestorInfo',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!CONTRACTS.ObsidianCapital },
  });
}

export function useDepositToFund() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const deposit = (amountEth: string) => {
    writeContract({
      ...contract,
      functionName: 'deposit',
      value: parseUnits(amountEth, 18),
    });
  };

  return { deposit, isPending, isConfirming, isSuccess, error };
}

export function useWithdrawFromFund() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const withdraw = (shares: bigint) => {
    writeContract({
      ...contract,
      functionName: 'withdraw',
      args: [shares],
    });
  };

  return { withdraw, isPending, isConfirming, isSuccess, error };
}

export function useAddTradePosition() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const addPosition = (
    asset: string,
    strategyType: number,
    size: bigint,
    entryPrice: bigint,
    isLong: boolean
  ) => {
    writeContract({
      ...contract,
      functionName: 'addPosition',
      args: [asset, BigInt(strategyType), size, entryPrice, isLong],
    });
  };

  return { addPosition, isPending, isConfirming, isSuccess, error };
}

export { formatUnits };
