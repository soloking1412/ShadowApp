'use client';

import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { parseEther, formatEther, keccak256, encodePacked } from 'viem';
import { CONTRACTS } from '@/lib/contracts';
import FractionalReserveBankingABI from '@/lib/abis/FractionalReserveBanking.json';
import { useCallback, useMemo } from 'react';

// Supported country codes matching contract
export const SUPPORTED_COUNTRY_CODES = [
  'US', 'GB', 'DE', 'FR', 'JP', 'CN', 'AU', 'CA', 'CH', 'SG',
  'AE', 'SA', 'RU', 'IN', 'BR', 'MX', 'ZA', 'NG', 'EG', 'KR', 'OZ'
] as const;

export type CountryCode = typeof SUPPORTED_COUNTRY_CODES[number];

// IBAN Account interface matching contract struct
export interface IBANAccount {
  countryCode: string;
  bankCode: string;
  owner: `0x${string}`;
  balance: bigint;
  creditLine: bigint;
  creditUsed: bigint;
  lastActivity: bigint;
  active: boolean;
}

// Transfer fee constants
export const TRANSFER_FEE_BPS = 9n;
export const FEE_DENOMINATOR = 100000n;

/**
 * Validate IBAN format (simplified)
 * Format: XX82 YYYY ZZZZ... (country + check digits + bank + account)
 */
export function validateIBANFormat(iban: string): boolean {
  const clean = iban.replace(/\s/g, '').toUpperCase();
  // Basic format: 2 letter country + 2 digits + 4-30 alphanumeric
  const ibanRegex = /^[A-Z]{2}[0-9]{2}[A-Z0-9]{4,30}$/;
  return ibanRegex.test(clean);
}

/**
 * Parse IBAN string to extract country and bank codes
 */
export function parseIBAN(iban: string): { countryCode: string; bankCode: string } | null {
  const clean = iban.replace(/\s/g, '').toUpperCase();
  if (!validateIBANFormat(clean)) return null;

  return {
    countryCode: clean.slice(0, 2),
    bankCode: clean.slice(4, 8).padEnd(4, '0'),
  };
}

/**
 * Convert country code string to bytes2
 */
export function countryCodeToBytes(code: string): `0x${string}` {
  const bytes = new TextEncoder().encode(code.slice(0, 2).toUpperCase());
  return `0x${Buffer.from(bytes).toString('hex').padEnd(4, '0')}` as `0x${string}`;
}

/**
 * Convert bank code string to bytes4
 */
export function bankCodeToBytes(code: string): `0x${string}` {
  const bytes = new TextEncoder().encode(code.slice(0, 4).toUpperCase().padEnd(4, '0'));
  return `0x${Buffer.from(bytes).toString('hex')}` as `0x${string}`;
}

/**
 * Format IBAN hash for display
 * Format: XX82 YYYY ZZZZ (country + check + bank + hash prefix)
 */
export function formatIBANDisplay(ibanHash: `0x${string}`, countryCode: string, bankCode: string): string {
  const hashPart = ibanHash.slice(2, 6).toUpperCase();
  return `${countryCode}82 ${bankCode} ${hashPart}`;
}

/**
 * Calculate transfer fee (0.009%)
 */
export function calculateTransferFee(amount: bigint): bigint {
  return (amount * TRANSFER_FEE_BPS) / FEE_DENOMINATOR;
}

/**
 * Calculate net amount after fee
 */
export function calculateNetAmount(amount: bigint): bigint {
  const fee = calculateTransferFee(amount);
  return amount - fee;
}

/**
 * Hook to register a new IBAN
 */
export function useRegisterIBAN() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const registerIBAN = useCallback((countryCode: CountryCode, bankCode: string) => {
    const countryBytes = countryCodeToBytes(countryCode);
    const bankBytes = bankCodeToBytes(bankCode);

    writeContract({
      address: CONTRACTS.FractionalReserveBanking,
      abi: FractionalReserveBankingABI,
      functionName: 'registerIBAN',
      args: [countryBytes, bankBytes],
    });
  }, [writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return { registerIBAN, hash, error, isPending, isConfirming, isSuccess };
}

/**
 * Hook to deposit funds to IBAN account
 */
export function useDepositToIBAN() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const deposit = useCallback((amount: string) => {
    writeContract({
      address: CONTRACTS.FractionalReserveBanking,
      abi: FractionalReserveBankingABI,
      functionName: 'depositToIBAN',
      value: parseEther(amount),
    });
  }, [writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return { deposit, hash, error, isPending, isConfirming, isSuccess };
}

/**
 * Hook to withdraw funds from IBAN account
 */
export function useWithdrawFromIBAN() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const withdraw = useCallback((amount: string) => {
    writeContract({
      address: CONTRACTS.FractionalReserveBanking,
      abi: FractionalReserveBankingABI,
      functionName: 'withdrawFromIBAN',
      args: [parseEther(amount)],
    });
  }, [writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return { withdraw, hash, error, isPending, isConfirming, isSuccess };
}

/**
 * Hook for inter-bank transfers with fee calculation
 */
export function useInterBankTransfer() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const transfer = useCallback((toIBANHash: `0x${string}`, amount: string) => {
    writeContract({
      address: CONTRACTS.FractionalReserveBanking,
      abi: FractionalReserveBankingABI,
      functionName: 'interBankTransfer',
      args: [toIBANHash, parseEther(amount)],
    });
  }, [writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // Fee calculation helper
  const calculateFee = useCallback((amount: string): string => {
    try {
      const amountWei = parseEther(amount);
      const fee = calculateTransferFee(amountWei);
      return formatEther(fee);
    } catch {
      return '0';
    }
  }, []);

  // Net amount helper
  const calculateNet = useCallback((amount: string): string => {
    try {
      const amountWei = parseEther(amount);
      const net = calculateNetAmount(amountWei);
      return formatEther(net);
    } catch {
      return '0';
    }
  }, []);

  return {
    transfer,
    calculateFee,
    calculateNet,
    hash,
    error,
    isPending,
    isConfirming,
    isSuccess
  };
}

/**
 * Hook to use credit from IBAN account
 */
export function useUseCredit() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const useCredit = useCallback((amount: string) => {
    writeContract({
      address: CONTRACTS.FractionalReserveBanking,
      abi: FractionalReserveBankingABI,
      functionName: 'useCredit',
      args: [parseEther(amount)],
    });
  }, [writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return { useCredit, hash, error, isPending, isConfirming, isSuccess };
}

/**
 * Hook to repay credit
 */
export function useRepayCredit() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const repayCredit = useCallback((amount: string) => {
    writeContract({
      address: CONTRACTS.FractionalReserveBanking,
      abi: FractionalReserveBankingABI,
      functionName: 'repayCredit',
      value: parseEther(amount),
    });
  }, [writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return { repayCredit, hash, error, isPending, isConfirming, isSuccess };
}

/**
 * Hook to get user's IBAN hash
 */
export function useGetMyIBAN() {
  const { address } = useAccount();

  return useReadContract({
    address: CONTRACTS.FractionalReserveBanking,
    abi: FractionalReserveBankingABI,
    functionName: 'addressToIBAN',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });
}

/**
 * Hook to get IBAN account details
 */
export function useGetIBANAccount(ibanHash: `0x${string}` | undefined) {
  const result = useReadContract({
    address: CONTRACTS.FractionalReserveBanking,
    abi: FractionalReserveBankingABI,
    functionName: 'ibanAccounts',
    args: ibanHash && ibanHash !== '0x0000000000000000000000000000000000000000000000000000000000000000'
      ? [ibanHash]
      : undefined,
    query: {
      enabled: !!ibanHash && ibanHash !== '0x0000000000000000000000000000000000000000000000000000000000000000',
      refetchInterval: 15000
    },
  });

  // Parse the result into a typed object
  const account = useMemo((): IBANAccount | null => {
    if (!result.data) return null;

    const data = result.data as [string, string, `0x${string}`, bigint, bigint, bigint, bigint, boolean];
    return {
      countryCode: new TextDecoder().decode(Buffer.from(data[0].slice(2), 'hex')),
      bankCode: new TextDecoder().decode(Buffer.from(data[1].slice(2), 'hex')),
      owner: data[2],
      balance: data[3],
      creditLine: data[4],
      creditUsed: data[5],
      lastActivity: data[6],
      active: data[7],
    };
  }, [result.data]);

  return { ...result, account };
}

/**
 * Hook to get current user's IBAN account with details
 */
export function useMyIBANAccount() {
  const { data: ibanHash, isLoading: isLoadingHash } = useGetMyIBAN();
  const { account, isLoading: isLoadingAccount, error } = useGetIBANAccount(
    ibanHash as `0x${string}` | undefined
  );

  const hasIBAN = useMemo(() => {
    return ibanHash && ibanHash !== '0x0000000000000000000000000000000000000000000000000000000000000000';
  }, [ibanHash]);

  return {
    ibanHash: ibanHash as `0x${string}` | undefined,
    account,
    hasIBAN,
    isLoading: isLoadingHash || isLoadingAccount,
    error,
  };
}

/**
 * Hook to check if country code is supported
 */
export function useIsSupportedCountry(countryCode: string) {
  const countryBytes = countryCodeToBytes(countryCode);

  return useReadContract({
    address: CONTRACTS.FractionalReserveBanking,
    abi: FractionalReserveBankingABI,
    functionName: 'supportedCountryCodes',
    args: [countryBytes],
  });
}

/**
 * Hook to get global debt index
 */
export function useGlobalDebtIndex() {
  return useReadContract({
    address: CONTRACTS.FractionalReserveBanking,
    abi: FractionalReserveBankingABI,
    functionName: 'globalDebtIndex',
    query: { refetchInterval: 60000 },
  });
}

/**
 * Hook to get country reserve info
 */
export function useCountryReserve(country: string) {
  return useReadContract({
    address: CONTRACTS.FractionalReserveBanking,
    abi: FractionalReserveBankingABI,
    functionName: 'countryReserves',
    args: [country],
    query: { refetchInterval: 30000 },
  });
}

/**
 * Hook to get all countries
 */
export function useAllCountries() {
  return useReadContract({
    address: CONTRACTS.FractionalReserveBanking,
    abi: FractionalReserveBankingABI,
    functionName: 'getAllCountries',
    query: { refetchInterval: 300000 }, // 5 minutes
  });
}

/**
 * Hook to get formatted IBAN display string
 */
export function useFormattedIBAN(ibanHash: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.FractionalReserveBanking,
    abi: FractionalReserveBankingABI,
    functionName: 'formatIBAN',
    args: ibanHash ? [ibanHash] : undefined,
    query: { enabled: !!ibanHash },
  });
}

/**
 * Calculate available credit for an account
 */
export function calculateAvailableCredit(account: IBANAccount | null): bigint {
  if (!account) return 0n;
  return account.creditLine - account.creditUsed;
}

/**
 * Calculate max possible credit based on balance and GDI
 */
export function calculateMaxCredit(balance: bigint, gdi: bigint): bigint {
  return (balance * gdi) / 100n;
}
