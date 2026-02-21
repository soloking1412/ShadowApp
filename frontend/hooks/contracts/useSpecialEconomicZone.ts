import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { SpecialEconomicZoneABI } from '@/lib/abis';

export function useSEZStats() {
  const zones = useReadContract({
    address: CONTRACTS.SpecialEconomicZone,
    abi: SpecialEconomicZoneABI,
    functionName: 'zoneCounter',
    query: { refetchInterval: 60000 },
  });
  const enterprises = useReadContract({
    address: CONTRACTS.SpecialEconomicZone,
    abi: SpecialEconomicZoneABI,
    functionName: 'enterpriseCounter',
    query: { refetchInterval: 30000 },
  });
  const investment = useReadContract({
    address: CONTRACTS.SpecialEconomicZone,
    abi: SpecialEconomicZoneABI,
    functionName: 'totalSEZInvestment',
    query: { refetchInterval: 30000 },
  });
  const employment = useReadContract({
    address: CONTRACTS.SpecialEconomicZone,
    abi: SpecialEconomicZoneABI,
    functionName: 'totalEmployment',
    query: { refetchInterval: 60000 },
  });
  return {
    zoneCount: zones.data,
    enterpriseCount: enterprises.data,
    totalInvestment: investment.data,
    totalEmployment: employment.data,
  };
}

export function useGetSEZ(zoneId: bigint | undefined) {
  return useReadContract({
    address: CONTRACTS.SpecialEconomicZone,
    abi: SpecialEconomicZoneABI,
    functionName: 'getSEZ',
    args: zoneId !== undefined ? [zoneId] : undefined,
    query: { enabled: zoneId !== undefined },
  });
}

export function useGetZoneStats(zoneId: bigint | undefined) {
  return useReadContract({
    address: CONTRACTS.SpecialEconomicZone,
    abi: SpecialEconomicZoneABI,
    functionName: 'getZoneStats',
    args: zoneId !== undefined ? [zoneId] : undefined,
    query: { enabled: zoneId !== undefined, refetchInterval: 30000 },
  });
}

export function useGetOwnerEnterprises(owner: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.SpecialEconomicZone,
    abi: SpecialEconomicZoneABI,
    functionName: 'getOwnerEnterprises',
    args: owner ? [owner] : undefined,
    query: { enabled: !!owner },
  });
}

export function useEstablishSEZ() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const establishSEZ = (
    zoneType: number,
    name: string,
    location: string,
    country: string,
    portCode: string,
    area: bigint,
    allowedActivities: string[],
  ) => {
    writeContract({
      address: CONTRACTS.SpecialEconomicZone,
      abi: SpecialEconomicZoneABI,
      functionName: 'establishSEZ',
      args: [zoneType, name, location, country, portCode, area, allowedActivities],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  return { establishSEZ, hash, error, isPending, isConfirming, isSuccess };
}

export function useRegisterEnterprise() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const registerEnterprise = (
    zoneId: bigint,
    companyName: string,
    registrationNumber: string,
    industry: string,
    investment: bigint,
    employees: bigint,
    licenseDuration: bigint,
  ) => {
    writeContract({
      address: CONTRACTS.SpecialEconomicZone,
      abi: SpecialEconomicZoneABI,
      functionName: 'registerEnterprise',
      args: [zoneId, companyName, registrationNumber, industry, investment, employees, licenseDuration],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  return { registerEnterprise, hash, error, isPending, isConfirming, isSuccess };
}

export const SEZ_TYPES = ['FreeTradeZone', 'ExportProcessing', 'TechPark', 'FinancialHub', 'IndustrialZone', 'MixedUse'] as const;
export const ZONE_STATUSES = ['Proposed', 'Approved', 'UnderConstruction', 'Operational', 'Suspended', 'Closed'] as const;
