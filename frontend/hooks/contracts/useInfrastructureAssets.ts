import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { InfrastructureAssetsABI } from '@/lib/abis';

export function useInfraStats() {
  const assets = useReadContract({
    address: CONTRACTS.InfrastructureAssets,
    abi: InfrastructureAssetsABI,
    functionName: 'assetCounter',
    query: { refetchInterval: 60000 },
  });
  const corridors = useReadContract({
    address: CONTRACTS.InfrastructureAssets,
    abi: InfrastructureAssetsABI,
    functionName: 'corridorCounter',
    query: { refetchInterval: 60000 },
  });
  const totalValue = useReadContract({
    address: CONTRACTS.InfrastructureAssets,
    abi: InfrastructureAssetsABI,
    functionName: 'totalFreightValue',
    query: { refetchInterval: 30000 },
  });
  return { assetCount: assets.data, corridorCount: corridors.data, totalFreightValue: totalValue.data };
}

export function useGetAssetByCode(code: string | undefined) {
  return useReadContract({
    address: CONTRACTS.InfrastructureAssets,
    abi: InfrastructureAssetsABI,
    functionName: 'getAssetByCode',
    args: code ? [code] : undefined,
    query: { enabled: !!code },
  });
}

export function useGetCorridor(corridorId: bigint | undefined) {
  return useReadContract({
    address: CONTRACTS.InfrastructureAssets,
    abi: InfrastructureAssetsABI,
    functionName: 'getCorridor',
    args: corridorId !== undefined ? [corridorId] : undefined,
    query: { enabled: corridorId !== undefined },
  });
}

export function useRegisterAsset() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const registerAsset = (
    assetType: number,
    name: string,
    code: string,
    country: string,
    city: string,
    coordinates: string,
    capacity: bigint,
    connectedCorridors: string[],
    sezEnabled: boolean,
  ) => {
    writeContract({
      address: CONTRACTS.InfrastructureAssets,
      abi: InfrastructureAssetsABI,
      functionName: 'registerAsset',
      args: [assetType, name, code, country, city, coordinates, capacity, connectedCorridors, sezEnabled],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  return { registerAsset, hash, error, isPending, isConfirming, isSuccess };
}

export function useEstablishCorridor() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const establishCorridor = (
    name: string,
    originCode: string,
    destinationCode: string,
    transitAssets: bigint[],
    supportedTypes: number[],
    distance: bigint,
    averageTransitTime: bigint,
  ) => {
    writeContract({
      address: CONTRACTS.InfrastructureAssets,
      abi: InfrastructureAssetsABI,
      functionName: 'establishCorridor',
      args: [name, originCode, destinationCode, transitAssets, supportedTypes, distance, averageTransitTime],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  return { establishCorridor, hash, error, isPending, isConfirming, isSuccess };
}

export const ASSET_TYPES = ['Port', 'Airport', 'RailTerminal', 'RoadHub', 'WarehouseComplex', 'PipelineStation', 'BorderCrossing', 'FreeTradeZone'] as const;
