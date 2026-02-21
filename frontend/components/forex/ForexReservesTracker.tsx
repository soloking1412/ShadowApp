'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { CONTRACTS, CURRENCIES, CURRENCY_NAMES } from '@/lib/contracts';
import { formatUnits } from 'viem';
import {
  useTotalGlobalReservesUSD,
  useForexTradeCounter,
  useGetAllCurrencies,
  useGetActiveOpportunities,
  useUpdateReserve,
} from '@/hooks/contracts/useForexReservesTracker';

// Invert CURRENCIES map: name → id
const CURRENCY_IDS: Record<string, bigint> = Object.fromEntries(
  Object.entries(CURRENCIES).map(([name, id]) => [name, BigInt(id)])
);

const RESERVE_TYPES = ['Central Bank', 'Commercial', 'Investment', 'Emergency'] as const;

function formatUSD(val: bigint) {
  const n = Number(formatUnits(val, 18));
  if (n >= 1e12) return `$${(n / 1e12).toFixed(2)}T`;
  if (n >= 1e9)  return `$${(n / 1e9).toFixed(2)}B`;
  if (n >= 1e6)  return `$${(n / 1e6).toFixed(2)}M`;
  return `$${n.toFixed(2)}`;
}

export default function ForexReservesTracker() {
  const { address } = useAccount();

  // Live contract reads
  const { data: totalReserves }    = useTotalGlobalReservesUSD();
  const { data: tradeCounter }     = useForexTradeCounter();
  const { data: allCurrencies }    = useGetAllCurrencies();
  const { data: opportunities }    = useGetActiveOpportunities();

  // Write hook
  const { updateReserve, isPending, isConfirming, isSuccess, error } = useUpdateReserve();

  const notDeployed = !CONTRACTS.ForexReservesTracker;

  // Form state
  const [selectedCurrency, setSelectedCurrency] = useState('USD');
  const [reserveAmount, setReserveAmount] = useState('');
  const [reserveType, setReserveType]   = useState(0);
  const [note, setNote]                 = useState('');

  const handleUpdateReserve = () => {
    if (!reserveAmount || !selectedCurrency) return;
    const currencyId = CURRENCY_IDS[selectedCurrency];
    if (!currencyId) return;
    updateReserve(currencyId, reserveAmount, reserveType, note || `${selectedCurrency} reserve update`);
  };

  const currencies = (allCurrencies as unknown[]) ?? [];
  const opps = (opportunities as unknown[]) ?? [];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="glass rounded-xl p-6">
        <h2 className="text-2xl font-bold text-white mb-2">Forex Reserves Tracker</h2>
        <p className="text-gray-400 mb-6">Global currency reserves and market corridor analysis</p>

        {notDeployed && (
          <div className="mb-4 p-3 bg-yellow-500/10 border border-yellow-500/30 rounded-lg text-yellow-400 text-sm">
            ForexReservesTracker contract not deployed — deploy via docker compose.
          </div>
        )}

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="p-4 bg-gradient-to-br from-green-500/20 to-emerald-500/20 border border-green-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Total Reserves (USD)</p>
            <p className="text-3xl font-bold text-white">
              {totalReserves !== undefined ? formatUSD(totalReserves as bigint) : '—'}
            </p>
            <p className="text-xs text-green-400 mt-1">On-chain</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-blue-500/20 to-cyan-500/20 border border-blue-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Registered Currencies</p>
            <p className="text-3xl font-bold text-white">{currencies.length || '—'}</p>
            <p className="text-xs text-blue-400 mt-1">On-chain</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-purple-500/20 to-violet-500/20 border border-purple-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Active Opportunities</p>
            <p className="text-3xl font-bold text-white">{opps.length || '—'}</p>
            <p className="text-xs text-purple-400 mt-1">On-chain</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-amber-500/20 to-orange-500/20 border border-amber-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Total Trades</p>
            <p className="text-3xl font-bold text-white">
              {tradeCounter !== undefined ? String(tradeCounter) : '—'}
            </p>
            <p className="text-xs text-amber-400 mt-1">On-chain</p>
          </div>
        </div>
      </div>

      {/* Update Reserve Form */}
      <div className="glass rounded-xl p-6">
        <h3 className="text-xl font-bold text-white mb-4">Update Reserve</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Currency</label>
              <select
                value={selectedCurrency}
                onChange={(e) => setSelectedCurrency(e.target.value)}
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
              >
                {Object.entries(CURRENCY_NAMES).map(([id, name]) => (
                  <option key={id} value={name}>{name}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Reserve Type</label>
              <select
                value={reserveType}
                onChange={(e) => setReserveType(Number(e.target.value))}
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
              >
                {RESERVE_TYPES.map((t, i) => <option key={t} value={i}>{t}</option>)}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Amount (USD, 18 decimals)</label>
              <input
                type="number"
                value={reserveAmount}
                onChange={(e) => setReserveAmount(e.target.value)}
                placeholder="1000000.00"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Note</label>
              <input
                type="text"
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder="Reserve update reason..."
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
            </div>

            {error && <p className="text-red-400 text-sm">{(error as Error).message.slice(0, 150)}</p>}
            {isSuccess && <p className="text-green-400 text-sm">✓ Reserve updated on-chain!</p>}

            <button
              onClick={handleUpdateReserve}
              disabled={isPending || isConfirming || !address || !reserveAmount || notDeployed}
              className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isPending ? 'Confirm in wallet...' : isConfirming ? 'Updating...' : 'Update Reserve'}
            </button>
          </div>

          {/* Active Opportunities */}
          <div>
            <h4 className="text-lg font-semibold text-white mb-3">Active Opportunities</h4>
            {opps.length === 0 ? (
              <div className="p-8 text-center text-gray-500 bg-white/5 rounded-lg">
                <p className="text-3xl mb-2">📊</p>
                <p className="font-medium">No active opportunities</p>
                <p className="text-xs mt-1">Opportunities are registered on-chain by oracle operators</p>
              </div>
            ) : (
              <div className="space-y-3">
                {(opps as { fromCurrency: string; toCurrency: string; potentialReturnBps: bigint; volumeOICD: bigint; riskScore: bigint }[]).map((opp, i) => (
                  <div key={i} className="p-4 bg-white/5 border border-white/10 rounded-lg">
                    <div className="flex items-center justify-between mb-2">
                      <p className="font-bold text-white">{opp.fromCurrency}/{opp.toCurrency}</p>
                      <p className="text-green-400 font-bold">+{(Number(opp.potentialReturnBps) / 100).toFixed(2)}%</p>
                    </div>
                    <div className="flex justify-between text-xs text-gray-400">
                      <span>Vol: {formatUSD(opp.volumeOICD)}</span>
                      <span>Risk: {Number(opp.riskScore)}/100</span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Currency Reserve Status — live from contract */}
      <div className="glass rounded-xl p-6">
        <h3 className="text-xl font-bold text-white mb-4">Registered Currency Reserves</h3>
        {currencies.length === 0 ? (
          <div className="p-8 text-center text-gray-500">
            <p className="text-4xl mb-2">💱</p>
            <p className="font-medium">No currencies registered on-chain yet</p>
            <p className="text-xs mt-1">Use the Update Reserve form above to register a currency and set its reserve</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
            {(currencies as { currencyCode: string; totalReservesUSD: bigint; utilizationRate: bigint; liquidityScore: bigint; activeCorriors: bigint }[]).map((cur) => (
              <div key={cur.currencyCode} className="p-4 bg-white/5 border border-white/10 rounded-lg">
                <div className="flex items-center justify-between mb-3">
                  <span className="font-bold text-white text-lg">{cur.currencyCode}</span>
                  <span className={`px-2 py-1 text-xs rounded ${
                    Number(cur.liquidityScore) >= 90 ? 'bg-green-500/20 text-green-400'
                    : Number(cur.liquidityScore) >= 70 ? 'bg-blue-500/20 text-blue-400'
                    : 'bg-amber-500/20 text-amber-400'
                  }`}>
                    L: {Number(cur.liquidityScore)}
                  </span>
                </div>
                <div className="space-y-1 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-400">Reserves</span>
                    <span className="text-white font-mono">{formatUSD(cur.totalReservesUSD)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Utilization</span>
                    <span className="text-green-400 font-semibold">{(Number(cur.utilizationRate) / 100).toFixed(2)}%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Corridors</span>
                    <span className="text-purple-400 font-semibold">{String(cur.activeCorriors)}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
