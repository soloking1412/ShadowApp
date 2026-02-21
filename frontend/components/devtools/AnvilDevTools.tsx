'use client';

import { useEffect, useState } from 'react';
import { useAccount, useChainId, useWriteContract, useWaitForTransactionReceipt, useBalance } from 'wagmi';
import {
  createWalletClient,
  createPublicClient,
  http,
  parseEther,
  formatEther,
  defineChain,
} from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { CONTRACTS } from '@/lib/contracts';
import InviteManagerABI from '@/lib/abis/InviteManager.json';

// Anvil's well-known test account #0 — safe to hardcode (local dev only)
const ANVIL_PK = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' as const;
const ANVIL_ADDR_0 = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
const ANVIL_RPC = 'http://127.0.0.1:8545';

const anvilChain = defineChain({
  id: 31337,
  name: 'Anvil',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: { default: { http: [ANVIL_RPC] } },
});

function getAdminClient() {
  const account = privateKeyToAccount(ANVIL_PK);
  return createWalletClient({ account, transport: http(ANVIL_RPC), chain: anvilChain });
}

function getPublicClient() {
  return createPublicClient({ transport: http(ANVIL_RPC), chain: anvilChain });
}

export default function AnvilDevTools() {
  const chainId = useChainId();
  const { address } = useAccount();
  const { data: balance, refetch: refetchBalance } = useBalance({ address });

  const [status, setStatus] = useState('');
  const [phase, setPhase] = useState<'idle' | 'busy' | 'done' | 'error'>('idle');
  const [inviteCode, setInviteCode] = useState<`0x${string}` | null>(null);
  const [needsAccept, setNeedsAccept] = useState(false);

  // wagmi hook for the user's acceptInvite call (MetaMask prompt)
  const { writeContract, data: acceptHash, error: acceptError } = useWriteContract();
  const { isSuccess: acceptDone } = useWaitForTransactionReceipt({ hash: acceptHash });

  useEffect(() => {
    if (acceptDone) {
      setStatus('✓ Whitelisted! You now have platform access. Refresh the page.');
      setPhase('done');
      setNeedsAccept(false);
    }
  }, [acceptDone]);

  useEffect(() => {
    if (acceptError) {
      setStatus('Accept failed: ' + (acceptError as Error).message.slice(0, 120));
      setPhase('error');
    }
  }, [acceptError]);

  // Only render on local Anvil
  if (chainId !== 31337) return null;

  const handleFundWallet = async () => {
    if (!address) return;
    setPhase('busy');
    setStatus('Sending 10 ETH from Anvil key 0...');
    try {
      const admin = getAdminClient();
      const pub = getPublicClient();
      const hash = await admin.sendTransaction({ to: address, value: parseEther('10') });
      await pub.waitForTransactionReceipt({ hash });
      await refetchBalance();
      setStatus('✓ Funded! Your wallet now has 10 ETH.');
      setPhase('done');
    } catch (e) {
      setStatus('Fund error: ' + (e as Error).message.slice(0, 150));
      setPhase('error');
    }
  };

  const handleWhitelist = async () => {
    if (!address || !CONTRACTS.InviteManager) return;
    setPhase('busy');
    setStatus('Step 1/2 — Admin issuing invite code...');
    try {
      const admin = getAdminClient();
      const pub = getPublicClient();

      // Simulate first to capture return value (bytes32 code)
      const { result: code } = await pub.simulateContract({
        address: CONTRACTS.InviteManager,
        abi: InviteManagerABI,
        functionName: 'issueInvite',
        args: [address, 1, []],
        account: ANVIL_ADDR_0 as `0x${string}`,
      });

      // Broadcast from admin key
      const hash = await admin.writeContract({
        address: CONTRACTS.InviteManager,
        abi: InviteManagerABI,
        functionName: 'issueInvite',
        args: [address, 1, []],
      });
      await pub.waitForTransactionReceipt({ hash });

      const resolvedCode = code as `0x${string}`;
      setInviteCode(resolvedCode);
      setStatus('Step 2/2 — Confirm acceptInvite in MetaMask...');
      setNeedsAccept(true);

      // Trigger MetaMask for the user's acceptInvite call
      writeContract({
        address: CONTRACTS.InviteManager,
        abi: InviteManagerABI,
        functionName: 'acceptInvite',
        args: [resolvedCode],
      });
    } catch (e) {
      setStatus('Whitelist error: ' + (e as Error).message.slice(0, 150));
      setPhase('error');
    }
  };

  const isBusy = phase === 'busy';

  return (
    <div className="glass rounded-xl p-6 border border-orange-500/30 bg-orange-500/5">
      <div className="flex items-center gap-3 mb-5">
        <div className="w-10 h-10 bg-orange-500/20 rounded-lg flex items-center justify-center text-xl">⚡</div>
        <div>
          <h2 className="text-xl font-bold text-orange-400">Anvil DevTools</h2>
          <p className="text-xs text-gray-400">Local dev helpers — only visible on chain 31337</p>
        </div>
      </div>

      {/* Anvil key 0 info */}
      <div className="bg-black/30 border border-orange-500/20 rounded-lg p-4 mb-5 font-mono text-xs">
        <p className="text-orange-300 font-semibold mb-2">Anvil Account #0 (deployer)</p>
        <p className="text-gray-300 mb-1 break-all">Addr: {ANVIL_ADDR_0}</p>
        <p className="text-gray-300 break-all">PK: {ANVIL_PK}</p>
        <p className="text-gray-500 mt-2 text-xs font-sans">Import this key to MetaMask for instant full access, or use the buttons below to set up your current wallet.</p>
      </div>

      {address ? (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center gap-3 p-3 bg-white/5 rounded-lg text-sm">
            <span className="text-gray-400">Your wallet:</span>
            <span className="text-white font-mono text-xs break-all">{address}</span>
            {balance && (
              <span className="ml-auto text-green-400 font-semibold whitespace-nowrap">
                {parseFloat(formatEther(balance.value)).toFixed(4)} ETH
              </span>
            )}
          </div>

          <div className="grid grid-cols-2 gap-3">
            <button
              onClick={handleFundWallet}
              disabled={isBusy}
              className="py-3 px-4 bg-orange-500 hover:bg-orange-600 disabled:opacity-50 disabled:cursor-not-allowed text-white font-semibold rounded-lg transition-all text-sm"
            >
              {isBusy && status.includes('ETH') ? '...' : '⛽ Fund 10 ETH'}
            </button>
            <button
              onClick={handleWhitelist}
              disabled={isBusy || !CONTRACTS.InviteManager}
              className="py-3 px-4 bg-purple-500 hover:bg-purple-600 disabled:opacity-50 disabled:cursor-not-allowed text-white font-semibold rounded-lg transition-all text-sm"
              title={!CONTRACTS.InviteManager ? 'InviteManager not deployed' : ''}
            >
              {needsAccept ? 'Confirm in MetaMask...' : isBusy ? '...' : '🔐 Whitelist Me'}
            </button>
          </div>

          {status && (
            <div
              className={`p-3 rounded-lg text-sm ${
                phase === 'done'
                  ? 'bg-green-500/10 border border-green-500/20 text-green-400'
                  : phase === 'error'
                  ? 'bg-red-500/10 border border-red-500/20 text-red-400'
                  : 'bg-white/5 text-gray-300'
              }`}
            >
              {status}
            </div>
          )}

          {inviteCode && needsAccept && (
            <div className="p-3 bg-purple-500/10 border border-purple-500/20 rounded-lg">
              <p className="text-xs text-purple-300 font-semibold mb-1">Invite Code (bytes32):</p>
              <p className="font-mono text-xs text-gray-200 break-all">{inviteCode}</p>
              <p className="text-xs text-gray-500 mt-1">MetaMask should have popped up — confirm to accept and whitelist your wallet.</p>
            </div>
          )}
        </div>
      ) : (
        <p className="text-gray-400 text-sm">Connect your wallet first to use DevTools.</p>
      )}
    </div>
  );
}
