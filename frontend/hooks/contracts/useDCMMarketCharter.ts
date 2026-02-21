import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { DCMMarketCharterABI } from '@/lib/abis';

const config = {
  address: CONTRACTS.DCMMarketCharter,
  abi: DCMMarketCharterABI,
} as const;

export function useCurrentScore() {
  return useReadContract({ ...config, functionName: 'getCurrentScore' });
}

export function useGetPillar(idx: number) {
  return useReadContract({ ...config, functionName: 'getPillar', args: [idx] });
}

export function useReportCount() {
  return useReadContract({ ...config, functionName: 'reportCount' });
}

export function useGetReport(id: bigint) {
  return useReadContract({ ...config, functionName: 'getReport', args: [id] });
}

export function useRetailFee() {
  return useReadContract({ ...config, functionName: 'retailFeePerMonth' });
}

export function useInstitutionalFee() {
  return useReadContract({ ...config, functionName: 'institutionalFeePerMonth' });
}

export function useTransactionFeeBps() {
  return useReadContract({ ...config, functionName: 'transactionFeeBps' });
}

export function useIsActiveSubscriber(address: `0x${string}` | undefined) {
  return useReadContract({
    ...config,
    functionName: 'isActiveSubscriber',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });
}

export function usePublishReport() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const publishReport = () => writeContract({ ...config, functionName: 'publishReport', args: [] });

  return { publishReport, hash, isPending, isConfirming, isSuccess, error };
}

export function useUpdateMetric() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const updateMetric = (pillarIdx: number, metricIdx: number, score: number) =>
    writeContract({
      ...config,
      functionName: 'updateMetric',
      args: [pillarIdx, metricIdx, score],
    });

  return { updateMetric, hash, isPending, isConfirming, isSuccess, error };
}
