'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { parseEther } from 'viem';

const COUNTRIES = [
  'US', 'GB', 'DE', 'FR', 'JP', 'CN', 'AU', 'CA', 'RU', 'ID', 'MM', 'TH', 'SG', 'EG',
  'LY', 'LB', 'PS', 'JO', 'BA', 'SY', 'AL', 'BR', 'GE', 'DZ', 'MA', 'KR', 'AM', 'NG',
  'IN', 'CL', 'AR', 'ZA', 'TN', 'CO', 'VE', 'BO', 'MX', 'SA', 'QA', 'KW', 'OM', 'YE',
  'IQ', 'IR', 'AE', 'CH'
];

export default function FractionalReserveDashboard() {
  const { address } = useAccount();
  const [selectedCountry, setSelectedCountry] = useState('US');
  const [depositAmount, setDepositAmount] = useState('');
  const [loanAmount, setLoanAmount] = useState('');
  const [borrower, setBorrower] = useState('');
  const [loanPurpose, setLoanPurpose] = useState('');

  const { writeContract, data: hash } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const handleDeposit = async () => {
    if (!depositAmount || !selectedCountry) return;

    try {
      writeContract({
        address: CONTRACTS.FractionalReserveBanking,
        abi: FRACTIONAL_RESERVE_ABI,
        functionName: 'depositToCountry',
        args: [selectedCountry, parseEther(depositAmount)],
      });
    } catch (error) {
      console.error('Error depositing:', error);
    }
  };

  const handleLoan = async () => {
    if (!loanAmount || !borrower || !selectedCountry) return;

    try {
      writeContract({
        address: CONTRACTS.FractionalReserveBanking,
        abi: FRACTIONAL_RESERVE_ABI,
        functionName: 'issueLoan',
        args: [selectedCountry, borrower as `0x${string}`, parseEther(loanAmount), loanPurpose],
      });
    } catch (error) {
      console.error('Error issuing loan:', error);
    }
  };

  const mockReserveData = COUNTRIES.map((country) => ({
    country,
    totalHoldings: (Math.random() * 10000000000).toFixed(2),
    reserveRatio: (Math.random() * 30 + 10).toFixed(2),
    availableForInvestment: (Math.random() * 5000000000).toFixed(2),
    activeInvestments: Math.floor(Math.random() * 100),
  }));

  const selectedCountryData = mockReserveData.find((d) => d.country === selectedCountry);

  return (
    <div className="space-y-6">
      <div className="glass rounded-xl p-6">
        <h2 className="text-2xl font-bold text-white mb-2">Fractional Reserve Banking</h2>
        <p className="text-gray-400 mb-6">Country-specific reserve holdings and lending operations</p>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="p-4 bg-gradient-to-br from-blue-500/20 to-blue-600/20 border border-blue-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Total Countries</p>
            <p className="text-3xl font-bold text-white">{COUNTRIES.length}</p>
            <p className="text-xs text-blue-400 mt-1">Global coverage</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-green-500/20 to-green-600/20 border border-green-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Total Holdings</p>
            <p className="text-3xl font-bold text-white">$2.4T</p>
            <p className="text-xs text-green-400 mt-1">Across all countries</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-amber-500/20 to-amber-600/20 border border-amber-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Avg Reserve Ratio</p>
            <p className="text-3xl font-bold text-white">22.4%</p>
            <p className="text-xs text-amber-400 mt-1">Global average</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-purple-500/20 to-purple-600/20 border border-purple-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Active Loans</p>
            <p className="text-3xl font-bold text-white">4,287</p>
            <p className="text-xs text-purple-400 mt-1">Outstanding</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="glass rounded-xl p-6">
          <h3 className="text-xl font-bold text-white mb-4">Deposit to Reserve</h3>

          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Select Country</label>
              <select
                value={selectedCountry}
                onChange={(e) => setSelectedCountry(e.target.value)}
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
              >
                {COUNTRIES.map((country) => (
                  <option key={country} value={country}>
                    {country}
                  </option>
                ))}
              </select>
            </div>

            {selectedCountryData && (
              <div className="p-4 bg-white/5 rounded-lg space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Total Holdings</span>
                  <span className="text-white font-semibold">${selectedCountryData.totalHoldings}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Reserve Ratio</span>
                  <span className="text-green-400 font-semibold">{selectedCountryData.reserveRatio}%</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Available for Investment</span>
                  <span className="text-blue-400 font-semibold">${selectedCountryData.availableForInvestment}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Active Investments</span>
                  <span className="text-purple-400 font-semibold">{selectedCountryData.activeInvestments}</span>
                </div>
              </div>
            )}

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Deposit Amount</label>
              <input
                type="number"
                value={depositAmount}
                onChange={(e) => setDepositAmount(e.target.value)}
                placeholder="0.00"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
            </div>

            <button
              onClick={handleDeposit}
              disabled={isConfirming || !address}
              className="w-full py-4 bg-green-500 hover:bg-green-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isConfirming ? 'Depositing...' : 'Deposit to Reserve'}
            </button>
          </div>
        </div>

        <div className="glass rounded-xl p-6">
          <h3 className="text-xl font-bold text-white mb-4">Issue Loan</h3>

          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Country Reserve</label>
              <select
                value={selectedCountry}
                onChange={(e) => setSelectedCountry(e.target.value)}
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
              >
                {COUNTRIES.map((country) => (
                  <option key={country} value={country}>
                    {country}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Borrower Address</label>
              <input
                type="text"
                value={borrower}
                onChange={(e) => setBorrower(e.target.value)}
                placeholder="0x..."
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Loan Amount</label>
              <input
                type="number"
                value={loanAmount}
                onChange={(e) => setLoanAmount(e.target.value)}
                placeholder="0.00"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Loan Purpose</label>
              <input
                type="text"
                value={loanPurpose}
                onChange={(e) => setLoanPurpose(e.target.value)}
                placeholder="Infrastructure development, business expansion, etc."
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
            </div>

            <button
              onClick={handleLoan}
              disabled={isConfirming || !address}
              className="w-full py-4 bg-purple-500 hover:bg-purple-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isConfirming ? 'Issuing Loan...' : 'Issue Loan'}
            </button>
          </div>
        </div>
      </div>

      {isSuccess && (
        <div className="glass rounded-xl p-4">
          <div className="flex items-center gap-3 text-green-400">
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
            <p className="text-sm font-semibold">Transaction completed successfully!</p>
          </div>
        </div>
      )}

      <div className="glass rounded-xl p-6">
        <h3 className="text-xl font-bold text-white mb-4">Country Reserve Holdings</h3>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/10">
                <th className="text-left py-3 px-4 text-gray-400 font-medium">Country</th>
                <th className="text-right py-3 px-4 text-gray-400 font-medium">Total Holdings</th>
                <th className="text-right py-3 px-4 text-gray-400 font-medium">Reserve Ratio</th>
                <th className="text-right py-3 px-4 text-gray-400 font-medium">Available</th>
                <th className="text-right py-3 px-4 text-gray-400 font-medium">Investments</th>
              </tr>
            </thead>
            <tbody className="max-h-96 overflow-y-auto">
              {mockReserveData.slice(0, 15).map((data) => (
                <tr
                  key={data.country}
                  className="border-b border-white/5 hover:bg-white/5 transition-all cursor-pointer"
                >
                  <td className="py-3 px-4">
                    <span className="font-semibold text-white">{data.country}</span>
                  </td>
                  <td className="py-3 px-4 text-right text-white font-mono">${data.totalHoldings}</td>
                  <td className="py-3 px-4 text-right">
                    <span className="text-green-400 font-semibold">{data.reserveRatio}%</span>
                  </td>
                  <td className="py-3 px-4 text-right text-blue-400 font-mono">${data.availableForInvestment}</td>
                  <td className="py-3 px-4 text-right text-purple-400 font-semibold">{data.activeInvestments}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

const FRACTIONAL_RESERVE_ABI = [
  {
    inputs: [
      { name: 'country', type: 'string' },
      { name: 'amount', type: 'uint256' },
    ],
    name: 'depositToCountry',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'country', type: 'string' },
      { name: 'borrower', type: 'address' },
      { name: 'amount', type: 'uint256' },
      { name: 'purpose', type: 'string' },
    ],
    name: 'issueLoan',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const;
