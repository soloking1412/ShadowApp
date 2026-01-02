'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { parseEther } from 'viem';

export default function IBANBanking() {
  const { address } = useAccount();
  const [activeTab, setActiveTab] = useState<'transfer' | 'generate'>('transfer');

  const [fromIBAN, setFromIBAN] = useState('');
  const [toIBAN, setToIBAN] = useState('');
  const [amount, setAmount] = useState('');
  const [referenceNumber, setReferenceNumber] = useState('');
  const [swiftCode, setSWIFTCode] = useState('');

  const [countryCode, setCountryCode] = useState('US');

  const { writeContract, data: hash } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const handleTransfer = async () => {
    if (!fromIBAN || !toIBAN || !amount || !swiftCode) return;

    try {
      writeContract({
        address: CONTRACTS.IBANBankingSystem,
        abi: IBAN_ABI,
        functionName: 'initiateTransfer',
        args: [fromIBAN, toIBAN, parseEther(amount), referenceNumber, swiftCode],
      });
    } catch (error) {
      console.error('Error initiating transfer:', error);
    }
  };

  const handleGenerateIBAN = async () => {
    if (!address || !countryCode) return;

    try {
      writeContract({
        address: CONTRACTS.IBANBankingSystem,
        abi: IBAN_ABI,
        functionName: 'generateIBAN',
        args: [countryCode, address],
      });
    } catch (error) {
      console.error('Error generating IBAN:', error);
    }
  };

  return (
    <div className="space-y-6">
      <div className="glass rounded-xl p-6">
        <h2 className="text-2xl font-bold text-white mb-2">IBAN Banking System</h2>
        <p className="text-gray-400 mb-6">International Bank Account Number transfers via SWIFT network</p>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="p-4 bg-gradient-to-br from-blue-500/20 to-cyan-500/20 border border-blue-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Total Transfers</p>
            <p className="text-3xl font-bold text-white">12,847</p>
            <p className="text-xs text-blue-400 mt-1">All time</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-green-500/20 to-emerald-500/20 border border-green-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Volume (24h)</p>
            <p className="text-3xl font-bold text-white">$4.2M</p>
            <p className="text-xs text-green-400 mt-1">+12.5% from yesterday</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-purple-500/20 to-violet-500/20 border border-purple-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Active Accounts</p>
            <p className="text-3xl font-bold text-white">8,429</p>
            <p className="text-xs text-purple-400 mt-1">Globally verified</p>
          </div>
        </div>
      </div>

      <div className="glass rounded-xl p-6">
        <div className="flex gap-2 mb-6">
          {(['transfer', 'generate'] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`px-6 py-3 rounded-lg font-semibold transition-all ${
                activeTab === tab
                  ? 'bg-primary-500 text-white'
                  : 'bg-white/5 text-gray-400 hover:bg-white/10'
              }`}
            >
              {tab === 'transfer' ? 'Bank Transfer' : 'Generate IBAN'}
            </button>
          ))}
        </div>

        {activeTab === 'transfer' ? (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">From IBAN</label>
              <input
                type="text"
                value={fromIBAN}
                onChange={(e) => setFromIBAN(e.target.value)}
                placeholder="GB82 WEST 1234 5698 7654 32"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">To IBAN</label>
              <input
                type="text"
                value={toIBAN}
                onChange={(e) => setToIBAN(e.target.value)}
                placeholder="DE89 3704 0044 0532 0130 00"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono"
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Amount</label>
                <input
                  type="number"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="0.00"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">SWIFT Code</label>
                <input
                  type="text"
                  value={swiftCode}
                  onChange={(e) => setSWIFTCode(e.target.value)}
                  placeholder="DEUTDEFF"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono"
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Reference Number (Optional)</label>
              <input
                type="text"
                value={referenceNumber}
                onChange={(e) => setReferenceNumber(e.target.value)}
                placeholder="Invoice #12345"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
            </div>

            <div className="p-4 bg-blue-500/10 border border-blue-500/20 rounded-lg">
              <div className="flex items-start gap-3">
                <svg className="w-5 h-5 text-blue-400 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <div className="flex-1">
                  <p className="text-sm font-medium text-white mb-1">SWIFT Transfer Information</p>
                  <ul className="space-y-1 text-xs text-gray-400">
                    <li>• Standard processing time: 1-3 business days</li>
                    <li>• Real-time validation of IBAN format</li>
                    <li>• Secure SWIFT messaging protocol</li>
                    <li>• Compliance with international banking regulations</li>
                  </ul>
                </div>
              </div>
            </div>

            <button
              onClick={handleTransfer}
              disabled={isConfirming || !address}
              className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isConfirming ? 'Processing Transfer...' : 'Initiate Transfer'}
            </button>
          </div>
        ) : (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Country Code</label>
              <select
                value={countryCode}
                onChange={(e) => setCountryCode(e.target.value)}
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
              >
                <option value="US">United States (US)</option>
                <option value="GB">United Kingdom (GB)</option>
                <option value="DE">Germany (DE)</option>
                <option value="FR">France (FR)</option>
                <option value="JP">Japan (JP)</option>
                <option value="CN">China (CN)</option>
                <option value="AU">Australia (AU)</option>
                <option value="CA">Canada (CA)</option>
                <option value="RU">Russia (RU)</option>
                <option value="ID">Indonesia (ID)</option>
                <option value="SG">Singapore (SG)</option>
                <option value="SA">Saudi Arabia (SA)</option>
                <option value="AE">UAE (AE)</option>
                <option value="BR">Brazil (BR)</option>
                <option value="IN">India (IN)</option>
                <option value="MX">Mexico (MX)</option>
              </select>
            </div>

            <div className="p-4 bg-white/5 rounded-lg">
              <p className="text-sm text-gray-400 mb-2">Your Wallet Address</p>
              <p className="text-sm text-white font-mono break-all">{address || 'Not connected'}</p>
            </div>

            <div className="p-4 bg-purple-500/10 border border-purple-500/20 rounded-lg">
              <p className="text-sm font-medium text-white mb-2">IBAN Generation</p>
              <ul className="space-y-1 text-xs text-gray-400">
                <li>• Algorithmically generated unique IBAN</li>
                <li>• Linked to your blockchain wallet address</li>
                <li>• Compatible with SWIFT network</li>
                <li>• Instantly verifiable globally</li>
              </ul>
            </div>

            <button
              onClick={handleGenerateIBAN}
              disabled={isConfirming || !address}
              className="w-full py-4 bg-purple-500 hover:bg-purple-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isConfirming ? 'Generating IBAN...' : 'Generate IBAN'}
            </button>
          </div>
        )}

        {isSuccess && (
          <div className="mt-4 p-4 bg-green-500/10 border border-green-500/20 rounded-lg">
            <p className="text-sm text-green-400">
              {activeTab === 'transfer' ? 'Transfer initiated successfully!' : 'IBAN generated successfully!'}
            </p>
          </div>
        )}
      </div>

      <div className="glass rounded-xl p-6">
        <h3 className="text-xl font-bold text-white mb-4">Recent Transfers</h3>
        <div className="space-y-3">
          {[1, 2, 3, 4, 5].map((i) => (
            <div key={i} className="p-4 bg-white/5 hover:bg-white/10 rounded-lg transition-all cursor-pointer">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-500 rounded-lg flex items-center justify-center">
                    <svg className="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
                    </svg>
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-white">Transfer #{12847 - i}</p>
                    <p className="text-xs text-gray-400 font-mono">GB82...7654 → DE89...0130</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-sm font-bold text-white">${(Math.random() * 100000).toFixed(2)}</p>
                  <p className="text-xs text-green-400">Completed</p>
                </div>
              </div>
              <div className="flex items-center justify-between text-xs text-gray-400">
                <span>SWIFT: DEUTDEFF</span>
                <span>{new Date(Date.now() - i * 86400000).toLocaleDateString()}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

const IBAN_ABI = [
  {
    inputs: [
      { name: 'fromIBAN', type: 'string' },
      { name: 'toIBAN', type: 'string' },
      { name: 'amount', type: 'uint256' },
      { name: 'referenceNumber', type: 'string' },
      { name: 'swiftCode', type: 'string' },
    ],
    name: 'initiateTransfer',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'countryCode', type: 'string' },
      { name: 'owner', type: 'address' },
    ],
    name: 'generateIBAN',
    outputs: [{ name: '', type: 'string' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const;
