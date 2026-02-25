'use client';
import { useReadContract, useWriteContract } from 'wagmi';
import SGMX_ABI from '@/lib/abis/SGMXToken.json';
import { SGMX_TOKEN_ADDRESS } from '@/lib/contracts';

const addr = SGMX_TOKEN_ADDRESS;

// ── Read hooks ─────────────────────────────────────────────────────────────────

export function useSGMXTotalSupply() {
  return useReadContract({ address: addr, abi: SGMX_ABI, functionName: 'totalSupply' });
}

export function useSGMXTotalInvestors() {
  return useReadContract({ address: addr, abi: SGMX_ABI, functionName: 'totalInvestors' });
}

export function useSGMXCirculating() {
  return useReadContract({ address: addr, abi: SGMX_ABI, functionName: 'circulatingSupply' });
}

export function useSGMXOICDPairRate() {
  return useReadContract({ address: addr, abi: SGMX_ABI, functionName: 'oicdPairRate' });
}

export function useSGMXTransfersEnabled() {
  return useReadContract({ address: addr, abi: SGMX_ABI, functionName: 'transfersEnabled' });
}

export function useSGMXCapTable() {
  return useReadContract({ address: addr, abi: SGMX_ABI, functionName: 'capTable' });
}

export function useSGMXDividendCounter() {
  return useReadContract({ address: addr, abi: SGMX_ABI, functionName: 'dividendCounter' });
}

export function useSGMXInvestor(address: `0x${string}` | undefined) {
  return useReadContract({
    address: addr, abi: SGMX_ABI, functionName: 'getInvestor',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });
}

export function useSGMXWhitelisted(address: `0x${string}` | undefined) {
  return useReadContract({
    address: addr, abi: SGMX_ABI, functionName: 'whitelist',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });
}

export function useSGMXDividend(id: bigint) {
  return useReadContract({
    address: addr, abi: SGMX_ABI, functionName: 'getDividend', args: [id],
    query: { enabled: id > 0n },
  });
}

export function useSGMXRegistered(address: `0x${string}` | undefined) {
  return useReadContract({
    address: addr, abi: SGMX_ABI, functionName: 'registered',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });
}

// ── Write hooks ────────────────────────────────────────────────────────────────

export function useSGMXRegisterInvestor() {
  const { writeContract, isPending, isSuccess, error } = useWriteContract();
  return {
    registerInvestor: (jurisdiction: string, shareClass: bigint) =>
      writeContract({ address: addr, abi: SGMX_ABI, functionName: 'registerInvestor', args: [jurisdiction, shareClass] }),
    isPending, isSuccess, error,
  };
}

export function useSGMXClaimDividend() {
  const { writeContract, isPending, isSuccess, error } = useWriteContract();
  return {
    claimDividend: (dividendId: bigint) =>
      writeContract({ address: addr, abi: SGMX_ABI, functionName: 'claimDividend', args: [dividendId] }),
    isPending, isSuccess, error,
  };
}
