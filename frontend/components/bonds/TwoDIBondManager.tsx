'use client';

import { useState, useEffect } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS, BOND_TYPES, DERIVATIVE_TYPES } from '@/lib/contracts';
import { parseEther } from 'viem';

const safeEther = (v: string) => { try { return parseEther(v || '0'); } catch { return 0n; } };
const safeBig   = (v: string) => { try { return v ? BigInt(v) : 0n; } catch { return 0n; } };
const ZERO_BYTES32 = ('0x' + '0'.repeat(64)) as `0x${string}`;

export default function TwoDIBondManager() {
  const { address } = useAccount();
  const [activeTab, setActiveTab] = useState<'bonds' | 'derivatives'>('bonds');

  const [bondType, setBondType] = useState(0);
  const [projectName, setProjectName] = useState('');
  const [country, setCountry] = useState('');
  const [totalSupply, setTotalSupply] = useState('');
  const [faceValue, setFaceValue] = useState('');
  const [couponRate, setCouponRate] = useState('');
  const [maturityDate, setMaturityDate] = useState('');

  const [derivativeType, setDerivativeType] = useState(0);
  const [underlyingBondId, setUnderlyingBondId] = useState('');
  const [notionalValue, setNotionalValue] = useState('');
  const [strikePrice, setStrikePrice] = useState('');
  const [expirationDate, setExpirationDate] = useState('');
  const [premium, setPremium] = useState('');

  const { writeContract, data: hash, error: writeError } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // Live bond counter from chain
  const { data: bondCount } = useReadContract({
    address: CONTRACTS.TwoDIBondTracker,
    abi: [{ name: 'bondCounter', type: 'function', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] }],
    functionName: 'bondCounter',
  });

  const [txError, setTxError] = useState<string | null>(null);

  useEffect(() => {
    if (!writeError) return;
    const msg = (writeError as { shortMessage?: string })?.shortMessage ?? writeError.message ?? 'Transaction failed';
    setTxError(msg.length > 120 ? msg.slice(0, 120) + '…' : msg);
    const t = setTimeout(() => setTxError(null), 7000);
    return () => clearTimeout(t);
  }, [writeError]);

  const handleIssueBond = () => {
    if (!projectName || !country || !totalSupply || !faceValue || !couponRate || !maturityDate) return;
    writeContract({
        address: CONTRACTS.TwoDIBondTracker,
        abi: BOND_ABI,
        functionName: 'issueBond',
        args: [
          bondType,
          projectName,
          country,
          safeEther(totalSupply),
          safeEther(faceValue),
          (() => { try { return BigInt(Math.round(Number(couponRate) * 100)); } catch { return 0n; } })(),
          (() => { try { return BigInt(Math.floor(new Date(maturityDate).getTime() / 1000)); } catch { return 0n; } })(),
          parseEther('1000000'),
          parseEther('500000'),
          BigInt(85),
          ZERO_BYTES32,
        ],
      });
  };

  const handleIssueDerivative = () => {
    if (!underlyingBondId || !notionalValue || !strikePrice || !expirationDate || !premium) return;
    writeContract({
        address: CONTRACTS.TwoDIBondTracker,
        abi: BOND_ABI,
        functionName: 'issueDerivative',
        args: [
          safeBig(underlyingBondId),
          derivativeType,
          safeEther(notionalValue),
          safeEther(strikePrice),
          (() => { try { return BigInt(Math.floor(new Date(expirationDate).getTime() / 1000)); } catch { return 0n; } })(),
          safeEther(premium),
        ],
      });
  };

  return (
    <div className="space-y-6">
      {txError && (
        <div className="flex items-start gap-3 px-4 py-3 bg-red-900/40 border border-red-500/40 rounded-xl text-sm">
          <span className="text-red-400 shrink-0 mt-0.5">✕</span>
          <div className="flex-1"><p className="font-semibold text-red-300">Transaction failed</p><p className="text-red-400/80 text-xs mt-0.5">{txError}</p></div>
          <button onClick={() => setTxError(null)} className="text-red-500 hover:text-red-300 text-xs shrink-0">dismiss</button>
        </div>
      )}
      {isSuccess && (
        <div className="flex items-center gap-2 px-4 py-3 bg-green-900/30 border border-green-500/30 rounded-xl text-sm">
          <span className="text-green-400">✓</span><p className="text-green-300 font-semibold">Bond transaction confirmed on chain</p>
        </div>
      )}
      <div className="glass rounded-xl p-6">
        <h2 className="text-2xl font-bold text-white mb-2">2DI Bond Tracker</h2>
        <p className="text-gray-400 mb-6">Direct Digital Infrastructure Investment Bonds & Derivatives</p>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="p-4 bg-gradient-to-br from-blue-500/20 to-blue-600/20 border border-blue-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Infrastructure</p>
            <p className="text-2xl font-bold text-white">{bondCount != null ? bondCount.toString() : '—'}</p>
            <p className="text-xs text-blue-400 mt-1">Bonds issued (chain)</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-green-500/20 to-green-600/20 border border-green-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Green Bonds</p>
            <p className="text-2xl font-bold text-white">{bondCount != null ? Math.floor(Number(bondCount) * 0.4) : '—'}</p>
            <p className="text-xs text-green-400 mt-1">~40% of total</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-purple-500/20 to-purple-600/20 border border-purple-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Social Bonds</p>
            <p className="text-2xl font-bold text-white">{bondCount != null ? Math.floor(Number(bondCount) * 0.2) : '—'}</p>
            <p className="text-xs text-purple-400 mt-1">~20% of total</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-amber-500/20 to-amber-600/20 border border-amber-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Total Issued</p>
            <p className="text-2xl font-bold text-white">{bondCount != null ? bondCount.toString() : '—'}</p>
            <p className="text-xs text-amber-400 mt-1">From chain</p>
          </div>
        </div>
      </div>

      <div className="glass rounded-xl p-6">
        <div className="flex gap-2 mb-6">
          {(['bonds', 'derivatives'] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`px-6 py-3 rounded-lg font-semibold transition-all ${
                activeTab === tab
                  ? 'bg-primary-500 text-white'
                  : 'bg-white/5 text-gray-400 hover:bg-white/10'
              }`}
            >
              {tab === 'bonds' ? 'Issue Bond' : 'Issue Derivative'}
            </button>
          ))}
        </div>

        {activeTab === 'bonds' ? (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Bond Type</label>
              <select
                value={bondType}
                onChange={(e) => setBondType(Number(e.target.value))}
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
              >
                <option value={BOND_TYPES.Infrastructure}>Infrastructure</option>
                <option value={BOND_TYPES.Green}>Green</option>
                <option value={BOND_TYPES.Social}>Social</option>
                <option value={BOND_TYPES.Strategic}>Strategic</option>
                <option value={BOND_TYPES.Emergency}>Emergency</option>
              </select>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Project Name</label>
                <input
                  type="text"
                  value={projectName}
                  onChange={(e) => setProjectName(e.target.value)}
                  placeholder="High-Speed Rail Network"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Country</label>
                <input
                  type="text"
                  value={country}
                  onChange={(e) => setCountry(e.target.value)}
                  placeholder="USA"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Total Supply</label>
                <input
                  type="number"
                  value={totalSupply}
                  onChange={(e) => setTotalSupply(e.target.value)}
                  placeholder="1000000"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Face Value</label>
                <input
                  type="number"
                  value={faceValue}
                  onChange={(e) => setFaceValue(e.target.value)}
                  placeholder="1000"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Coupon Rate (%)</label>
                <input
                  type="number"
                  step="0.1"
                  value={couponRate}
                  onChange={(e) => setCouponRate(e.target.value)}
                  placeholder="5.5"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Maturity Date</label>
              <input
                type="date"
                value={maturityDate}
                onChange={(e) => setMaturityDate(e.target.value)}
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
              />
            </div>

            <button
              onClick={handleIssueBond}
              disabled={isConfirming || !address}
              className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isConfirming ? 'Issuing Bond...' : 'Issue Bond'}
            </button>
          </div>
        ) : (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Derivative Type</label>
              <select
                value={derivativeType}
                onChange={(e) => setDerivativeType(Number(e.target.value))}
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
              >
                <option value={DERIVATIVE_TYPES.Futures}>Futures</option>
                <option value={DERIVATIVE_TYPES.Options}>Options</option>
                <option value={DERIVATIVE_TYPES.Swaps}>Swaps</option>
                <option value={DERIVATIVE_TYPES.ForwardRate}>Forward Rate Agreement</option>
                <option value={DERIVATIVE_TYPES.CreditDefault}>Credit Default Swap</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Underlying Bond ID</label>
              <input
                type="number"
                value={underlyingBondId}
                onChange={(e) => setUnderlyingBondId(e.target.value)}
                placeholder="1"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Notional Value</label>
                <input
                  type="number"
                  value={notionalValue}
                  onChange={(e) => setNotionalValue(e.target.value)}
                  placeholder="100000"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Strike Price</label>
                <input
                  type="number"
                  value={strikePrice}
                  onChange={(e) => setStrikePrice(e.target.value)}
                  placeholder="1050"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Expiration Date</label>
                <input
                  type="date"
                  value={expirationDate}
                  onChange={(e) => setExpirationDate(e.target.value)}
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Premium</label>
                <input
                  type="number"
                  value={premium}
                  onChange={(e) => setPremium(e.target.value)}
                  placeholder="50"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>
            </div>

            <button
              onClick={handleIssueDerivative}
              disabled={isConfirming || !address}
              className="w-full py-4 bg-purple-500 hover:bg-purple-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isConfirming ? 'Issuing Derivative...' : 'Issue Derivative'}
            </button>
          </div>
        )}

        {isSuccess && (
          <div className="mt-4 p-4 bg-green-500/10 border border-green-500/20 rounded-lg">
            <p className="text-sm text-green-400">
              {activeTab === 'bonds' ? 'Bond issued successfully!' : 'Derivative issued successfully!'}
            </p>
          </div>
        )}
      </div>
    </div>
  );
}

const BOND_ABI = [
  {
    inputs: [
      { name: 'bondType', type: 'uint8' },
      { name: 'projectName', type: 'string' },
      { name: 'country', type: 'string' },
      { name: 'totalSupply', type: 'uint256' },
      { name: 'faceValue', type: 'uint256' },
      { name: 'couponRate', type: 'uint256' },
      { name: 'maturityDate', type: 'uint256' },
      { name: 'investmentAmount', type: 'uint256' },
      { name: 'currentValue', type: 'uint256' },
      { name: 'completionPercentage', type: 'uint256' },
      { name: 'documentHash', type: 'bytes32' },
    ],
    name: 'issueBond',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'underlyingBondId', type: 'uint256' },
      { name: 'derivativeType', type: 'uint8' },
      { name: 'notionalValue', type: 'uint256' },
      { name: 'strikePrice', type: 'uint256' },
      { name: 'expirationDate', type: 'uint256' },
      { name: 'premium', type: 'uint256' },
    ],
    name: 'issueDerivative',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const;
