'use client';
import React, { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatEther } from 'viem';
import {
  useBrokerCounter, useActiveBrokers, useTotalBrokerVolume,
  useGetBroker, useGetBrokerByWallet, useGetBrokerClients,
  useRegisterBroker, useOnboardClient, useApproveBroker,
} from '@/hooks/contracts/usePublicBroker';

const BROKER_STATUS = ['Pending', 'Active', 'Suspended', 'Revoked'];
const LICENSE_TIERS = ['Retail', 'Institutional', 'Prime', 'Sovereign'];
const STATUS_COLORS: Record<number, string> = {
  0: 'bg-yellow-500/20 text-yellow-300',
  1: 'bg-green-500/20 text-green-300',
  2: 'bg-orange-500/20 text-orange-300',
  3: 'bg-red-500/20 text-red-300',
};
const TIER_COLORS: Record<number, string> = {
  0: 'bg-gray-500/20 text-gray-300',
  1: 'bg-blue-500/20 text-blue-300',
  2: 'bg-purple-500/20 text-purple-300',
  3: 'bg-amber-500/20 text-amber-300',
};

export default function PublicBroker() {
  const { address, isConnected } = useAccount();
  const [tab, setTab] = useState<'overview' | 'register' | 'clients' | 'lookup'>('overview');

  // Register form
  const [companyName, setCompanyName] = useState('');
  const [regNumber, setRegNumber] = useState('');
  const [jurisdiction, setJurisdiction] = useState('');
  const [licenseNumber, setLicenseNumber] = useState('');
  const [tier, setTier] = useState(0);
  const [websiteUrl, setWebsiteUrl] = useState('');
  const [contactEmail, setContactEmail] = useState('');

  // Client onboard
  const [clientAddr, setClientAddr] = useState('');

  // Admin
  const [approveBrokerId, setApproveBrokerId] = useState('');

  // Lookup
  const [lookupBrokerId, setLookupBrokerId] = useState('');
  const [lookupClientsId, setLookupClientsId] = useState('');

  const { data: brokerCount } = useBrokerCounter();
  const { data: activeCount } = useActiveBrokers();
  const { data: totalVol } = useTotalBrokerVolume();
  const { data: myBroker } = useGetBrokerByWallet(address);
  const { data: lookupBroker, refetch: refetchBroker } = useGetBroker(lookupBrokerId ? BigInt(lookupBrokerId) : 0n);
  const { data: brokerClients, refetch: refetchClients } = useGetBrokerClients(lookupClientsId ? BigInt(lookupClientsId) : 0n);

  const { registerBroker, isPending: registering, isSuccess: registered } = useRegisterBroker();
  const { onboardClient, isPending: onboarding, isSuccess: onboarded } = useOnboardClient();
  const { approveBroker, isPending: approving } = useApproveBroker();

  const handleRegister = () => {
    if (!companyName || !regNumber) return;
    registerBroker(companyName, regNumber, jurisdiction, licenseNumber, tier, websiteUrl, contactEmail);
  };

  const TABS = [
    { id: 'overview', label: 'Overview' },
    { id: 'register', label: 'Register Broker' },
    { id: 'clients', label: 'Client Onboarding' },
    { id: 'lookup', label: 'Lookup' },
  ] as const;

  const myBrokerData = myBroker as { brokerId: bigint; companyName: string; status: number; tier: number; complianceScore: bigint; kycVerified: boolean; amlVerified: boolean; totalClientsOnboarded: bigint } | undefined;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Public Broker Registry</h2>
        <p className="text-gray-400 mt-1">On-chain broker onboarding, licensing & compliance tracking</p>
      </div>

      <div className="flex gap-2 border-b border-white/10 pb-2">
        {TABS.map(t => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={`px-4 py-2 rounded-t text-sm font-medium transition-colors ${
              tab === t.id ? 'bg-emerald-600 text-white' : 'text-gray-400 hover:text-white'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Overview */}
      {tab === 'overview' && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
            {[
              { label: 'Total Brokers', value: brokerCount?.toString() ?? '—' },
              { label: 'Active Brokers', value: activeCount?.toString() ?? '—' },
              { label: 'Volume Processed', value: totalVol ? `${parseFloat(formatEther(totalVol as bigint)).toFixed(2)} ETH` : '—' },
            ].map(s => (
              <div key={s.label} className="bg-white/5 rounded-xl p-4 border border-white/10">
                <div className="text-xs text-gray-400">{s.label}</div>
                <div className="text-xl font-bold text-white mt-1">{s.value}</div>
              </div>
            ))}
          </div>

          {/* My Broker Status */}
          {isConnected && myBrokerData && myBrokerData.brokerId > 0n && (
            <div className="bg-white/5 rounded-xl p-5 border border-white/10 space-y-3">
              <h3 className="font-semibold text-white">My Broker Profile</h3>
              <div className="flex items-center gap-3 flex-wrap">
                <span className="font-semibold text-white">{myBrokerData.companyName}</span>
                <span className={`text-xs px-2 py-0.5 rounded-full ${STATUS_COLORS[myBrokerData.status] ?? ''}`}>{BROKER_STATUS[myBrokerData.status]}</span>
                <span className={`text-xs px-2 py-0.5 rounded-full ${TIER_COLORS[myBrokerData.tier] ?? ''}`}>{LICENSE_TIERS[myBrokerData.tier]}</span>
              </div>
              <div className="grid grid-cols-3 gap-3 text-sm">
                <div><span className="text-gray-400">KYC:</span> <span className={myBrokerData.kycVerified ? 'text-green-400' : 'text-red-400'}>{myBrokerData.kycVerified ? '✓ Verified' : '✗ Pending'}</span></div>
                <div><span className="text-gray-400">AML:</span> <span className={myBrokerData.amlVerified ? 'text-green-400' : 'text-red-400'}>{myBrokerData.amlVerified ? '✓ Verified' : '✗ Pending'}</span></div>
                <div><span className="text-gray-400">Compliance:</span> <span className="text-white">{myBrokerData.complianceScore.toString()}/100</span></div>
                <div><span className="text-gray-400">Clients:</span> <span className="text-white">{myBrokerData.totalClientsOnboarded.toString()}</span></div>
              </div>
            </div>
          )}

          <div className="bg-white/5 rounded-xl p-5 border border-white/10">
            <h3 className="font-semibold text-white mb-2">Admin: Approve Broker</h3>
            <div className="flex gap-3">
              <input
                className="flex-1 bg-white/10 text-white rounded px-3 py-2 border border-white/20 text-sm"
                placeholder="Broker ID to approve"
                value={approveBrokerId}
                onChange={e => setApproveBrokerId(e.target.value)}
                type="number"
              />
              <button
                onClick={() => approveBrokerId && approveBroker(BigInt(approveBrokerId))}
                disabled={approving || !isConnected || !approveBrokerId}
                className="bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 text-white px-4 py-2 rounded text-sm"
              >
                {approving ? 'Approving…' : 'Approve'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Register */}
      {tab === 'register' && (
        <div className="bg-white/5 rounded-xl p-5 border border-white/10 max-w-lg space-y-4">
          <h3 className="font-semibold text-white">Register as Broker</h3>
          <div className="grid grid-cols-2 gap-3">
            <div className="col-span-2">
              <label className="text-xs text-gray-400 block mb-1">Company Name *</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" value={companyName} onChange={e => setCompanyName(e.target.value)} placeholder="ACME Capital Ltd" />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Registration Number *</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" value={regNumber} onChange={e => setRegNumber(e.target.value)} placeholder="REG-2024-00123" />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Jurisdiction</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" value={jurisdiction} onChange={e => setJurisdiction(e.target.value)} placeholder="Tirana, OZF" />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">License Number</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" value={licenseNumber} onChange={e => setLicenseNumber(e.target.value)} placeholder="LIC-OZF-001" />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">License Tier</label>
              <select className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" value={tier} onChange={e => setTier(Number(e.target.value))}>
                {LICENSE_TIERS.map((t, i) => <option key={i} value={i}>{t}</option>)}
              </select>
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Website URL</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" value={websiteUrl} onChange={e => setWebsiteUrl(e.target.value)} placeholder="https://acmecapital.com" />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Contact Email</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" value={contactEmail} onChange={e => setContactEmail(e.target.value)} placeholder="compliance@acme.com" />
            </div>
          </div>
          <button
            onClick={handleRegister}
            disabled={registering || !isConnected || !companyName || !regNumber}
            className="w-full bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 text-white font-medium py-2 rounded"
          >
            {registering ? 'Registering…' : registered ? 'Registered! (pending approval)' : 'Register Broker'}
          </button>
          {!isConnected && <p className="text-xs text-yellow-400">Connect wallet to register</p>}
        </div>
      )}

      {/* Client Onboarding */}
      {tab === 'clients' && (
        <div className="space-y-4 max-w-lg">
          <div className="bg-white/5 rounded-xl p-5 border border-white/10 space-y-4">
            <h3 className="font-semibold text-white">Onboard a Client</h3>
            <p className="text-sm text-gray-300">You must be an active broker to onboard clients. The client address will be assigned to your broker ID on-chain.</p>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Client Wallet Address</label>
              <input
                className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20"
                placeholder="0x..."
                value={clientAddr}
                onChange={e => setClientAddr(e.target.value)}
              />
            </div>
            <button
              onClick={() => clientAddr && onboardClient(clientAddr as `0x${string}`)}
              disabled={onboarding || !isConnected || !clientAddr}
              className="w-full bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 text-white font-medium py-2 rounded"
            >
              {onboarding ? 'Onboarding…' : onboarded ? 'Client Onboarded!' : 'Onboard Client'}
            </button>
          </div>
          <div className="bg-white/5 rounded-xl p-5 border border-white/10 space-y-3">
            <h3 className="font-semibold text-white">View Broker Clients</h3>
            <div className="flex gap-3">
              <input
                className="flex-1 bg-white/10 text-white rounded px-3 py-2 border border-white/20 text-sm"
                placeholder="Broker ID"
                value={lookupClientsId}
                onChange={e => setLookupClientsId(e.target.value)}
                type="number"
              />
              <button onClick={() => refetchClients()} className="bg-emerald-600 hover:bg-emerald-700 text-white px-4 py-2 rounded text-sm">Fetch</button>
            </div>
            {!!brokerClients && (brokerClients as string[]).length > 0 && (
              <div className="space-y-1">
                {(brokerClients as string[]).map((c, i) => (
                  <div key={i} className="font-mono text-xs text-gray-300 bg-white/5 rounded px-3 py-1">{c}</div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Lookup */}
      {tab === 'lookup' && (
        <div className="space-y-4">
          <div className="flex gap-3 max-w-md">
            <input
              className="flex-1 bg-white/10 text-white rounded px-3 py-2 border border-white/20"
              placeholder="Broker ID"
              value={lookupBrokerId}
              onChange={e => setLookupBrokerId(e.target.value)}
              type="number"
            />
            <button onClick={() => refetchBroker()} className="bg-emerald-600 hover:bg-emerald-700 text-white px-4 py-2 rounded">Lookup</button>
          </div>

          {!!lookupBroker && (lookupBroker as { brokerId: bigint }).brokerId > 0n && ((): React.ReactElement | null => {
            const b = lookupBroker as {
              brokerId: bigint; wallet: string; companyName: string;
              registrationNumber: string; jurisdiction: string; licenseNumber: string;
              tier: number; status: number; complianceScore: bigint;
              kycVerified: boolean; amlVerified: boolean;
              totalClientsOnboarded: bigint; totalVolumeHandled: bigint;
              websiteUrl: string; contactEmail: string;
            };
            return (
              <div className="bg-white/5 rounded-xl p-5 border border-white/10 space-y-3 max-w-lg">
                <div className="flex items-center justify-between flex-wrap gap-2">
                  <span className="font-semibold text-white">{b.companyName}</span>
                  <div className="flex gap-2">
                    <span className={`text-xs px-2 py-0.5 rounded-full ${TIER_COLORS[b.tier] ?? ''}`}>{LICENSE_TIERS[b.tier]}</span>
                    <span className={`text-xs px-2 py-0.5 rounded-full ${STATUS_COLORS[b.status] ?? ''}`}>{BROKER_STATUS[b.status]}</span>
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-2 text-sm">
                  <div><span className="text-gray-400">Reg #:</span> <span className="text-white">{b.registrationNumber}</span></div>
                  <div><span className="text-gray-400">License:</span> <span className="text-white">{b.licenseNumber}</span></div>
                  <div><span className="text-gray-400">Jurisdiction:</span> <span className="text-white">{b.jurisdiction}</span></div>
                  <div><span className="text-gray-400">Clients:</span> <span className="text-white">{b.totalClientsOnboarded.toString()}</span></div>
                  <div><span className="text-gray-400">KYC:</span> <span className={b.kycVerified ? 'text-green-400' : 'text-red-400'}>{b.kycVerified ? '✓' : '✗'}</span></div>
                  <div><span className="text-gray-400">AML:</span> <span className={b.amlVerified ? 'text-green-400' : 'text-red-400'}>{b.amlVerified ? '✓' : '✗'}</span></div>
                  <div><span className="text-gray-400">Score:</span> <span className="text-white">{b.complianceScore.toString()}/100</span></div>
                  <div><span className="text-gray-400">Volume:</span> <span className="text-white">{formatEther(b.totalVolumeHandled)} ETH</span></div>
                  <div className="col-span-2"><span className="text-gray-400">Wallet:</span> <span className="text-white font-mono text-xs">{b.wallet}</span></div>
                </div>
              </div>
            );
          })()}
        </div>
      )}
    </div>
  );
}
