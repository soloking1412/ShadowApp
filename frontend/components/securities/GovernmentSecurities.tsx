'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatEther, parseEther } from 'viem';
const safeEther = (v: string) => { try { return parseEther(v || '0'); } catch { return 0n; } };
const safeBig   = (v: string) => { try { return v ? BigInt(v) : 0n; } catch { return 0n; } };
import {
  useSecurityCounter,
  useTradeCounter,
  useTotalSecuritiesValue,
  useGetSecurity,
  useGetTrade,
  useIssueSecurity,
  useSettleTrade,
  SECURITY_TYPES,
} from '@/hooks/contracts/useGovernmentSecurities';

type Tab = 'overview' | 'issue' | 'trade' | 'settle';

export default function GovernmentSecuritiesDashboard() {
  const { address } = useAccount();
  const [tab, setTab] = useState<Tab>('overview');

  // Stats
  const { data: securityCount } = useSecurityCounter();
  const { data: tradeCount } = useTradeCounter();
  const { data: totalValue } = useTotalSecuritiesValue();

  // Issue form
  const [secType, setSecType] = useState(0);
  const [isin, setIsin] = useState('');
  const [cusip, setCusip] = useState('');
  const [faceValue, setFaceValue] = useState('');
  const [couponRate, setCouponRate] = useState('');
  const [maturityDays, setMaturityDays] = useState('');
  const [totalIssued, setTotalIssued] = useState('');

  // Lookup
  const [lookupSecId, setLookupSecId] = useState('');
  const [lookupTradeId, setLookupTradeId] = useState('');
  const [settleId, setSettleId] = useState('');

  const parsedSecId   = (() => { try { return lookupSecId   ? BigInt(lookupSecId)   : undefined; } catch { return undefined; } })();
  const parsedTradeId = (() => { try { return lookupTradeId ? BigInt(lookupTradeId) : undefined; } catch { return undefined; } })();
  const { data: securityData } = useGetSecurity(parsedSecId);
  const { data: tradeData } = useGetTrade(parsedTradeId);

  const { issueSecurity, isPending: issuing, isConfirming: issueConfirming, isSuccess: issueSuccess, error: issueError } = useIssueSecurity();
  const { settleTrade, isPending: settling, isConfirming: settleConfirming, isSuccess: settleSuccess } = useSettleTrade();

  const handleIssue = () => {
    if (!isin || !faceValue || !totalIssued) return;
    const maturity = maturityDays
      ? BigInt(Math.floor(Date.now() / 1000) + Number(maturityDays) * 86400)
      : BigInt(0);
    issueSecurity(
      secType,
      isin,
      cusip,
      safeEther(faceValue),
      couponRate ? (() => { try { return BigInt(Math.round(parseFloat(couponRate) * 100)); } catch { return 0n; } })() : 0n,
      maturity,
      safeEther(totalIssued),
    );
  };

  const handleSettle = () => {
    if (!settleId) return;
    settleTrade(safeBig(settleId));
  };

  const sec = securityData as any;
  const trade = tradeData as any;

  const TABS: { id: Tab; label: string }[] = [
    { id: 'overview', label: 'Overview' },
    { id: 'issue', label: 'Issue Security' },
    { id: 'trade', label: 'Trade Lookup' },
    { id: 'settle', label: 'Settle Trade' },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="glass rounded-xl p-6">
        <h2 className="text-2xl font-bold text-white mb-1">Government Securities Settlement</h2>
        <p className="text-gray-400">On-chain settlement for sovereign bonds, T-bills, and government instruments</p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Securities Issued</p>
          <p className="text-3xl font-bold text-white">{securityCount?.toString() ?? '—'}</p>
          <p className="text-xs text-blue-400 mt-1">Total instruments</p>
        </div>
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Trades Executed</p>
          <p className="text-3xl font-bold text-white">{tradeCount?.toString() ?? '—'}</p>
          <p className="text-xs text-green-400 mt-1">Pending settlement</p>
        </div>
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Total Value Locked</p>
          <p className="text-3xl font-bold text-white">
            {totalValue ? `$${parseFloat(formatEther(totalValue as bigint)).toLocaleString()}` : '—'}
          </p>
          <p className="text-xs text-purple-400 mt-1">Across all securities</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="glass rounded-xl overflow-hidden">
        <div className="flex border-b border-white/10">
          {TABS.map((t) => (
            <button
              key={t.id}
              onClick={() => setTab(t.id)}
              className={`px-6 py-4 text-sm font-medium transition-colors ${
                tab === t.id
                  ? 'border-b-2 border-primary-500 text-white bg-white/5'
                  : 'text-gray-400 hover:text-white'
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>

        <div className="p-6">
          {/* Overview */}
          {tab === 'overview' && (
            <div className="space-y-4">
              <h3 className="text-lg font-bold text-white">Security Types</h3>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                {SECURITY_TYPES.map((type, i) => (
                  <div
                    key={type}
                    className="p-4 bg-white/5 border border-white/10 rounded-lg hover:bg-white/10 transition-all cursor-pointer"
                  >
                    <p className="text-xs text-gray-400 mb-1">Type {i}</p>
                    <p className="font-semibold text-white">{type}</p>
                  </div>
                ))}
              </div>

              <div className="mt-6 p-4 bg-blue-500/10 border border-blue-500/20 rounded-lg">
                <p className="text-sm font-semibold text-white mb-2">Settlement Protocol</p>
                <ul className="space-y-1 text-xs text-gray-400">
                  <li>• DvP (Delivery vs Payment) atomic settlement</li>
                  <li>• T+0 finality via on-chain verification</li>
                  <li>• ISIN / CUSIP identification standard</li>
                  <li>• Coupon and maturity management</li>
                  <li>• Multi-party trade execution</li>
                </ul>
              </div>
            </div>
          )}

          {/* Issue Security */}
          {tab === 'issue' && (
            <div className="space-y-4 max-w-lg">
              <h3 className="text-lg font-bold text-white mb-4">Issue Government Security</h3>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Security Type</label>
                <select
                  value={secType}
                  onChange={(e) => setSecType(Number(e.target.value))}
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
                >
                  {SECURITY_TYPES.map((t, i) => (
                    <option key={t} value={i}>{t}</option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">ISIN</label>
                  <input
                    value={isin}
                    onChange={(e) => setIsin(e.target.value)}
                    placeholder="US912810TW90"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">CUSIP</label>
                  <input
                    value={cusip}
                    onChange={(e) => setCusip(e.target.value)}
                    placeholder="912810TW9"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Face Value (ETH)</label>
                  <input
                    type="number"
                    value={faceValue}
                    onChange={(e) => setFaceValue(e.target.value)}
                    placeholder="1000"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Coupon Rate (%)</label>
                  <input
                    type="number"
                    value={couponRate}
                    onChange={(e) => setCouponRate(e.target.value)}
                    placeholder="4.5"
                    step="0.01"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Maturity (days)</label>
                  <input
                    type="number"
                    value={maturityDays}
                    onChange={(e) => setMaturityDays(e.target.value)}
                    placeholder="3650"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Total Issued (ETH)</label>
                  <input
                    type="number"
                    value={totalIssued}
                    onChange={(e) => setTotalIssued(e.target.value)}
                    placeholder="1000000"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
              </div>

              <button
                onClick={handleIssue}
                disabled={issuing || issueConfirming || !address || !isin || !faceValue}
                className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {issuing || issueConfirming ? 'Issuing Security...' : issueSuccess ? 'Security Issued!' : 'Issue Security'}
              </button>

              {issueError && (
                <p className="text-xs text-red-400 bg-red-500/10 border border-red-500/20 rounded-lg p-3">
                  {issueError.message}
                </p>
              )}
            </div>
          )}

          {/* Trade Lookup */}
          {tab === 'trade' && (
            <div className="space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-3">
                  <h3 className="text-lg font-bold text-white">Security Lookup</h3>
                  <input
                    type="number"
                    value={lookupSecId}
                    onChange={(e) => setLookupSecId(e.target.value)}
                    placeholder="Security ID"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                  {sec && (
                    <div className="p-4 bg-white/5 border border-white/10 rounded-lg space-y-2 text-sm">
                      <div className="flex justify-between">
                        <span className="text-gray-400">ISIN</span>
                        <span className="text-white font-mono">{sec.isin}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Type</span>
                        <span className="text-blue-400">{SECURITY_TYPES[sec.securityType] ?? sec.securityType}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Face Value</span>
                        <span className="text-green-400">{formatEther(sec.faceValue ?? 0n)} ETH</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Coupon</span>
                        <span className="text-white">{(Number(sec.couponRate ?? 0) / 100).toFixed(2)}%</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Active</span>
                        <span className={sec.active ? 'text-green-400' : 'text-red-400'}>
                          {sec.active ? 'Yes' : 'No'}
                        </span>
                      </div>
                    </div>
                  )}
                </div>

                <div className="space-y-3">
                  <h3 className="text-lg font-bold text-white">Trade Lookup</h3>
                  <input
                    type="number"
                    value={lookupTradeId}
                    onChange={(e) => setLookupTradeId(e.target.value)}
                    placeholder="Trade ID"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                  {trade && (
                    <div className="p-4 bg-white/5 border border-white/10 rounded-lg space-y-2 text-sm">
                      <div className="flex justify-between">
                        <span className="text-gray-400">Security ID</span>
                        <span className="text-white">{trade.securityId?.toString()}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Quantity</span>
                        <span className="text-white">{formatEther(trade.quantity ?? 0n)} ETH</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Price</span>
                        <span className="text-green-400">{formatEther(trade.price ?? 0n)} ETH</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Settled</span>
                        <span className={trade.settled ? 'text-green-400' : 'text-amber-400'}>
                          {trade.settled ? 'Yes' : 'Pending'}
                        </span>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* Settle Trade */}
          {tab === 'settle' && (
            <div className="space-y-4 max-w-md">
              <h3 className="text-lg font-bold text-white">Settle Trade</h3>
              <p className="text-sm text-gray-400">
                Execute DvP settlement — transfers securities to buyer and payment to seller atomically.
              </p>
              <div>
                <label className="block text-sm text-gray-400 mb-1">Trade ID</label>
                <input
                  type="number"
                  value={settleId}
                  onChange={(e) => setSettleId(e.target.value)}
                  placeholder="Trade ID"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>
              <button
                onClick={handleSettle}
                disabled={settling || settleConfirming || !settleId || !address}
                className="w-full py-4 bg-green-600 hover:bg-green-700 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {settling || settleConfirming ? 'Settling...' : settleSuccess ? 'Trade Settled!' : 'Settle Trade'}
              </button>
              {settleSuccess && (
                <div className="flex items-center gap-2 text-green-400 text-sm p-3 bg-green-500/10 border border-green-500/20 rounded-lg">
                  <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  Trade settled successfully on-chain.
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
