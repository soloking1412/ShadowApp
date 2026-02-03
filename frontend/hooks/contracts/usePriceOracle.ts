import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { PriceOracleAggregatorABI } from '@/lib/abis';

export function useGetLatestPrice(assetAddress: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.PriceOracleAggregator,
    abi: PriceOracleAggregatorABI,
    functionName: 'getLatestPrice',
    args: assetAddress ? [assetAddress] : undefined,
    query: {
      enabled: !!assetAddress,
      refetchInterval: 30000,
    },
  });
}

export function useGetAggregatedPrice(assetAddress: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.PriceOracleAggregator,
    abi: PriceOracleAggregatorABI,
    functionName: 'getAggregatedPrice',
    args: assetAddress ? [assetAddress] : undefined,
    query: {
      enabled: !!assetAddress,
      refetchInterval: 30000,
    },
  });
}

export function useIsPriceStale(assetAddress: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.PriceOracleAggregator,
    abi: PriceOracleAggregatorABI,
    functionName: 'isPriceStale',
    args: assetAddress ? [assetAddress] : undefined,
    query: {
      enabled: !!assetAddress,
      refetchInterval: 60000,
    },
  });
}

export function useCheckPriceDeviation(
  assetAddress: `0x${string}` | undefined,
  targetPrice: bigint | undefined
) {
  return useReadContract({
    address: CONTRACTS.PriceOracleAggregator,
    abi: PriceOracleAggregatorABI,
    functionName: 'checkPriceDeviation',
    args: assetAddress && targetPrice !== undefined ? [assetAddress, targetPrice] : undefined,
    query: {
      enabled: !!assetAddress && targetPrice !== undefined,
    },
  });
}

export function useGetRegisteredAssets() {
  return useReadContract({
    address: CONTRACTS.PriceOracleAggregator,
    abi: PriceOracleAggregatorABI,
    functionName: 'getRegisteredAssets',
    query: {
      refetchInterval: 60000,
    },
  });
}

export function useRegisterPriceFeed() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const registerFeed = (
    asset: `0x${string}`,
    chainlinkFeed: `0x${string}`,
    heartbeat: bigint
  ) => {
    writeContract({
      address: CONTRACTS.PriceOracleAggregator,
      abi: PriceOracleAggregatorABI,
      functionName: 'registerPriceFeed',
      args: [asset, chainlinkFeed, heartbeat],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  return {
    registerFeed,
    hash,
    error,
    isPending,
    isConfirming,
    isSuccess,
  };
}

export function useAddBackupFeed() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const addBackupFeed = (asset: `0x${string}`, backupFeed: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.PriceOracleAggregator,
      abi: PriceOracleAggregatorABI,
      functionName: 'addBackupFeed',
      args: [asset, backupFeed],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  return {
    addBackupFeed,
    hash,
    error,
    isPending,
    isConfirming,
    isSuccess,
  };
}
