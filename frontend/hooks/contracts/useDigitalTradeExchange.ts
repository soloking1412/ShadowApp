import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { DigitalTradeExchangeABI } from '@/lib/abis';

const config = {
  address: CONTRACTS.DigitalTradeExchange,
  abi: DigitalTradeExchangeABI,
} as const;

export function useCompanyCount() {
  return useReadContract({ ...config, functionName: 'companyCount' });
}

export function useTradeCount() {
  return useReadContract({ ...config, functionName: 'tradeCount' });
}

export function useGetAllCenters() {
  return useReadContract({ ...config, functionName: 'getAllCenters' });
}

export function useGetCompany(id: bigint) {
  return useReadContract({ ...config, functionName: 'getCompany', args: [id] });
}

export function useGetCenterListings(centerId: bigint) {
  return useReadContract({ ...config, functionName: 'getCenterListings', args: [centerId] });
}

export function useGetRecentTrades(count: bigint) {
  return useReadContract({ ...config, functionName: 'getRecentTrades', args: [count] });
}

export function useListingFee() {
  return useReadContract({ ...config, functionName: 'listingFeeOICD' });
}

export function useTradingFees() {
  return useReadContract({ ...config, functionName: 'tradingFeesBps' });
}

export function useListCompany() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const listCompany = (
    name: string,
    ticker: string,
    sector: string,
    center: number,
    sharesTotal: bigint,
    initialPrice: bigint,
  ) => writeContract({
    ...config,
    functionName: 'listCompany',
    args: [name, ticker, sector, center, sharesTotal, initialPrice],
  });

  return { listCompany, hash, isPending, isConfirming, isSuccess, error };
}

export function useDelistCompany() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const delistCompany = (companyId: bigint) => writeContract({
    ...config,
    functionName: 'delistCompany',
    args: [companyId],
  });

  return { delistCompany, hash, isPending, isConfirming, isSuccess, error };
}

export function useDTXExecuteTrade() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const executeTrade = (
    companyId: bigint,
    seller: `0x${string}`,
    shares: bigint,
    priceOICD: bigint,
  ) => writeContract({
    ...config,
    functionName: 'executeTrade',
    args: [companyId, seller, shares, priceOICD],
  });

  return { executeTrade, hash, isPending, isConfirming, isSuccess, error };
}

export function useAuthorizeTrader() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const authorizeTrader = (companyId: bigint, trader: `0x${string}`) => writeContract({
    ...config,
    functionName: 'authorizeTrader',
    args: [companyId, trader],
  });

  return { authorizeTrader, hash, isPending, isConfirming, isSuccess, error };
}
