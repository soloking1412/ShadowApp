import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { ArmsTradeComplianceABI } from '@/lib/abis';

export function useArmsStats() {
  const licenses = useReadContract({
    address: CONTRACTS.ArmsTradeCompliance,
    abi: ArmsTradeComplianceABI,
    functionName: 'licenseCounter',
    query: { refetchInterval: 60000 },
  });
  const totalValue = useReadContract({
    address: CONTRACTS.ArmsTradeCompliance,
    abi: ArmsTradeComplianceABI,
    functionName: 'totalTradeValue',
    query: { refetchInterval: 30000 },
  });
  return { licenseCount: licenses.data, totalTradeValue: totalValue.data };
}

export function useGetLicense(licenseId: bigint | undefined) {
  return useReadContract({
    address: CONTRACTS.ArmsTradeCompliance,
    abi: ArmsTradeComplianceABI,
    functionName: 'getLicense',
    args: licenseId !== undefined ? [licenseId] : undefined,
    query: { enabled: licenseId !== undefined },
  });
}

export function useGetExporterLicenses(exporter: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.ArmsTradeCompliance,
    abi: ArmsTradeComplianceABI,
    functionName: 'getExporterLicenses',
    args: exporter ? [exporter] : undefined,
    query: { enabled: !!exporter },
  });
}

export function useApplyForLicense() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const applyForLicense = (
    importer: `0x${string}`,
    exporterCountry: string,
    importerCountry: string,
    commodityType: number,
    commodityDescription: string,
    hsCode: string,
    quantity: bigint,
    value: bigint,
    documentHash: string,
  ) => {
    writeContract({
      address: CONTRACTS.ArmsTradeCompliance,
      abi: ArmsTradeComplianceABI,
      functionName: 'applyForLicense',
      args: [importer, exporterCountry, importerCountry, commodityType, commodityDescription, hsCode, quantity, value, documentHash],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  return { applyForLicense, hash, error, isPending, isConfirming, isSuccess };
}

export function usePerformSanctionsCheck() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const performSanctionsCheck = (entity: `0x${string}`, entityName: string, country: string) => {
    writeContract({
      address: CONTRACTS.ArmsTradeCompliance,
      abi: ArmsTradeComplianceABI,
      functionName: 'performSanctionsCheck',
      args: [entity, entityName, country],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  return { performSanctionsCheck, hash, error, isPending, isConfirming, isSuccess };
}

export const COMMODITY_TYPES = ['SmallArms', 'Artillery', 'AircraftSystems', 'NavalSystems', 'Electronics', 'Ammunition', 'MissileSystems', 'Other'] as const;
