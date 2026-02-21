'use client';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { JobsBoardABI } from '@/lib/abis';

const cfg = { address: CONTRACTS.JobsBoard, abi: JobsBoardABI } as const;

export function useJobsBoardJobCounter() {
  return useReadContract({ ...cfg, functionName: 'jobCounter' });
}

export function useJobsBoardTotalPosted() {
  return useReadContract({ ...cfg, functionName: 'totalJobsPosted' });
}

export function useJobsBoardTotalCompleted() {
  return useReadContract({ ...cfg, functionName: 'totalJobsCompleted' });
}

export function useJobsBoardStats() {
  return useReadContract({ ...cfg, functionName: 'boardStats' });
}

export function useJobsBoardGetJob(jobId: bigint) {
  return useReadContract({
    ...cfg,
    functionName: 'getJob',
    args: [jobId],
    query: { enabled: jobId > 0n },
  });
}

export function useJobsBoardWorkerProfile(addr: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getWorkerProfile',
    args: addr ? [addr] : undefined,
    query: { enabled: !!addr },
  });
}

export function useJobsBoardPosterJobs(addr: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getPosterJobs',
    args: addr ? [addr] : undefined,
    query: { enabled: !!addr },
  });
}

export function useJobsBoardWorkerApplications(addr: `0x${string}` | undefined) {
  return useReadContract({
    ...cfg,
    functionName: 'getWorkerApplications',
    args: addr ? [addr] : undefined,
    query: { enabled: !!addr },
  });
}

export function useJobsBoardJobApplications(jobId: bigint) {
  return useReadContract({
    ...cfg,
    functionName: 'getJobApplications',
    args: [jobId],
    query: { enabled: jobId > 0n },
  });
}

export function useJobsBoardPostJob() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const postJob = (
    level: number,
    category: number,
    title: string,
    description: string,
    payOICD: bigint,
    stockUnits: bigint,
    breakPct: bigint,
    clearance: number,
    deadlineDays: bigint,
    ipfsDetails: string,
  ) => writeContract({
    ...cfg,
    functionName: 'postJob',
    args: [level, category, title, description, payOICD, stockUnits, breakPct, clearance, deadlineDays, ipfsDetails],
  });

  return { postJob, hash, isPending, isConfirming, isSuccess, error };
}

export function useJobsBoardApplyForJob() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const applyForJob = (jobId: bigint, coverNote: string) =>
    writeContract({ ...cfg, functionName: 'applyForJob', args: [jobId, coverNote] });

  return { applyForJob, hash, isPending, isConfirming, isSuccess, error };
}

export function useJobsBoardHireWorker() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const hireWorker = (jobId: bigint, worker: `0x${string}`) =>
    writeContract({ ...cfg, functionName: 'hireWorker', args: [jobId, worker] });

  return { hireWorker, hash, isPending, isConfirming, isSuccess, error };
}

export function useJobsBoardMarkComplete() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const markJobComplete = (jobId: bigint) =>
    writeContract({ ...cfg, functionName: 'markJobComplete', args: [jobId] });

  return { markJobComplete, hash, isPending, isConfirming, isSuccess, error };
}

export function useJobsBoardCancelJob() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const cancelJob = (jobId: bigint) =>
    writeContract({ ...cfg, functionName: 'cancelJob', args: [jobId] });

  return { cancelJob, hash, isPending, isConfirming, isSuccess, error };
}

export function useJobsBoardGrantClearance() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const grantClearance = (worker: `0x${string}`, clearance: number) =>
    writeContract({ ...cfg, functionName: 'grantClearance', args: [worker, clearance] });

  return { grantClearance, hash, isPending, isConfirming, isSuccess, error };
}
