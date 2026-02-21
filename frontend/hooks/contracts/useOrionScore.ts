'use client';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { OrionScoreABI } from '@/lib/abis';

const cfg = { address: CONTRACTS.OrionScore, abi: OrionScoreABI } as const;

export function useOrionCountryCount() {
  return useReadContract({ ...cfg, functionName: 'countryCount' });
}

export function useOrionWeights() {
  return useReadContract({ ...cfg, functionName: 'getWeights' });
}

export function useOrionCountryScore(code: string) {
  return useReadContract({
    ...cfg,
    functionName: 'getCountryScore',
    args: [code],
    query: { enabled: !!code },
  });
}

export function useOrionVariableScore(code: string, variable: number) {
  return useReadContract({
    ...cfg,
    functionName: 'getVariableScore',
    args: [code, variable],
    query: { enabled: !!code },
  });
}

export function useOrionScoreHistory(code: string) {
  return useReadContract({
    ...cfg,
    functionName: 'getScoreHistory',
    args: [code],
    query: { enabled: !!code },
  });
}

export function useOrionAllCountries() {
  return useReadContract({ ...cfg, functionName: 'getAllCountries' });
}

export function useOrionApprovedCountries() {
  return useReadContract({ ...cfg, functionName: 'getApprovedCountries' });
}

export function useOrionRegisterCountry() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const registerCountry = (code: string, name: string) =>
    writeContract({ ...cfg, functionName: 'registerCountry', args: [code, name] });

  return { registerCountry, hash, isPending, isConfirming, isSuccess, error };
}

export function useOrionScoreCountry() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const scoreCountry = (code: string, scores: readonly number[], rationales: readonly string[]) =>
    writeContract({ ...cfg, functionName: 'scoreCountry', args: [code, scores, rationales] });

  return { scoreCountry, hash, isPending, isConfirming, isSuccess, error };
}

export function useOrionUpdateVariable() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const updateVariable = (code: string, variable: number, score: number, rationale: string) =>
    writeContract({ ...cfg, functionName: 'updateVariable', args: [code, variable, score, rationale] });

  return { updateVariable, hash, isPending, isConfirming, isSuccess, error };
}

export function useOrionAuthorizeAnalyst() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const authorizeAnalyst = (analyst: `0x${string}`, status: boolean) =>
    writeContract({ ...cfg, functionName: 'authorizeAnalyst', args: [analyst, status] });

  return { authorizeAnalyst, hash, isPending, isConfirming, isSuccess, error };
}
