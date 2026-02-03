import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { UniversalAMMABI } from '@/lib/abis';

export function useGetPool(poolId: bigint | undefined) {
  return useReadContract({
    address: CONTRACTS.UniversalAMM,
    abi: UniversalAMMABI,
    functionName: 'getPool',
    args: poolId !== undefined ? [poolId] : undefined,
    query: {
      enabled: poolId !== undefined,
      refetchInterval: 15000,
    },
  });
}

export function useGetReserves(poolId: bigint | undefined) {
  return useReadContract({
    address: CONTRACTS.UniversalAMM,
    abi: UniversalAMMABI,
    functionName: 'getReserves',
    args: poolId !== undefined ? [poolId] : undefined,
    query: {
      enabled: poolId !== undefined,
      refetchInterval: 10000,
    },
  });
}

export function useGetAmountOut(
  poolId: bigint | undefined,
  tokenIn: `0x${string}` | undefined,
  amountIn: bigint | undefined
) {
  return useReadContract({
    address: CONTRACTS.UniversalAMM,
    abi: UniversalAMMABI,
    functionName: 'getAmountOut',
    args: poolId !== undefined && tokenIn && amountIn !== undefined
      ? [poolId, tokenIn, amountIn]
      : undefined,
    query: {
      enabled: poolId !== undefined && !!tokenIn && amountIn !== undefined,
      refetchInterval: 5000,
    },
  });
}

export function useGetUserLiquidity(poolId: bigint | undefined, user: `0x${string}` | undefined) {
  return useReadContract({
    address: CONTRACTS.UniversalAMM,
    abi: UniversalAMMABI,
    functionName: 'getUserLiquidity',
    args: poolId !== undefined && user ? [poolId, user] : undefined,
    query: {
      enabled: poolId !== undefined && !!user,
      refetchInterval: 30000,
    },
  });
}

export function usePoolCounter() {
  return useReadContract({
    address: CONTRACTS.UniversalAMM,
    abi: UniversalAMMABI,
    functionName: 'poolCounter',
    query: {
      refetchInterval: 60000,
    },
  });
}

export function useCreatePool() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const createPool = (
    token0: `0x${string}`,
    tokenId0: bigint,
    token1: `0x${string}`,
    tokenId1: bigint,
    initialAmount0: bigint,
    initialAmount1: bigint,
    feeBasisPoints: bigint
  ) => {
    writeContract({
      address: CONTRACTS.UniversalAMM,
      abi: UniversalAMMABI,
      functionName: 'createPool',
      args: [token0, tokenId0, token1, tokenId1, initialAmount0, initialAmount1, feeBasisPoints],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  return {
    createPool,
    hash,
    error,
    isPending,
    isConfirming,
    isSuccess,
  };
}

export function useAddLiquidity() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const addLiquidity = (
    poolId: bigint,
    amount0: bigint,
    amount1: bigint,
    minShares: bigint
  ) => {
    writeContract({
      address: CONTRACTS.UniversalAMM,
      abi: UniversalAMMABI,
      functionName: 'addLiquidity',
      args: [poolId, amount0, amount1, minShares],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  return {
    addLiquidity,
    hash,
    error,
    isPending,
    isConfirming,
    isSuccess,
  };
}

export function useRemoveLiquidity() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const removeLiquidity = (
    poolId: bigint,
    shares: bigint,
    minAmount0: bigint,
    minAmount1: bigint
  ) => {
    writeContract({
      address: CONTRACTS.UniversalAMM,
      abi: UniversalAMMABI,
      functionName: 'removeLiquidity',
      args: [poolId, shares, minAmount0, minAmount1],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  return {
    removeLiquidity,
    hash,
    error,
    isPending,
    isConfirming,
    isSuccess,
  };
}

export function useSwap() {
  const { writeContract, data: hash, error, isPending } = useWriteContract();

  const swap = (
    poolId: bigint,
    tokenIn: `0x${string}`,
    amountIn: bigint,
    minAmountOut: bigint
  ) => {
    writeContract({
      address: CONTRACTS.UniversalAMM,
      abi: UniversalAMMABI,
      functionName: 'swap',
      args: [poolId, tokenIn, amountIn, minAmountOut],
    });
  };

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  return {
    swap,
    hash,
    error,
    isPending,
    isConfirming,
    isSuccess,
  };
}
