'use client';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { PublicBrokerRegistryABI } from '@/lib/abis';

const cfg = { address: CONTRACTS.PublicBrokerRegistry, abi: PublicBrokerRegistryABI } as const;

// ─── READ HOOKS ───────────────────────────────────────────────────────────────

export function useBrokerCounter() {
  return useReadContract({ ...cfg, functionName: 'brokerCounter' });
}

export function useActiveBrokers() {
  return useReadContract({ ...cfg, functionName: 'activeBrokers' });
}

export function useTotalBrokerVolume() {
  return useReadContract({ ...cfg, functionName: 'totalVolumeProcessed' });
}

export function useGetBroker(brokerId: bigint) {
  return useReadContract({
    ...cfg,
    functionName: 'getBroker',
    args: [brokerId],
    query: { enabled: brokerId > 0n },
  });
}

export function useGetBrokerByWallet(wallet: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getBrokerByWallet',
    args: wallet ? [wallet] : undefined,
    query: { enabled: !!wallet },
  });
}

export function useGetBrokerClients(brokerId: bigint) {
  return useReadContract({
    ...cfg,
    functionName: 'getBrokerClients',
    args: [brokerId],
    query: { enabled: brokerId > 0n },
  });
}

export function useGetClientBroker(client: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getClientBroker',
    args: client ? [client] : undefined,
    query: { enabled: !!client },
  });
}

// ─── WRITE HOOKS ──────────────────────────────────────────────────────────────

export function useRegisterBroker() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const registerBroker = (
    companyName: string,
    registrationNumber: string,
    jurisdiction: string,
    licenseNumber: string,
    tier: number,
    websiteUrl: string,
    contactEmail: string,
  ) => writeContract({
    ...cfg,
    functionName: 'registerBroker',
    args: [companyName, registrationNumber, jurisdiction, licenseNumber, tier, websiteUrl, contactEmail],
  });

  return { registerBroker, hash, isPending, isConfirming, isSuccess, error };
}

export function useApproveBroker() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const approveBroker = (brokerId: bigint) =>
    writeContract({ ...cfg, functionName: 'approveBroker', args: [brokerId] });

  return { approveBroker, hash, isPending, isConfirming, isSuccess, error };
}

export function useOnboardClient() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const onboardClient = (client: `0x${string}`) =>
    writeContract({ ...cfg, functionName: 'onboardClient', args: [client] });

  return { onboardClient, hash, isPending, isConfirming, isSuccess, error };
}

export function useSuspendBroker() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const suspendBroker = (brokerId: bigint, reason: string) =>
    writeContract({ ...cfg, functionName: 'suspendBroker', args: [brokerId, reason] });

  return { suspendBroker, hash, isPending, isConfirming, isSuccess, error };
}
