'use client';

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits } from 'viem';
import { CONTRACTS } from '@/lib/contracts';
import PrimeBrokerageABI from '@/lib/abis/PrimeBrokerage.json';

const safeUnits = (v: string, d = 18) => { try { return parseUnits(v || '0', d); } catch { return 0n; } };

const contract = {
  address: CONTRACTS.PrimeBrokerage,
  abi: PrimeBrokerageABI,
};

export function useClientAccount(address?: `0x${string}`) {
  return useReadContract({
    ...contract,
    functionName: 'getClientAccount',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!CONTRACTS.PrimeBrokerage },
  });
}

export function useClientRiskMetrics(address?: `0x${string}`) {
  return useReadContract({
    ...contract,
    functionName: 'getRiskMetrics',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!CONTRACTS.PrimeBrokerage },
  });
}

export function useRegisterClient() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const registerClient = (clientTier: number) => {
    writeContract({
      ...contract,
      functionName: 'registerClient',
      args: [BigInt(clientTier)],
    });
  };

  return { registerClient, isPending, isConfirming, isSuccess, error };
}

export function useRequestMarginLoan() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const requestLoan = (amount: string, collateral: string) => {
    writeContract({
      ...contract,
      functionName: 'requestMarginLoan',
      args: [safeUnits(amount), safeUnits(collateral)],
    });
  };

  return { requestLoan, isPending, isConfirming, isSuccess, error };
}

export function useDepositCollateral() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const depositCollateral = (amountEth: string) => {
    writeContract({
      ...contract,
      functionName: 'depositCollateral',
      value: safeUnits(amountEth),
    });
  };

  return { depositCollateral, isPending, isConfirming, isSuccess, error };
}

export function useWithdrawCollateral() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const withdrawCollateral = (amount: bigint) => {
    writeContract({
      ...contract,
      functionName: 'withdrawCollateral',
      args: [amount],
    });
  };

  return { withdrawCollateral, isPending, isConfirming, isSuccess, error };
}

export const CLIENT_TIERS = ['Institutional', 'HedgeFund', 'AssetManager', 'FamilyOffice', 'Sovereign'] as const;
