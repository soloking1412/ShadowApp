'use client';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { FreeTradeRegistryABI } from '@/lib/abis';

const cfg = { address: CONTRACTS.FreeTradeRegistry, abi: FreeTradeRegistryABI } as const;

export function useFTRAgreementCounter() {
  return useReadContract({ ...cfg, functionName: 'agreementCounter' });
}

export function useFTRBolCounter() {
  return useReadContract({ ...cfg, functionName: 'bolCounter' });
}

export function useFTRTotalTradeValue() {
  return useReadContract({ ...cfg, functionName: 'totalTradeValueOICD' });
}

export function useFTRGetAgreement(id: bigint) {
  return useReadContract({
    ...cfg,
    functionName: 'getAgreement',
    args: [id],
    query: { enabled: id > 0n },
  });
}

export function useFTRGetBOL(bolId: bigint) {
  return useReadContract({
    ...cfg,
    functionName: 'getBOL',
    args: [bolId],
    query: { enabled: bolId > 0n },
  });
}

export function useFTRExporterAgreements(addr: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getExporterAgreements',
    args: addr ? [addr] : undefined,
    query: { enabled: !!addr },
  });
}

export function useFTRImporterAgreements(addr: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getImporterAgreements',
    args: addr ? [addr] : undefined,
    query: { enabled: !!addr },
  });
}

export function useFTRCreateAgreement() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const createAgreement = (
    importer: `0x${string}`,
    broker: `0x${string}`,
    exporterCountry: string,
    importerCountry: string,
    brokerInstitution: string,
    commodityTypes: readonly number[],
    totalValueOICD: bigint,
    incotermsChoice: number,
    paymentTermsChoice: number,
    effectiveDateTs: bigint,
    expiryDateTs: bigint,
  ) => writeContract({
    ...cfg,
    functionName: 'createAgreement',
    args: [importer, broker, exporterCountry, importerCountry, brokerInstitution, commodityTypes, totalValueOICD, incotermsChoice, paymentTermsChoice, effectiveDateTs, expiryDateTs],
  });

  return { createAgreement, hash, isPending, isConfirming, isSuccess, error };
}

export function useFTRSignAgreement() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const signAgreement = (agreementId: bigint) =>
    writeContract({ ...cfg, functionName: 'signAgreement', args: [agreementId] });

  return { signAgreement, hash, isPending, isConfirming, isSuccess, error };
}

export function useFTRRaiseDispute() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const raiseDispute = (agreementId: bigint, reason: string) =>
    writeContract({ ...cfg, functionName: 'raiseDispute', args: [agreementId, reason] });

  return { raiseDispute, hash, isPending, isConfirming, isSuccess, error };
}

export function useFTRCompleteAgreement() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const completeAgreement = (agreementId: bigint) =>
    writeContract({ ...cfg, functionName: 'completeAgreement', args: [agreementId] });

  return { completeAgreement, hash, isPending, isConfirming, isSuccess, error };
}
