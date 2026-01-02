'use client';

import { useState } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS, CURRENCY_NAMES } from '@/lib/contracts';
import { formatEther, parseEther } from 'viem';

export default function TreasuryDashboard() {
  const { address } = useAccount();
  const [selectedCurrency, setSelectedCurrency] = useState(9);
  const [mintAmount, setMintAmount] = useState('');
  const [recipient, setRecipient] = useState('');

  const { writeContract, data: hash } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const handleMint = async () => {
    if (!recipient || !mintAmount) return;

    try {
      writeContract({
        address: CONTRACTS.OICDTreasury,
        abi: TREASURY_ABI,
        functionName: 'mint',
        args: [recipient as `0x${string}`, BigInt(selectedCurrency), parseEther(mintAmount), '0x'],
      });
    } catch (error) {
      console.error('Error minting:', error);
    }
  };

  const currencies = Object.entries(CURRENCY_NAMES);
  const mintLimit = '250,000,000,000';

  return (
    <div className="space-y-6">
      <div className="glass rounded-xl p-6">
        <h2 className="text-2xl font-bold text-white mb-2">OICD Treasury</h2>
        <p className="text-gray-400 mb-6">Manage global currency reserves and minting operations</p>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <div className="p-4 bg-gradient-to-br from-blue-500/20 to-purple-500/20 border border-blue-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Total Currencies</p>
            <p className="text-3xl font-bold text-white">45</p>
            <p className="text-xs text-blue-400 mt-1">Active globally</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-green-500/20 to-emerald-500/20 border border-green-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Mint Limit per Currency</p>
            <p className="text-3xl font-bold text-white">{mintLimit}</p>
            <p className="text-xs text-green-400 mt-1">OICD/OTD tokens</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-amber-500/20 to-orange-500/20 border border-amber-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">MinMint Rate</p>
            <p className="text-3xl font-bold text-white">185B</p>
            <p className="text-xs text-amber-400 mt-1">USD/OICD/OTD</p>
          </div>
        </div>
      </div>

      <div className="glass rounded-xl p-6">
        <h3 className="text-xl font-bold text-white mb-4">Mint Currency</h3>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">Select Currency</label>
            <select
              value={selectedCurrency}
              onChange={(e) => setSelectedCurrency(Number(e.target.value))}
              className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
            >
              {currencies.map(([id, name]) => (
                <option key={id} value={id}>
                  {name} - {id}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">Recipient Address</label>
            <input
              type="text"
              value={recipient}
              onChange={(e) => setRecipient(e.target.value)}
              placeholder="0x..."
              className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">
              Amount (Max: {mintLimit})
            </label>
            <input
              type="number"
              value={mintAmount}
              onChange={(e) => setMintAmount(e.target.value)}
              placeholder="0.00"
              className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
            />
          </div>

          <button
            onClick={handleMint}
            disabled={isConfirming || !address || !recipient || !mintAmount}
            className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isConfirming ? 'Minting...' : 'Mint Tokens'}
          </button>

          {isSuccess && (
            <div className="p-4 bg-green-500/10 border border-green-500/20 rounded-lg">
              <p className="text-sm text-green-400">Tokens minted successfully!</p>
            </div>
          )}
        </div>
      </div>

      <div className="glass rounded-xl p-6">
        <h3 className="text-xl font-bold text-white mb-4">Currency Overview</h3>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 max-h-96 overflow-y-auto">
          {currencies.map(([id, name]) => (
            <div
              key={id}
              className="p-4 bg-white/5 hover:bg-white/10 border border-white/10 rounded-lg transition-all cursor-pointer"
            >
              <div className="flex items-center justify-between mb-2">
                <span className="font-bold text-white">{name}</span>
                <span className="text-xs text-gray-400">ID: {id}</span>
              </div>
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-400">Status</span>
                <span className="text-green-400 flex items-center gap-1">
                  <div className="w-2 h-2 rounded-full bg-green-400" />
                  Active
                </span>
              </div>
              <div className="mt-2 pt-2 border-t border-white/10">
                <p className="text-xs text-gray-400">Limit: {mintLimit}</p>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="glass rounded-xl p-6">
        <h3 className="text-xl font-bold text-white mb-4">OTD Independence</h3>
        <div className="p-4 bg-purple-500/10 border border-purple-500/20 rounded-lg">
          <p className="text-sm text-gray-300 mb-2">
            OTD (ID: 8) operates as an independent currency separate from other OICD currencies.
          </p>
          <ul className="space-y-1 text-xs text-gray-400">
            <li className="flex items-center gap-2">
              <div className="w-1.5 h-1.5 rounded-full bg-purple-500" />
              Independent minting and supply control
            </li>
            <li className="flex items-center gap-2">
              <div className="w-1.5 h-1.5 rounded-full bg-purple-500" />
              Separate reserve backing and collateral
            </li>
            <li className="flex items-center gap-2">
              <div className="w-1.5 h-1.5 rounded-full bg-purple-500" />
              Own monetary policy and governance
            </li>
            <li className="flex items-center gap-2">
              <div className="w-1.5 h-1.5 rounded-full bg-purple-500" />
              250B mint limit same as other currencies
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}

const TREASURY_ABI = [
  {
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'id', type: 'uint256' },
      { name: 'amount', type: 'uint256' },
      { name: 'data', type: 'bytes' },
    ],
    name: 'mint',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const;
