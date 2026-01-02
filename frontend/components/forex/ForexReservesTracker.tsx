'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS, CURRENCY_NAMES } from '@/lib/contracts';
import { parseEther } from 'viem';

export default function ForexReservesTracker() {
  const { address } = useAccount();
  const [selectedCurrency, setSelectedCurrency] = useState('USD');
  const [reserveAmount, setReserveAmount] = useState('');
  const [fromCurrency, setFromCurrency] = useState('USD');
  const [toCurrency, setToCurrency] = useState('EUR');

  const { writeContract, data: hash } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const handleUpdateReserve = async () => {
    if (!reserveAmount || !selectedCurrency) return;

    try {
      writeContract({
        address: CONTRACTS.ForexReservesTracker,
        abi: FOREX_ABI,
        functionName: 'updateReserve',
        args: [selectedCurrency, parseEther(reserveAmount), parseEther('0.05'), BigInt(85)],
      });
    } catch (error) {
      console.error('Error updating reserve:', error);
    }
  };

  const mockReserveData = Object.values(CURRENCY_NAMES).map((currency) => ({
    currency,
    reserves: (Math.random() * 500000000000).toFixed(2),
    utilizationRate: (Math.random() * 100).toFixed(2),
    liquidityScore: Math.floor(Math.random() * 40 + 60),
    corridors: Math.floor(Math.random() * 30 + 10),
  }));

  const mockCorridors = [
    { from: 'USD', to: 'EUR', buyVolume: '4.2B', sellVolume: '3.8B', spread: '0.05%', liquidity: '98.5%' },
    { from: 'USD', to: 'JPY', buyVolume: '3.1B', sellVolume: '2.9B', spread: '0.08%', liquidity: '95.2%' },
    { from: 'EUR', to: 'GBP', buyVolume: '2.8B', sellVolume: '2.7B', spread: '0.06%', liquidity: '96.8%' },
    { from: 'USD', to: 'CNY', buyVolume: '5.5B', sellVolume: '5.2B', spread: '0.12%', liquidity: '92.4%' },
    { from: 'GBP', to: 'JPY', buyVolume: '1.9B', sellVolume: '1.8B', spread: '0.09%', liquidity: '94.1%' },
    { from: 'EUR', to: 'CHF', buyVolume: '2.2B', sellVolume: '2.1B', spread: '0.07%', liquidity: '97.3%' },
    { from: 'AUD', to: 'USD', buyVolume: '1.5B', sellVolume: '1.4B', spread: '0.10%', liquidity: '93.6%' },
    { from: 'CAD', to: 'USD', buyVolume: '1.7B', sellVolume: '1.6B', spread: '0.08%', liquidity: '95.8%' },
  ];

  const mockOpportunities = [
    { pair: 'EUR/USD', type: 'Arbitrage', potential: '+2.4%', volume: '$450M', risk: 'Low' },
    { pair: 'GBP/JPY', type: 'Carry Trade', potential: '+3.8%', volume: '$280M', risk: 'Medium' },
    { pair: 'AUD/NZD', type: 'Spread Trading', potential: '+1.9%', volume: '$120M', risk: 'Low' },
    { pair: 'USD/CHF', type: 'Hedging', potential: '+1.2%', volume: '$890M', risk: 'Very Low' },
    { pair: 'EUR/GBP', type: 'Momentum', potential: '+2.7%', volume: '$340M', risk: 'Medium' },
  ];

  return (
    <div className="space-y-6">
      <div className="glass rounded-xl p-6">
        <h2 className="text-2xl font-bold text-white mb-2">Forex Reserves Tracker</h2>
        <p className="text-gray-400 mb-6">Global currency reserves and market corridor analysis</p>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="p-4 bg-gradient-to-br from-green-500/20 to-emerald-500/20 border border-green-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Total Reserves</p>
            <p className="text-3xl font-bold text-white">$12.8T</p>
            <p className="text-xs text-green-400 mt-1">Across 45 currencies</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-blue-500/20 to-cyan-500/20 border border-blue-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Active Corridors</p>
            <p className="text-3xl font-bold text-white">287</p>
            <p className="text-xs text-blue-400 mt-1">Currency pairs</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-purple-500/20 to-violet-500/20 border border-purple-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Avg Liquidity</p>
            <p className="text-3xl font-bold text-white">94.2%</p>
            <p className="text-xs text-purple-400 mt-1">Global average</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-amber-500/20 to-orange-500/20 border border-amber-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Opportunities</p>
            <p className="text-3xl font-bold text-white">142</p>
            <p className="text-xs text-amber-400 mt-1">Active signals</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="glass rounded-xl p-6">
          <h3 className="text-xl font-bold text-white mb-4">Update Reserve</h3>

          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Currency</label>
              <select
                value={selectedCurrency}
                onChange={(e) => setSelectedCurrency(e.target.value)}
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
              >
                {Object.values(CURRENCY_NAMES).map((currency) => (
                  <option key={currency} value={currency}>
                    {currency}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Reserve Amount</label>
              <input
                type="number"
                value={reserveAmount}
                onChange={(e) => setReserveAmount(e.target.value)}
                placeholder="0.00"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
            </div>

            <div className="p-4 bg-blue-500/10 border border-blue-500/20 rounded-lg">
              <p className="text-sm font-medium text-white mb-2">Reserve Information</p>
              <ul className="space-y-1 text-xs text-gray-400">
                <li>• Real-time global reserve tracking</li>
                <li>• Automated utilization rate calculation</li>
                <li>• Liquidity scoring and risk assessment</li>
                <li>• Multi-currency corridor analysis</li>
              </ul>
            </div>

            <button
              onClick={handleUpdateReserve}
              disabled={isConfirming || !address}
              className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isConfirming ? 'Updating Reserve...' : 'Update Reserve'}
            </button>
          </div>
        </div>

        <div className="glass rounded-xl p-6">
          <h3 className="text-xl font-bold text-white mb-4">Investment Opportunities</h3>

          <div className="space-y-3">
            {mockOpportunities.map((opp, index) => (
              <div
                key={index}
                className="p-4 bg-white/5 hover:bg-white/10 rounded-lg transition-all cursor-pointer border border-white/10"
              >
                <div className="flex items-center justify-between mb-2">
                  <div>
                    <p className="font-bold text-white">{opp.pair}</p>
                    <p className="text-xs text-gray-400">{opp.type}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-lg font-bold text-green-400">{opp.potential}</p>
                    <p className="text-xs text-gray-400">{opp.volume}</p>
                  </div>
                </div>
                <div className="flex items-center justify-between text-xs">
                  <span
                    className={`px-2 py-1 rounded ${
                      opp.risk === 'Very Low'
                        ? 'bg-green-500/20 text-green-400'
                        : opp.risk === 'Low'
                        ? 'bg-blue-500/20 text-blue-400'
                        : 'bg-amber-500/20 text-amber-400'
                    }`}
                  >
                    {opp.risk} Risk
                  </span>
                  <button className="text-primary-400 hover:text-primary-300 font-medium">
                    View Details →
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {isSuccess && (
        <div className="glass rounded-xl p-4">
          <div className="flex items-center gap-3 text-green-400">
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
            <p className="text-sm font-semibold">Reserve updated successfully!</p>
          </div>
        </div>
      )}

      <div className="glass rounded-xl p-6">
        <h3 className="text-xl font-bold text-white mb-4">Market Corridors</h3>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/10">
                <th className="text-left py-3 px-4 text-gray-400 font-medium">Corridor</th>
                <th className="text-right py-3 px-4 text-gray-400 font-medium">Buy Volume</th>
                <th className="text-right py-3 px-4 text-gray-400 font-medium">Sell Volume</th>
                <th className="text-right py-3 px-4 text-gray-400 font-medium">Spread</th>
                <th className="text-right py-3 px-4 text-gray-400 font-medium">Liquidity</th>
              </tr>
            </thead>
            <tbody>
              {mockCorridors.map((corridor, index) => (
                <tr
                  key={index}
                  className="border-b border-white/5 hover:bg-white/5 transition-all cursor-pointer"
                >
                  <td className="py-3 px-4">
                    <span className="font-semibold text-white">
                      {corridor.from}/{corridor.to}
                    </span>
                  </td>
                  <td className="py-3 px-4 text-right text-green-400 font-semibold">{corridor.buyVolume}</td>
                  <td className="py-3 px-4 text-right text-red-400 font-semibold">{corridor.sellVolume}</td>
                  <td className="py-3 px-4 text-right text-blue-400 font-mono">{corridor.spread}</td>
                  <td className="py-3 px-4 text-right">
                    <span className="text-purple-400 font-semibold">{corridor.liquidity}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="glass rounded-xl p-6">
        <h3 className="text-xl font-bold text-white mb-4">Currency Reserve Status</h3>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
          {mockReserveData.slice(0, 12).map((data) => (
            <div
              key={data.currency}
              className="p-4 bg-white/5 hover:bg-white/10 border border-white/10 rounded-lg transition-all cursor-pointer"
            >
              <div className="flex items-center justify-between mb-3">
                <span className="font-bold text-white text-lg">{data.currency}</span>
                <span
                  className={`px-2 py-1 text-xs rounded ${
                    Number(data.liquidityScore) >= 90
                      ? 'bg-green-500/20 text-green-400'
                      : Number(data.liquidityScore) >= 70
                      ? 'bg-blue-500/20 text-blue-400'
                      : 'bg-amber-500/20 text-amber-400'
                  }`}
                >
                  L: {data.liquidityScore}
                </span>
              </div>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-400">Reserves</span>
                  <span className="text-white font-mono">${data.reserves}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Utilization</span>
                  <span className="text-green-400 font-semibold">{data.utilizationRate}%</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Corridors</span>
                  <span className="text-purple-400 font-semibold">{data.corridors}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

const FOREX_ABI = [
  {
    inputs: [
      { name: 'currency', type: 'string' },
      { name: 'amount', type: 'uint256' },
      { name: 'utilizationRate', type: 'uint256' },
      { name: 'liquidityScore', type: 'uint256' },
    ],
    name: 'updateReserve',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const;
