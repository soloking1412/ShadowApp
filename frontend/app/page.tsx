'use client';

import { useState } from 'react';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import IchimokuChart from '@/components/trading/IchimokuChart';
import DarkPoolOrderForm from '@/components/trading/DarkPoolOrderForm';
import CEXOrderBook from '@/components/trading/CEXOrderBook';
import TreasuryDashboard from '@/components/treasury/TreasuryDashboard';
import TwoDIBondManager from '@/components/bonds/TwoDIBondManager';
import FractionalReserveDashboard from '@/components/banking/FractionalReserveDashboard';
import ForexReservesTracker from '@/components/forex/ForexReservesTracker';
import GovernanceDashboard from '@/components/dao/GovernanceDashboard';
import ChatWindow from '@/components/chat/ChatWindow';
import PublicLobby from '@/components/lobby/PublicLobby';
import MediaMonitor from '@/components/media/MediaMonitor';
import SecureChat from '@/components/chat/SecureChat';
import BlacklistRegistry from '@/components/registry/BlacklistRegistry';
import AMMDashboard from '@/components/amm/AMMDashboard';
import InviteManagerDashboard from '@/components/access/InviteManager';
import ObsidianCapitalDashboard from '@/components/capital/ObsidianCapital';
import PrimeBrokerageDashboard from '@/components/brokerage/PrimeBrokerage';
import LiquidityServiceDashboard from '@/components/liquidity/LiquidityService';
import GovernmentSecuritiesDashboard from '@/components/securities/GovernmentSecurities';
import DigitalTradeBlocksDashboard from '@/components/trade/DigitalTradeBlocks';
import OZFParliamentDashboard from '@/components/parliament/OZFParliament';
import ArmsComplianceDashboard from '@/components/arms/ArmsCompliance';
import InfrastructureAssetsDashboard from '@/components/infrastructure/InfrastructureAssets';
import SpecialEconomicZoneDashboard from '@/components/sez/SpecialEconomicZone';
import SovereignDEXDashboard from '@/components/dex/SovereignDEX';
import BondAuctionDashboard from '@/components/auction/BondAuction';
import PublicBrokerDashboard from '@/components/broker/PublicBroker';
import HFTEngineDashboard from '@/components/hft/HFTEngine';
import AVSPlatformDashboard from '@/components/avs/AVSPlatform';
import OTDTokenDashboard from '@/components/otd/OTDTokenDashboard';
import OrionScoreDashboard from '@/components/orion/OrionScoreDashboard';
import FreeTradeRegistryDashboard from '@/components/trade/FreeTradeRegistry';
import ICFLendingDashboard from '@/components/lending/ICFLendingDashboard';
import PreAllocationDashboard from '@/components/prealloc/PreAllocationDashboard';
import JobsBoardDashboard from '@/components/jobs/JobsBoardDashboard';
import DTXDashboard from '@/components/dtx/DTXDashboard';
import DCMCharter from '@/components/dcm/DCMCharter';
import PriceOracleDashboard from '@/components/oracle/PriceOracleDashboard';
import GlobalExchangeTrading from '@/components/trading/GlobalExchangeTrading';
import TradingTerminal from '@/components/trading/TradingTerminal';
import ODCMDashboard from '@/components/odcm/ODCMDashboard';
import SGMTokenDashboard from '@/components/sgm/SGMTokenDashboard';
import SGMXTokenDashboard from '@/components/sgmx/SGMXTokenDashboard';
import AnvilDevTools from '@/components/devtools/AnvilDevTools';
import AnvilStatusBanner from '@/components/ui/AnvilStatusBanner';
// Live stats hooks
import { usePreAllocTotalValidators, usePreAllocTotalShareholders } from '@/hooks/contracts/usePreAllocation';
import { useJobsBoardJobCounter, useJobsBoardTotalCompleted } from '@/hooks/contracts/useJobsBoard';
import { useFTRAgreementCounter, useFTRBolCounter } from '@/hooks/contracts/useFreeTradeRegistry';
import { useAVSTotalAssets, useAVSTotalCountries } from '@/hooks/contracts/useAVSPlatform';
import { useICFLoanCounter, useICFActiveLoans } from '@/hooks/contracts/useICFLending';
import { useOrionCountryCount, useOrionApprovedCountries } from '@/hooks/contracts/useOrionScore';
import { useBrokerCounter, useActiveBrokers } from '@/hooks/contracts/usePublicBroker';
import { useOTDTotalHolders, useOTDTotalVotes } from '@/hooks/contracts/useOTDToken';

type Section =
  | 'overview' | 'trading' | 'amm' | 'treasury' | 'bonds'
  | 'banking' | 'forex' | 'prime' | 'obsidian' | 'laas'
  | 'governance' | 'invites' | 'registry' | 'lobby' | 'media' | 'chat'
  | 'gov-securities' | 'trade-blocks' | 'parliament' | 'arms' | 'infrastructure' | 'sez'
  | 'sovereign-dex' | 'bond-auction' | 'broker-registry' | 'hft-engine'
  | 'avs-platform' | 'otd-token' | 'orion-score' | 'free-trade' | 'icf-lending' | 'pre-alloc' | 'jobs-board'
  | 'dtx' | 'dcm-charter' | 'price-oracle' | 'exchange-trading' | 'odcm' | 'sgm-token' | 'sgmx-token';

const chainId = parseInt(process.env.NEXT_PUBLIC_CHAIN_ID || '421614');
const isLocal = chainId === 31337;

export default function Home() {
  const [activeSection, setActiveSection] = useState<Section>('overview');
  const [showChat, setShowChat] = useState(false);

  // Live network stats from contracts
  const { data: preAllocValidators } = usePreAllocTotalValidators();
  const { data: preAllocShareholders } = usePreAllocTotalShareholders();
  const { data: totalJobs } = useJobsBoardJobCounter();
  const { data: jobsDone } = useJobsBoardTotalCompleted();
  const { data: tradeAgreements } = useFTRAgreementCounter();
  const { data: billsOfLading } = useFTRBolCounter();
  const { data: avsAssetCount } = useAVSTotalAssets();
  const { data: avsCountryCount } = useAVSTotalCountries();
  const { data: icfLoanCount } = useICFLoanCounter();
  const { data: icfActiveLoans } = useICFActiveLoans();
  const { data: orionCountryCount } = useOrionCountryCount();
  const { data: orionApproved } = useOrionApprovedCountries();
  const { data: brokerTotal } = useBrokerCounter();
  const { data: brokerActive } = useActiveBrokers();
  const { data: otdHolders } = useOTDTotalHolders();
  const { data: otdVotes } = useOTDTotalVotes();

  const navigation: { id: Section; name: string; icon: string; group: string }[] = [
    // Core Platform
    { id: 'overview',       name: 'Overview',              icon: '📊', group: 'Platform' },
    { id: 'trading',        name: 'Dark Pool',             icon: '🌑', group: 'Platform' },
    { id: 'amm',            name: 'Universal AMM',         icon: '🔄', group: 'Platform' },
    { id: 'invites',        name: 'Invite Manager',        icon: '🔐', group: 'Platform' },
    { id: 'registry',       name: 'OGR Blacklist',         icon: '📋', group: 'Platform' },
    // Finance & Capital
    { id: 'treasury',       name: 'OICD Treasury',         icon: '💰', group: 'Finance' },
    { id: 'bonds',          name: '2DI Bonds',             icon: '📜', group: 'Finance' },
    { id: 'gov-securities', name: 'Gov Securities',        icon: '🏛️', group: 'Finance' },
    { id: 'trade-blocks',   name: 'Trade Blocks',          icon: '🧱', group: 'Finance' },
    { id: 'prime',          name: 'Prime Brokerage',       icon: '🏛', group: 'Finance' },
    { id: 'obsidian',       name: 'Obsidian Capital',      icon: '💎', group: 'Finance' },
    { id: 'laas',           name: 'LaaS',                  icon: '💧', group: 'Finance' },
    // Banking & FX
    { id: 'banking',        name: 'IBAN Banking',          icon: '🏦', group: 'Banking' },
    { id: 'forex',          name: 'Forex Reserves',        icon: '💱', group: 'Banking' },
    // Infrastructure & Sovereign
    { id: 'infrastructure', name: 'Infrastructure',        icon: '🚢', group: 'Sovereign' },
    { id: 'sez',            name: 'Economic Zones',        icon: '🏙️', group: 'Sovereign' },
    { id: 'parliament',     name: 'OZF Parliament',        icon: '🌐', group: 'Sovereign' },
    { id: 'arms',           name: 'Arms Compliance',       icon: '🛡️', group: 'Sovereign' },
    // Finance & Capital — Phase 2C
    { id: 'sovereign-dex',  name: 'Sovereign DEX',         icon: '🔀', group: 'Finance' },
    { id: 'bond-auction',   name: 'Bond Auctions',         icon: '🏷️', group: 'Finance' },
    { id: 'broker-registry',name: 'Broker Registry',       icon: '👥', group: 'Finance' },
    { id: 'hft-engine',     name: 'HFT Engine (GLTE)',     icon: '⚡', group: 'Finance' },
    // Phase 3
    { id: 'avs-platform',   name: 'AVS Platform',          icon: '🌍', group: 'Finance' },
    { id: 'otd-token',      name: 'OTD Token',             icon: '🪙', group: 'Finance' },
    { id: 'icf-lending',    name: 'ICF Lending',           icon: '🏗️', group: 'Finance' },
    { id: 'pre-alloc',      name: 'Pre-Allocation',        icon: '📦', group: 'Finance' },
    { id: 'orion-score',    name: 'Orion Score',           icon: '🔮', group: 'Sovereign' },
    { id: 'free-trade',     name: 'Free Trade Registry',   icon: '🤝', group: 'Sovereign' },
    { id: 'jobs-board',     name: 'Jobs Board',            icon: '💼', group: 'Governance' },
    // Phase 4
    { id: 'dtx',              name: 'DTX Bourse',          icon: '🏦', group: 'Finance'    },
    { id: 'dcm-charter',      name: 'DCM Charter',         icon: '📐', group: 'Finance'    },
    { id: 'price-oracle',     name: 'Price Oracle',        icon: '📡', group: 'Finance'    },
    { id: 'exchange-trading', name: 'Trading Terminal',    icon: '🖥️', group: 'Finance'    },
    { id: 'odcm',             name: 'ODCM Dashboard',      icon: '🌐', group: 'Finance'    },
    { id: 'sgm-token',        name: 'SGM Token',           icon: '🟣', group: 'Finance'    },
    { id: 'sgmx-token',       name: 'SGMX Security Token', icon: '🔵', group: 'Finance'    },
    // Governance & Comms
    { id: 'governance',     name: 'DAO Governance',        icon: '⚖️', group: 'Governance' },
    { id: 'lobby',          name: 'Public Lobby',          icon: '🗣️', group: 'Governance' },
    { id: 'media',          name: 'Media Monitor',         icon: '📰', group: 'Governance' },
    { id: 'chat',           name: 'Secure Chat',           icon: '💬', group: 'Governance' },
  ];

  const groups = ['Platform', 'Finance', 'Banking', 'Sovereign', 'Governance'];

  return (
    <div className="min-h-screen bg-gradient-to-br from-dark-900 via-dark-800 to-dark-900">
      {/* Top Nav */}
      <nav className="glass border-b border-white/10 sticky top-0 z-50 backdrop-blur-xl">
        <div className="container mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-gradient-to-br from-primary-500 to-purple-600 rounded-lg flex items-center justify-center">
                <span className="text-2xl">🌐</span>
              </div>
              <div>
                <h1 className="text-xl font-bold text-white">ShadowDapp</h1>
                <p className="text-xs text-purple-400 font-semibold">OZF - OZHUMANILL ZAYED FEDERATION</p>
              </div>
            </div>
            <div className="flex items-center gap-4">
              <button
                onClick={() => setShowChat(!showChat)}
                className="relative px-4 py-2 bg-white/5 hover:bg-white/10 text-white rounded-lg transition-all flex items-center gap-2"
              >
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                </svg>
                Chat
              </button>
              <ConnectButton />
            </div>
          </div>
        </div>
      </nav>

      <div className="container mx-auto px-6 py-8">
        <div className="flex gap-6">
          {/* Sidebar */}
          <aside className="w-56 flex-shrink-0">
            <div className="glass rounded-xl p-3 sticky top-24 max-h-[calc(100vh-8rem)] overflow-y-auto">
              <nav className="space-y-0.5">
                {groups.map((group) => (
                  <div key={group}>
                    <p className="text-xs text-gray-600 font-semibold uppercase tracking-wider px-3 pt-3 pb-1">{group}</p>
                    {navigation.filter((item) => item.group === group).map((item) => (
                      <button
                        key={item.id}
                        onClick={() => setActiveSection(item.id)}
                        className={`w-full text-left px-3 py-2 rounded-lg text-sm font-medium transition-all flex items-center gap-2.5 ${
                          activeSection === item.id
                            ? 'bg-primary-500 text-white shadow-lg shadow-primary-500/20'
                            : 'text-gray-400 hover:bg-white/5 hover:text-white'
                        }`}
                      >
                        <span className="text-sm">{item.icon}</span>
                        {item.name}
                      </button>
                    ))}
                  </div>
                ))}
              </nav>
            </div>
          </aside>

          {/* Main content */}
          <main className="flex-1 min-w-0">
            <AnvilStatusBanner />

            {activeSection === 'overview' && (
              <div className="space-y-6">
                {/* {isLocal && <AnvilDevTools />} */}

                {/* Hero Section */}
                <div className="bg-gradient-to-br from-slate-900/80 via-primary-900/20 to-purple-900/30 border border-primary-500/20 rounded-xl p-6 space-y-5">
                  <div className="flex items-start justify-between flex-wrap gap-3">
                    <div>
                      <div className="flex items-center gap-2 mb-2">
                        <span className="text-xs font-semibold uppercase tracking-widest text-primary-400 bg-primary-500/10 px-3 py-1 rounded-full border border-primary-500/20">Obsidian Capital Platform</span>
                      </div>
                      <h2 className="text-3xl font-bold text-white">ShadowDapp</h2>
                      <p className="text-gray-400 text-sm mt-1">Alternative Global Digital Economy for Emerging Markets · Ozhumanill Zayed Federation</p>
                      <p className="text-xs text-gray-500 mt-1">Kratos Smart Chain · ABFT Proof-of-Stake · 250-yr Lease · 40/60 Revenue Split (Obsidian/Country)</p>
                    </div>
                    <span className={`text-xs font-medium px-3 py-1 rounded-full border self-start ${isLocal ? 'bg-green-500/20 text-green-400 border-green-500/30' : 'bg-blue-500/20 text-blue-400 border-blue-500/30'}`}>
                      {isLocal ? '● Anvil 31337' : '● Arb Sepolia'}
                    </span>
                  </div>
                  <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
                    {[
                      { icon: '📜', label: 'Contracts', value: '33' },
                      { icon: '🌍', label: 'Currencies', value: '61' },
                      { icon: '🏦', label: 'Bourse Centers', value: '5' },
                      { icon: '💱', label: 'FX Corridors', value: '287' },
                      { icon: '🎯', label: 'Validator Target', value: '250K' },
                    ].map(({ icon, label, value }) => (
                      <div key={label} className="p-4 bg-white/5 border border-white/10 rounded-xl text-center">
                        <div className="text-xl mb-1">{icon}</div>
                        <p className="text-2xl font-bold text-white">{value}</p>
                        <p className="text-xs text-gray-400 mt-0.5">{label}</p>
                      </div>
                    ))}
                  </div>
                  <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
                    {([
                      { id: 'treasury' as Section, label: 'Finance', icon: '💰', desc: 'Treasury · Bonds · DEX · Lending', color: 'from-cyan-500/10 to-blue-500/10 border-cyan-500/20 hover:border-cyan-500/50' },
                      { id: 'infrastructure' as Section, label: 'Sovereign', icon: '🌐', desc: 'Infrastructure · SEZs · Parliament', color: 'from-purple-500/10 to-violet-500/10 border-purple-500/20 hover:border-purple-500/50' },
                      { id: 'banking' as Section, label: 'Banking', icon: '🏦', desc: 'IBAN Banking · 287 FX Corridors', color: 'from-emerald-500/10 to-teal-500/10 border-emerald-500/20 hover:border-emerald-500/50' },
                      { id: 'trading' as Section, label: 'Platform', icon: '🌑', desc: 'Dark Pool · AMM · Invites', color: 'from-slate-500/10 to-gray-500/10 border-slate-500/20 hover:border-slate-500/50' },
                      { id: 'governance' as Section, label: 'Governance', icon: '⚖️', desc: 'DAO · Lobby · Jobs Board', color: 'from-amber-500/10 to-orange-500/10 border-amber-500/20 hover:border-amber-500/50' },
                    ]).map(({ id, label, icon, desc, color }) => (
                      <button key={label} onClick={() => setActiveSection(id)}
                        className={`bg-gradient-to-br ${color} border rounded-xl p-4 text-left transition-all hover:scale-105`}>
                        <div className="text-xl mb-1">{icon}</div>
                        <div className="text-white text-sm font-semibold">{label}</div>
                        <div className="text-gray-400 text-xs mt-0.5">{desc}</div>
                      </button>
                    ))}
                  </div>
                </div>

                {/* Live Network Activity — all dynamic from contracts */}
                <div className="glass rounded-xl p-6">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-lg font-bold text-white">Live Network Activity</h3>
                    <span className="text-xs text-green-400 flex items-center gap-1.5">
                      <span className="w-1.5 h-1.5 rounded-full bg-green-400 animate-pulse inline-block" />
                      Live from chain
                    </span>
                  </div>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                    {([
                      { label: 'Validators', value: String(preAllocValidators??0), icon: '🎯', nav: 'pre-alloc' as Section, sub: 'Pre-Alloc' },
                      { label: 'Shareholders', value: String(preAllocShareholders??0), icon: '📦', nav: 'pre-alloc' as Section, sub: 'Pre-Alloc' },
                      { label: 'Jobs Posted', value: String(totalJobs??0), icon: '💼', nav: 'jobs-board' as Section, sub: 'Jobs Board' },
                      { label: 'Jobs Completed', value: String(jobsDone??0), icon: '✅', nav: 'jobs-board' as Section, sub: 'Jobs Board' },
                      { label: 'Trade Agreements', value: String(tradeAgreements??0), icon: '🤝', nav: 'free-trade' as Section, sub: 'Free Trade' },
                      { label: 'Bills of Lading', value: String(billsOfLading??0), icon: '📋', nav: 'free-trade' as Section, sub: 'Free Trade' },
                      { label: 'AVS Assets', value: String(avsAssetCount??0), icon: '🌍', nav: 'avs-platform' as Section, sub: 'AVS Platform' },
                      { label: 'AVS Countries', value: String(avsCountryCount??0), icon: '🗺️', nav: 'avs-platform' as Section, sub: 'AVS Platform' },
                      { label: 'ICF Loans', value: String(icfLoanCount??0), icon: '🏗️', nav: 'icf-lending' as Section, sub: 'ICF Lending' },
                      { label: 'Active Loans', value: String(icfActiveLoans??0), icon: '📈', nav: 'icf-lending' as Section, sub: 'ICF Lending' },
                      { label: 'Orion Countries', value: String(orionCountryCount??0), icon: '🔮', nav: 'orion-score' as Section, sub: 'Orion Score' },
                      { label: 'FDI Approved', value: String((orionApproved as string[]|undefined)?.length??0), icon: '✓', nav: 'orion-score' as Section, sub: 'Orion Score' },
                      { label: 'OTD Holders', value: String(otdHolders??0), icon: '🪙', nav: 'otd-token' as Section, sub: 'OTD Token' },
                      { label: 'OTD Votes', value: String(otdVotes??0), icon: '⚖️', nav: 'otd-token' as Section, sub: 'OTD Token' },
                      { label: 'Brokers', value: brokerTotal?.toString()??'0', icon: '👥', nav: 'broker-registry' as Section, sub: 'Broker Registry' },
                      { label: 'Active Brokers', value: brokerActive?.toString()??'0', icon: '🟢', nav: 'broker-registry' as Section, sub: 'Broker Registry' },
                    ]).map(({ label, value, icon, nav, sub }) => (
                      <button key={label} onClick={() => setActiveSection(nav)}
                        className="p-4 bg-white/5 border border-white/10 rounded-xl text-left hover:bg-white/10 hover:border-white/20 transition-all group">
                        <div className="flex items-center justify-between mb-2">
                          <span className="text-lg">{icon}</span>
                          <span className="text-xs text-gray-600 group-hover:text-gray-400 transition-colors truncate ml-1">{sub} →</span>
                        </div>
                        <p className="text-2xl font-bold text-white">{value}</p>
                        <p className="text-xs text-gray-400 mt-0.5">{label}</p>
                      </button>
                    ))}
                  </div>
                </div>

                {/* All Systems — navigable grid, no static text */}
                <div className="glass rounded-xl p-6">
                  <h3 className="text-lg font-bold text-white mb-4">All 51 Systems</h3>
                  <div className="grid grid-cols-3 md:grid-cols-6 gap-2">
                    {navigation.filter(item => item.id !== 'overview').map((item) => (
                      <button key={item.id} onClick={() => setActiveSection(item.id)}
                        className={`flex items-center gap-2 px-3 py-2 rounded-lg text-xs transition-all text-left ${
                          activeSection === item.id
                            ? 'bg-primary-500 text-white shadow-lg shadow-primary-500/20'
                            : 'bg-white/5 text-gray-400 hover:bg-white/10 hover:text-white border border-white/5 hover:border-white/15'
                        }`}>
                        <span>{item.icon}</span>
                        <span className="truncate">{item.name}</span>
                      </button>
                    ))}
                  </div>
                </div>

                {/* System Status — environment + live contract counts */}
                <div className="glass rounded-xl p-6">
                  <h3 className="text-lg font-bold text-white mb-4">System Status</h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                    {([
                      { label: 'Environment',           value: isLocal ? 'Local Anvil' : 'Arbitrum Sepolia', ok: true },
                      { label: 'Chain ID',              value: String(chainId),                              ok: true },
                      { label: 'Core Contracts (13)',   value: 'Deployed',                                   ok: true },
                      { label: 'Phase 2A Contracts (7)',value: isLocal ? 'Deployed' : 'Not configured',      ok: isLocal },
                      { label: 'Phase 2C Contracts (4)',value: isLocal ? 'Deployed' : 'Not configured',      ok: isLocal },
                      { label: 'Phase 3 Contracts (7)', value: isLocal ? 'Deployed' : 'Not configured',      ok: isLocal },
                      { label: 'Phase 4 Contracts (2)', value: isLocal ? 'Deployed' : 'Not configured',      ok: isLocal },
                      { label: 'ZK Verifier',           value: 'Dev placeholder keys',                       ok: false },
                      { label: 'Pre-Alloc Validators',  value: `${String(preAllocValidators??0)} registered`, ok: true },
                      { label: 'ICF Active Loans',      value: String(icfActiveLoans??0),                    ok: true },
                      { label: 'Trade Agreements',      value: String(tradeAgreements??0),                    ok: true },
                      { label: 'AVS Coverage',          value: `${String(avsAssetCount??0)} assets · ${String(avsCountryCount??0)} countries`, ok: true },
                    ] as {label:string;value:string;ok:boolean}[]).map(({ label, value, ok }) => (
                      <div key={label} className="flex justify-between items-center p-3 bg-white/5 rounded-lg">
                        <span className="text-sm text-gray-400">{label}</span>
                        <span className={`text-sm font-medium flex items-center gap-1.5 ${ok ? 'text-green-400' : 'text-yellow-400'}`}>
                          <div className={`w-1.5 h-1.5 rounded-full animate-pulse ${ok ? 'bg-green-400' : 'bg-yellow-400'}`} />
                          {value}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}

            {activeSection === 'trading' && (
              <div className="space-y-6">
                <IchimokuChart currencyPair="OICD/USD" />
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  <DarkPoolOrderForm />
                  <CEXOrderBook />
                </div>
              </div>
            )}

            {activeSection === 'amm'            && <AMMDashboard />}
            {activeSection === 'treasury'       && <TreasuryDashboard />}
            {activeSection === 'bonds'          && <TwoDIBondManager />}
            {activeSection === 'banking'        && <FractionalReserveDashboard />}
            {activeSection === 'forex'          && <ForexReservesTracker />}
            {activeSection === 'prime'          && <PrimeBrokerageDashboard />}
            {activeSection === 'obsidian'       && <ObsidianCapitalDashboard />}
            {activeSection === 'laas'           && <LiquidityServiceDashboard />}
            {activeSection === 'governance'     && <GovernanceDashboard />}
            {activeSection === 'invites'        && <InviteManagerDashboard />}
            {activeSection === 'registry'       && <BlacklistRegistry />}
            {activeSection === 'lobby'          && <PublicLobby />}
            {activeSection === 'media'          && <MediaMonitor />}
            {activeSection === 'chat'           && <SecureChat />}
            {activeSection === 'gov-securities' && <GovernmentSecuritiesDashboard />}
            {activeSection === 'trade-blocks'   && <DigitalTradeBlocksDashboard />}
            {activeSection === 'parliament'     && <OZFParliamentDashboard />}
            {activeSection === 'arms'           && <ArmsComplianceDashboard />}
            {activeSection === 'infrastructure' && <InfrastructureAssetsDashboard />}
            {activeSection === 'sez'            && <SpecialEconomicZoneDashboard />}
            {activeSection === 'sovereign-dex'  && <SovereignDEXDashboard />}
            {activeSection === 'bond-auction'   && <BondAuctionDashboard />}
            {activeSection === 'broker-registry'&& <PublicBrokerDashboard />}
            {activeSection === 'hft-engine'     && <HFTEngineDashboard />}
            {activeSection === 'avs-platform'   && <AVSPlatformDashboard />}
            {activeSection === 'otd-token'      && <OTDTokenDashboard />}
            {activeSection === 'orion-score'    && <OrionScoreDashboard />}
            {activeSection === 'free-trade'     && <FreeTradeRegistryDashboard />}
            {activeSection === 'icf-lending'    && <ICFLendingDashboard />}
            {activeSection === 'pre-alloc'      && <PreAllocationDashboard />}
            {activeSection === 'jobs-board'     && <JobsBoardDashboard />}
            {activeSection === 'dtx'              && <DTXDashboard />}
            {activeSection === 'dcm-charter'      && <DCMCharter />}
            {activeSection === 'price-oracle'     && <PriceOracleDashboard />}
            {activeSection === 'exchange-trading' && <TradingTerminal />}
            {activeSection === 'odcm'             && <ODCMDashboard />}
            {activeSection === 'sgm-token'        && <SGMTokenDashboard />}
            {activeSection === 'sgmx-token'       && <SGMXTokenDashboard />}

          </main>
        </div>
      </div>

      {/* Floating chat */}
      {showChat && (
        <div className="fixed bottom-6 right-6 w-[800px] shadow-2xl z-50">
          <div className="flex items-center justify-between bg-gradient-to-r from-primary-500 to-purple-600 p-3 rounded-t-xl">
            <h3 className="text-white font-bold">Team Chat</h3>
            <button onClick={() => setShowChat(false)} className="text-white hover:bg-white/20 rounded-lg p-1 transition-all">
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          <ChatWindow />
        </div>
      )}

      <footer className="mt-16 border-t border-white/10 bg-white/5 backdrop-blur-xl">
        <div className="container mx-auto px-6 py-6 text-center">
          <p className="text-sm text-purple-400 font-semibold">OZHUMANILL ZAYED FEDERATION (OZF)</p>
          <p className="text-xs text-gray-500 mt-1">ShadowDapp Version 4.0 &copy; 2026 · 33 Contracts · 61 Currencies · 287 FX Corridors · 5 Bourse Centers</p>
        </div>
      </footer>
    </div>
  );
}
