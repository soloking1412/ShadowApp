'use client';
import React, { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatEther, parseEther } from 'viem';
const safeEther = (v: string) => { try { return parseEther(v || '0'); } catch { return 0n; } };
const safeBig   = (v: string) => { try { return v ? BigInt(v) : 0n; } catch { return 0n; } };
import {
  useSwapCounter, useTotalVolumeUSD, useActiveSwaps, useSettledSwaps,
  useGetSwap, useGetUserSwaps, useCreateSwap, useMatchSwap,
  useDepositConfirmation, useCancelSwap,
} from '@/hooks/contracts/useSovereignDEX';

const STATUS_LABELS = ['Open', 'Matched', 'Settled', 'Cancelled', 'Expired'];
const STATUS_COLORS: Record<number, string> = {
  0: 'bg-blue-500/20 text-blue-300',
  1: 'bg-yellow-500/20 text-yellow-300',
  2: 'bg-green-500/20 text-green-300',
  3: 'bg-gray-500/20 text-gray-400',
  4: 'bg-red-500/20 text-red-300',
};

export default function SovereignDEXComponent() {
  const { address, isConnected } = useAccount();
  const [tab, setTab] = useState<'overview' | 'create' | 'myswaps' | 'lookup'>('overview');
  const [lookupId, setLookupId] = useState('');
  const [matchId, setMatchId] = useState('');
  const [depositId, setDepositId] = useState('');
  const [cancelId, setCancelId] = useState('');

  // Create swap form
  const [offerCcy, setOfferCcy] = useState('USD');
  const [requestCcy, setRequestCcy] = useState('EUR');
  const [offerAmt, setOfferAmt] = useState('');
  const [requestAmt, setRequestAmt] = useState('');
  const [expiry, setExpiry] = useState('3600');

  const { data: swapCount } = useSwapCounter();
  const { data: totalVol } = useTotalVolumeUSD();
  const { data: activeCount } = useActiveSwaps();
  const { data: settledCount } = useSettledSwaps();
  const { data: lookupSwap, refetch: refetchLookup } = useGetSwap(lookupId ? BigInt(lookupId) : 0n);
  const { data: userSwaps } = useGetUserSwaps(address);

  const { createSwap, isPending: creating, isConfirming: confirmingCreate, isSuccess: created } = useCreateSwap();
  const { matchSwap, isPending: matching } = useMatchSwap();
  const { depositConfirmation, isPending: depositing } = useDepositConfirmation();
  const { cancelSwap, isPending: cancelling } = useCancelSwap();

  const handleCreate = () => {
    if (!offerAmt || !requestAmt) return;
    createSwap(offerCcy, requestCcy, safeEther(offerAmt), safeEther(requestAmt), safeBig(expiry));
  };

  const TABS = [
    { id: 'overview', label: 'Overview' },
    { id: 'create', label: 'Create Swap' },
    { id: 'myswaps', label: 'My Swaps' },
    { id: 'lookup', label: 'Lookup' },
  ] as const;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">SovereignDEX</h2>
        <p className="text-gray-400 mt-1">Atomic cross-currency peer-to-peer swap engine with DvP settlement</p>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 border-b border-white/10 pb-2">
        {TABS.map(t => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={`px-4 py-2 rounded-t text-sm font-medium transition-colors ${
              tab === t.id ? 'bg-purple-600 text-white' : 'text-gray-400 hover:text-white'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Overview */}
      {tab === 'overview' && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              { label: 'Total Swaps', value: swapCount?.toString() ?? '—' },
              { label: 'Active Swaps', value: activeCount?.toString() ?? '—' },
              { label: 'Settled Swaps', value: settledCount?.toString() ?? '—' },
              { label: 'Total Volume (ETH)', value: totalVol ? parseFloat(formatEther(totalVol as bigint)).toFixed(4) : '—' },
            ].map(s => (
              <div key={s.label} className="bg-white/5 rounded-xl p-4 border border-white/10">
                <div className="text-xs text-gray-400">{s.label}</div>
                <div className="text-xl font-bold text-white mt-1">{s.value}</div>
              </div>
            ))}
          </div>
          <div className="bg-white/5 rounded-xl p-5 border border-white/10">
            <h3 className="font-semibold text-white mb-3">How It Works</h3>
            <ol className="space-y-2 text-sm text-gray-300 list-decimal list-inside">
              <li>Initiator creates a swap offer (offer currency ↔ request currency)</li>
              <li>Counterparty matches the swap (locks in as counterparty)</li>
              <li>Both parties confirm deposit — contract auto-settles atomically</li>
              <li>Swap marked Settled; pair statistics updated on-chain</li>
            </ol>
          </div>
          <div className="bg-white/5 rounded-xl p-5 border border-white/10">
            <h3 className="font-semibold text-white mb-2">Quick Actions</h3>
            <div className="flex gap-3 flex-wrap">
              <div className="space-y-1">
                <input
                  className="bg-white/10 text-white text-sm rounded px-3 py-1.5 border border-white/20 w-32"
                  placeholder="Swap ID"
                  value={matchId}
                  onChange={e => setMatchId(e.target.value)}
                />
                <button
                  onClick={() => matchId && matchSwap(BigInt(matchId))}
                  disabled={matching || !matchId || !isConnected}
                  className="w-full bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white text-sm px-3 py-1.5 rounded"
                >
                  {matching ? 'Matching…' : 'Match Swap'}
                </button>
              </div>
              <div className="space-y-1">
                <input
                  className="bg-white/10 text-white text-sm rounded px-3 py-1.5 border border-white/20 w-32"
                  placeholder="Swap ID"
                  value={depositId}
                  onChange={e => setDepositId(e.target.value)}
                />
                <button
                  onClick={() => depositId && depositConfirmation(BigInt(depositId))}
                  disabled={depositing || !depositId || !isConnected}
                  className="w-full bg-green-600 hover:bg-green-700 disabled:opacity-50 text-white text-sm px-3 py-1.5 rounded"
                >
                  {depositing ? 'Depositing…' : 'Confirm Deposit'}
                </button>
              </div>
              <div className="space-y-1">
                <input
                  className="bg-white/10 text-white text-sm rounded px-3 py-1.5 border border-white/20 w-32"
                  placeholder="Swap ID"
                  value={cancelId}
                  onChange={e => setCancelId(e.target.value)}
                />
                <button
                  onClick={() => cancelId && cancelSwap(BigInt(cancelId))}
                  disabled={cancelling || !cancelId || !isConnected}
                  className="w-full bg-red-600 hover:bg-red-700 disabled:opacity-50 text-white text-sm px-3 py-1.5 rounded"
                >
                  {cancelling ? 'Cancelling…' : 'Cancel Swap'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Create Swap */}
      {tab === 'create' && (
        <div className="bg-white/5 rounded-xl p-5 border border-white/10 max-w-lg space-y-4">
          <h3 className="font-semibold text-white">Create Atomic Swap</h3>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-xs text-gray-400 block mb-1">Offer Currency (ISO 4217)</label>
              <input
                className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20"
                value={offerCcy}
                onChange={e => setOfferCcy(e.target.value.toUpperCase())}
                placeholder="USD"
                maxLength={6}
              />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Request Currency</label>
              <input
                className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20"
                value={requestCcy}
                onChange={e => setRequestCcy(e.target.value.toUpperCase())}
                placeholder="EUR"
                maxLength={6}
              />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-xs text-gray-400 block mb-1">Offer Amount (ETH units)</label>
              <input
                className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20"
                type="number"
                value={offerAmt}
                onChange={e => setOfferAmt(e.target.value)}
                placeholder="1000"
              />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Request Amount (ETH units)</label>
              <input
                className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20"
                type="number"
                value={requestAmt}
                onChange={e => setRequestAmt(e.target.value)}
                placeholder="920"
              />
            </div>
          </div>
          <div>
            <label className="text-xs text-gray-400 block mb-1">Expiry (seconds, min 3600 / max 2592000)</label>
            <input
              className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20"
              type="number"
              value={expiry}
              onChange={e => setExpiry(e.target.value)}
              placeholder="3600"
            />
          </div>
          {offerAmt && requestAmt && (
            <div className="text-xs text-gray-400">
              Rate: 1 {offerCcy} = {(parseFloat(requestAmt) / parseFloat(offerAmt)).toFixed(6)} {requestCcy}
            </div>
          )}
          <button
            onClick={handleCreate}
            disabled={creating || confirmingCreate || !isConnected || !offerAmt || !requestAmt}
            className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white font-medium py-2 rounded"
          >
            {creating ? 'Signing…' : confirmingCreate ? 'Confirming…' : created ? 'Swap Created!' : 'Create Swap'}
          </button>
          {!isConnected && <p className="text-xs text-yellow-400">Connect wallet to create swaps</p>}
        </div>
      )}

      {/* My Swaps */}
      {tab === 'myswaps' && (
        <div className="space-y-3">
          <h3 className="font-semibold text-white">My Swaps</h3>
          {!isConnected && <p className="text-gray-400 text-sm">Connect wallet to view your swaps</p>}
          {isConnected && (!userSwaps || (userSwaps as bigint[]).length === 0) && (
            <p className="text-gray-400 text-sm">No swaps found for your address</p>
          )}
          {isConnected && !!userSwaps && (userSwaps as bigint[]).length > 0 && (
            <div className="text-sm text-gray-300">
              Swap IDs: {(userSwaps as bigint[]).map(id => id.toString()).join(', ')}
            </div>
          )}
        </div>
      )}

      {/* Lookup */}
      {tab === 'lookup' && (
        <div className="space-y-4">
          <div className="flex gap-3 max-w-md">
            <input
              className="flex-1 bg-white/10 text-white rounded px-3 py-2 border border-white/20"
              placeholder="Enter Swap ID"
              value={lookupId}
              onChange={e => setLookupId(e.target.value)}
              type="number"
            />
            <button
              onClick={() => refetchLookup()}
              className="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded"
            >
              Lookup
            </button>
          </div>

          {!!lookupSwap && (lookupSwap as { swapId: bigint }).swapId > 0n && ((): React.ReactElement | null => {
            const s = lookupSwap as {
              swapId: bigint; initiator: string; counterparty: string;
              offerCurrency: string; requestCurrency: string;
              offerAmount: bigint; requestAmount: bigint; exchangeRate: bigint;
              expiryTime: bigint; status: number;
            };
            return (
              <div className="bg-white/5 rounded-xl p-5 border border-white/10 space-y-3 max-w-lg">
                <div className="flex items-center justify-between">
                  <span className="font-semibold text-white">Swap #{s.swapId.toString()}</span>
                  <span className={`text-xs px-2 py-0.5 rounded-full ${STATUS_COLORS[s.status] ?? ''}`}>
                    {STATUS_LABELS[s.status] ?? 'Unknown'}
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-2 text-sm">
                  <div><span className="text-gray-400">Pair:</span> <span className="text-white">{s.offerCurrency}/{s.requestCurrency}</span></div>
                  <div><span className="text-gray-400">Rate:</span> <span className="text-white">{parseFloat(formatEther(s.exchangeRate)).toFixed(6)}</span></div>
                  <div><span className="text-gray-400">Offer:</span> <span className="text-white">{formatEther(s.offerAmount)} units</span></div>
                  <div><span className="text-gray-400">Request:</span> <span className="text-white">{formatEther(s.requestAmount)} units</span></div>
                  <div className="col-span-2"><span className="text-gray-400">Initiator:</span> <span className="text-white font-mono text-xs">{s.initiator}</span></div>
                  <div className="col-span-2"><span className="text-gray-400">Counterparty:</span> <span className="text-white font-mono text-xs">{s.counterparty === '0x0000000000000000000000000000000000000000' ? 'None yet' : s.counterparty}</span></div>
                </div>
              </div>
            );
          })()}
        </div>
      )}
    </div>
  );
}
