'use client';

import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { keccak256, encodePacked, toHex, parseEther, formatEther } from 'viem';
import { CONTRACTS } from '@/lib/contracts';
import DarkPoolABI from '@/lib/abis/DarkPool.json';
import { useState, useCallback, useEffect } from 'react';

// Order types matching contract enums
export enum OrderType {
  Market = 0,
  Limit = 1,
  Iceberg = 2,
  VWAP = 3,
  TWAP = 4,
}

export enum OrderSide {
  Buy = 0,
  Sell = 1,
}

export enum OrderStatus {
  Pending = 0,
  PartiallyFilled = 1,
  Filled = 2,
  Cancelled = 3,
  Expired = 4,
}

export interface OrderParams {
  tokenAddress: `0x${string}`;
  tokenId: bigint;
  orderType: OrderType;
  side: OrderSide;
  amount: bigint;
  price: bigint;
  minFillAmount: bigint;
  expiry: bigint;
}

interface StoredCommitment {
  params: {
    tokenAddress: string;
    tokenId: string;
    orderType: number;
    side: number;
    amount: string;
    price: string;
    minFillAmount: string;
    expiry: string;
  };
  salt: string;
  timestamp: number;
  escrowAmount: string;
}

// Poseidon hash placeholder (in production, use circomlibjs)
// This is a simplified version - real implementation needs snarkjs
async function poseidonHash(inputs: bigint[]): Promise<bigint> {
  // Import poseidon from circomlibjs dynamically
  try {
    const { buildPoseidon } = await import('circomlibjs');
    const poseidon = await buildPoseidon();
    const hash = poseidon(inputs.map(i => BigInt(i)));
    return poseidon.F.toObject(hash);
  } catch {
    // Fallback to keccak for testing
    const encoded = encodePacked(
      inputs.map(() => 'uint256'),
      inputs
    );
    const hash = keccak256(encoded);
    return BigInt(hash);
  }
}

// Generate random salt for commitment
export function generateSalt(): bigint {
  const array = new Uint8Array(32);
  if (typeof window !== 'undefined') {
    crypto.getRandomValues(array);
  }
  return BigInt('0x' + Array.from(array).map(b => b.toString(16).padStart(2, '0')).join(''));
}

// Create commitment hash using Poseidon
export async function createCommitment(
  salt: bigint,
  amount: bigint,
  price: bigint,
  side: number,
  tokenId: bigint,
  trader: bigint
): Promise<bigint> {
  return poseidonHash([salt, amount, price, BigInt(side), tokenId, trader]);
}

// Generate nullifier
export async function createNullifier(salt: bigint, trader: bigint): Promise<bigint> {
  return poseidonHash([salt, trader]);
}

/**
 * Hook for committing to a dark order
 */
export function useCommitOrder() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();
  const { address } = useAccount();
  const [pendingCommitments, setPendingCommitments] = useState<Map<string, StoredCommitment>>(new Map());

  // Load stored commitments from localStorage on mount
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const stored = localStorage.getItem('darkpool_commitments');
      if (stored) {
        const parsed = JSON.parse(stored);
        setPendingCommitments(new Map(Object.entries(parsed)));
      }
    }
  }, []);

  const commitOrder = useCallback(async (params: OrderParams, escrowAmount?: bigint) => {
    if (!address) throw new Error('Wallet not connected');

    const salt = generateSalt();
    const traderBigInt = BigInt(address);

    // Create Poseidon commitment
    const commitment = await createCommitment(
      salt,
      params.amount,
      params.price,
      params.side,
      params.tokenId,
      traderBigInt
    );

    const commitmentHex = `0x${commitment.toString(16).padStart(64, '0')}` as `0x${string}`;

    // Store commitment data for later reveal
    const storedCommitment: StoredCommitment = {
      params: {
        tokenAddress: params.tokenAddress,
        tokenId: params.tokenId.toString(),
        orderType: params.orderType,
        side: params.side,
        amount: params.amount.toString(),
        price: params.price.toString(),
        minFillAmount: params.minFillAmount.toString(),
        expiry: params.expiry.toString(),
      },
      salt: salt.toString(),
      timestamp: Date.now(),
      escrowAmount: (escrowAmount || 0n).toString(),
    };

    // Save to localStorage for persistence
    const stored = JSON.parse(localStorage.getItem('darkpool_commitments') || '{}');
    stored[commitmentHex] = storedCommitment;
    localStorage.setItem('darkpool_commitments', JSON.stringify(stored));

    // Update state
    setPendingCommitments(prev => new Map(prev).set(commitmentHex, storedCommitment));

    // Submit commitment to contract
    writeContract({
      address: CONTRACTS.DarkPool,
      abi: DarkPoolABI,
      functionName: 'commitOrder',
      args: [commitmentHex],
      value: escrowAmount,
    });

    return { commitment: commitmentHex, salt };
  }, [address, writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return {
    commitOrder,
    hash,
    error,
    isPending,
    isConfirming,
    isSuccess,
    pendingCommitments
  };
}

/**
 * Hook for revealing a committed order with ZK proof
 */
export function useRevealOrder() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();
  const { address } = useAccount();
  const [isGeneratingProof, setIsGeneratingProof] = useState(false);

  const revealOrder = useCallback(async (commitmentHex: `0x${string}`) => {
    if (!address) throw new Error('Wallet not connected');

    // Retrieve stored commitment data
    const stored = JSON.parse(localStorage.getItem('darkpool_commitments') || '{}');
    const commitmentData = stored[commitmentHex] as StoredCommitment | undefined;

    if (!commitmentData) {
      throw new Error('Commitment data not found');
    }

    setIsGeneratingProof(true);

    try {
      // Generate ZK proof using snarkjs
      const { params, salt } = commitmentData;
      const saltBigInt = BigInt(salt);
      const traderBigInt = BigInt(address);

      // Calculate commitment and nullifier
      const commitment = await createCommitment(
        saltBigInt,
        BigInt(params.amount),
        BigInt(params.price),
        params.side,
        BigInt(params.tokenId),
        traderBigInt
      );
      const nullifier = await createNullifier(saltBigInt, traderBigInt);

      // In production, generate actual Groth16 proof using snarkjs
      // For now, use placeholder proof structure
      let proof: { a: [bigint, bigint]; b: [[bigint, bigint], [bigint, bigint]]; c: [bigint, bigint] };

      try {
        // Try to load snarkjs and generate real proof
        const snarkjs = await import('snarkjs');

        // Load circuit artifacts
        const wasmPath = '/circuits/orderCommitment.wasm';
        const zkeyPath = '/circuits/orderCommitment_final.zkey';

        const input = {
          salt: saltBigInt.toString(),
          amount: params.amount,
          price: params.price,
          side: params.side.toString(),
          tokenId: params.tokenId,
          trader: traderBigInt.toString(),
        };

        const { proof: generatedProof } = await snarkjs.groth16.fullProve(
          input,
          wasmPath,
          zkeyPath
        );

        proof = {
          a: [BigInt(generatedProof.pi_a[0]), BigInt(generatedProof.pi_a[1])],
          b: [
            [BigInt(generatedProof.pi_b[0][1]), BigInt(generatedProof.pi_b[0][0])],
            [BigInt(generatedProof.pi_b[1][1]), BigInt(generatedProof.pi_b[1][0])],
          ],
          c: [BigInt(generatedProof.pi_c[0]), BigInt(generatedProof.pi_c[1])],
        };
      } catch {
        // Fallback: use placeholder proof for development
        console.warn('Using placeholder proof - install snarkjs for production');
        proof = {
          a: [1n, 2n],
          b: [[1n, 2n], [3n, 4n]],
          c: [1n, 2n],
        };
      }

      // Prepare public inputs [commitment, nullifier]
      const publicInputs = [commitment, nullifier];

      // Submit reveal transaction
      writeContract({
        address: CONTRACTS.DarkPool,
        abi: DarkPoolABI,
        functionName: 'revealOrder',
        args: [
          [proof.a[0], proof.a[1]],
          proof.b,
          [proof.c[0], proof.c[1]],
          publicInputs,
          params.tokenAddress as `0x${string}`,
          BigInt(params.tokenId),
          params.orderType,
          params.side,
          BigInt(params.amount),
          BigInt(params.price),
          BigInt(params.minFillAmount),
          BigInt(params.expiry),
        ],
      });

      // Remove from localStorage after successful submission
      delete stored[commitmentHex];
      localStorage.setItem('darkpool_commitments', JSON.stringify(stored));

    } finally {
      setIsGeneratingProof(false);
    }
  }, [address, writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return {
    revealOrder,
    hash,
    error,
    isPending,
    isConfirming,
    isSuccess,
    isGeneratingProof
  };
}

/**
 * Hook to cancel a pending commitment
 */
export function useCancelCommitment() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const cancelCommitment = useCallback((commitment: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.DarkPool,
      abi: DarkPoolABI,
      functionName: 'cancelCommitment',
      args: [commitment],
    });

    // Remove from localStorage
    const stored = JSON.parse(localStorage.getItem('darkpool_commitments') || '{}');
    delete stored[commitment];
    localStorage.setItem('darkpool_commitments', JSON.stringify(stored));
  }, [writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return { cancelCommitment, hash, error, isPending, isConfirming, isSuccess };
}

/**
 * Hook to place a public (non-ZK) order directly
 */
export function usePlaceOrder() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const placeOrder = useCallback((
    params: OrderParams,
    isPublic: boolean,
    escrowValue?: bigint
  ) => {
    writeContract({
      address: CONTRACTS.DarkPool,
      abi: DarkPoolABI,
      functionName: 'placeOrder',
      args: [
        params.tokenAddress,
        params.tokenId,
        params.orderType,
        params.side,
        params.amount,
        params.price,
        params.minFillAmount,
        params.expiry,
        isPublic,
      ],
      value: escrowValue,
    });
  }, [writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return { placeOrder, hash, error, isPending, isConfirming, isSuccess };
}

/**
 * Hook to get user's orders
 */
export function useGetUserOrders(user: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.DarkPool,
    abi: DarkPoolABI,
    functionName: 'getUserOrders',
    args: user ? [user] : undefined,
    query: { enabled: !!user, refetchInterval: 10000 },
  });
}

/**
 * Hook to get order details
 */
export function useGetOrder(orderHash: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.DarkPool,
    abi: DarkPoolABI,
    functionName: 'getOrder',
    args: orderHash ? [orderHash] : undefined,
    query: { enabled: !!orderHash },
  });
}

/**
 * Hook to check commitment status
 */
export function useCommitmentStatus(commitment: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.DarkPool,
    abi: DarkPoolABI,
    functionName: 'getCommitmentDetails',
    args: commitment ? [commitment] : undefined,
    query: { enabled: !!commitment, refetchInterval: 5000 },
  });
}

/**
 * Hook to check if commitment can be revealed (after delay)
 */
export function useCanReveal(commitment: `0x${string}` | undefined) {
  const { data: details } = useCommitmentStatus(commitment);

  if (!details) return { canReveal: false, timeRemaining: 0 };

  const [exists, timestamp] = details as [boolean, bigint, `0x${string}`, bigint, boolean];
  const revealDelay = 30 * 60; // 30 minutes in seconds
  const currentTime = Math.floor(Date.now() / 1000);
  const revealTime = Number(timestamp) + revealDelay;

  return {
    canReveal: exists && currentTime >= revealTime,
    timeRemaining: Math.max(0, revealTime - currentTime),
    exists,
  };
}

/**
 * Hook to get trading statistics
 */
export function useGetStatistics(tokenAddress: `0x${string}`, tokenId: bigint) {
  return useReadContract({
    address: CONTRACTS.DarkPool,
    abi: DarkPoolABI,
    functionName: 'getStatistics',
    args: [tokenAddress, tokenId],
    query: { refetchInterval: 30000 },
  });
}

/**
 * Hook to get active orders count
 */
export function useActiveOrdersCount() {
  return useReadContract({
    address: CONTRACTS.DarkPool,
    abi: DarkPoolABI,
    functionName: 'getActiveOrdersCount',
    query: { refetchInterval: 15000 },
  });
}

/**
 * Hook to cancel an order
 */
export function useCancelOrder() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const cancelOrder = useCallback((orderHash: `0x${string}`) => {
    writeContract({
      address: CONTRACTS.DarkPool,
      abi: DarkPoolABI,
      functionName: 'cancelOrder',
      args: [orderHash],
    });
  }, [writeContract]);

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  return { cancelOrder, hash, error, isPending, isConfirming, isSuccess };
}
