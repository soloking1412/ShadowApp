import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { GovernmentSecuritiesSettlementABI } from '@/lib/abis';

export function useSecurityCounter() {
  return useReadContract({
    address: CONTRACTS.GovernmentSecuritiesSettlement,
    abi: GovernmentSecuritiesSettlementABI,
    functionName: 'securityCounter',
    query: { refetchInterval: 30000 },
  });
}

export function useTradeCounter() {
  return useReadContract({
    address: CONTRACTS.GovernmentSecuritiesSettlement,
    abi: GovernmentSecuritiesSettlementABI,
    functionName: 'tradeCounter',
    query: { refetchInterval: 30000 },
  });
}

export function useTotalSecuritiesValue() {
  return useReadContract({
    address: CONTRACTS.GovernmentSecuritiesSettlement,
    abi: GovernmentSecuritiesSettlementABI,
    functionName: 'totalSecuritiesValue',
    query: { refetchInterval: 15000 },
  });
}

export function useGetSecurity(securityId: bigint | undefined) {
  return useReadContract({
    address: CONTRACTS.GovernmentSecuritiesSettlement,
    abi: GovernmentSecuritiesSettlementABI,
    functionName: 'getSecurity',
    args: securityId !== undefined ? [securityId] : undefined,
    query: { enabled: securityId !== undefined },
  });
}

export function useGetTrade(tradeId: bigint | undefined) {
  return useReadContract({
    address: CONTRACTS.GovernmentSecuritiesSettlement,
    abi: GovernmentSecuritiesSettlementABI,
    functionName: 'getTrade',
    args: tradeId !== undefined ? [tradeId] : undefined,
    query: { enabled: tradeId !== undefined },
  });
}

export function useGetHoldings(holder: `0x${string}` | undefined, securityId: bigint | undefined) {
  return useReadContract({
    address: CONTRACTS.GovernmentSecuritiesSettlement,
    abi: GovernmentSecuritiesSettlementABI,
    functionName: 'getHoldings',
    args: holder && securityId !== undefined ? [holder, securityId] : undefined,
    query: { enabled: !!holder && securityId !== undefined },
  });
}

export function useIssueSecurity() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const issueSecurity = (
    securityType: number,
    isin: string,
    cusip: string,
    faceValue: bigint,
    couponRate: bigint,
    maturityDate: bigint,
    totalIssued: bigint,
  ) => {
    writeContract({
      address: CONTRACTS.GovernmentSecuritiesSettlement,
      abi: GovernmentSecuritiesSettlementABI,
      functionName: 'issueSecurity',
      args: [securityType, isin, cusip, faceValue, couponRate, maturityDate, totalIssued],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  return { issueSecurity, hash, error, isPending, isConfirming, isSuccess };
}

export function useExecuteTrade() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const executeTrade = (securityId: bigint, seller: `0x${string}`, quantity: bigint, price: bigint) => {
    writeContract({
      address: CONTRACTS.GovernmentSecuritiesSettlement,
      abi: GovernmentSecuritiesSettlementABI,
      functionName: 'executeTrade',
      args: [securityId, seller, quantity, price],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  return { executeTrade, hash, error, isPending, isConfirming, isSuccess };
}

export function useSettleTrade() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const settleTrade = (tradeId: bigint) => {
    writeContract({
      address: CONTRACTS.GovernmentSecuritiesSettlement,
      abi: GovernmentSecuritiesSettlementABI,
      functionName: 'settleTrade',
      args: [tradeId],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  return { settleTrade, hash, error, isPending, isConfirming, isSuccess };
}

export const SECURITY_TYPES = ['MunicipalBond', 'CorporateBond', 'SovereignBond', 'TokenizedEquity', 'Repo', 'CDS'] as const;
