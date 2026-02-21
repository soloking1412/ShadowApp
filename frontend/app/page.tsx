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
import AnvilDevTools from '@/components/devtools/AnvilDevTools';

type Section =
  | 'overview' | 'trading' | 'amm' | 'treasury' | 'bonds'
  | 'banking' | 'forex' | 'prime' | 'obsidian' | 'laas'
  | 'governance' | 'invites' | 'registry' | 'lobby' | 'media' | 'chat'
  | 'gov-securities' | 'trade-blocks' | 'parliament' | 'arms' | 'infrastructure' | 'sez'
  | 'sovereign-dex' | 'bond-auction' | 'broker-registry' | 'hft-engine'
  | 'avs-platform' | 'otd-token' | 'orion-score' | 'free-trade' | 'icf-lending' | 'pre-alloc' | 'jobs-board'
  | 'dtx' | 'dcm-charter' | 'price-oracle' | 'exchange-trading';

const chainId = parseInt(process.env.NEXT_PUBLIC_CHAIN_ID || '421614');
const isLocal = chainId === 31337;

export default function Home() {
  const [activeSection, setActiveSection] = useState<Section>('overview');
  const [showChat, setShowChat] = useState(false);

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
    // Governance & Comms
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
    { id: 'exchange-trading', name: 'Exchange Trading',    icon: '📈', group: 'Finance'    },
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

            {activeSection === 'overview' && (
              <div className="space-y-6">
                {isLocal && <AnvilDevTools />}
                <div className="glass rounded-xl p-6">
                  <h2 className="text-3xl font-bold text-white mb-1">ShadowDapp</h2>
                  <p className="text-gray-400 text-sm mb-1">Version 1.0 / 2.0 — Sovereign investment & decentralized finance · 35 contracts · 18 global exchanges</p>
                  <p className="text-xs text-purple-400 mb-6">OZHUMANILL ZAYED FEDERATION (OZF)</p>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                    {[
                      { icon: '📜', label: 'Contracts', value: '35' },
                      { icon: '🌍', label: 'Currencies', value: '61' },
                      { icon: '🏦', label: 'Countries', value: '46' },
                      { icon: '⛓️', label: 'Chain', value: isLocal ? 'Anvil 31337' : 'Arb Sepolia' },
                    ].map(({ icon, label, value }) => (
                      <div key={label} className="p-5 bg-white/5 border border-white/10 rounded-xl">
                        <div className="text-2xl mb-2">{icon}</div>
                        <p className="text-xs text-gray-400 mb-1">{label}</p>
                        <p className="text-2xl font-bold text-white">{value}</p>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  <div className="glass rounded-xl p-6">
                    <h3 className="text-lg font-bold text-white mb-4">Version 1.0 — Core (Deployed)</h3>
                    <div className="space-y-2">
                      {[
                        { icon: '💰', name: 'OICDTreasury',              desc: '61-currency ERC1155 treasury' },
                        { icon: '🏦', name: 'Fractional Reserve Banking', desc: 'IBAN banking, 46 countries' },
                        { icon: '🔄', name: 'UniversalAMM',              desc: 'Constant-product token swaps' },
                        { icon: '🔐', name: 'InviteManager',             desc: 'Gated access via invite codes' },
                        { icon: '📋', name: 'OGRBlacklist',              desc: 'Compliance blacklist registry' },
                        { icon: '🌑', name: 'DarkPool',                  desc: 'Anonymous ZK-SNARK trading' },
                        { icon: '💧', name: 'LaaS',                      desc: 'Liquidity-as-a-Service pools' },
                        { icon: '💎', name: 'Obsidian Capital',          desc: 'Multi-strategy hedge fund' },
                        { icon: '📜', name: '2DI Bond Tracker',          desc: 'Infrastructure bond ERC1155' },
                        { icon: '🏛️', name: 'Prime Brokerage',           desc: 'Institutional margin services' },
                        { icon: '⚖️', name: 'Sovereign DAO',             desc: 'Ministry governance system' },
                        { icon: '💱', name: 'Forex Reserves',            desc: '287-corridor FX tracking' },
                      ].map(({ icon, name, desc }) => (
                        <div key={name} className="flex items-center gap-3 p-2.5 bg-white/5 rounded-lg">
                          <span>{icon}</span>
                          <div>
                            <p className="text-sm font-medium text-white">{name}</p>
                            <p className="text-xs text-gray-500">{desc}</p>
                          </div>
                          <span className="ml-auto text-xs text-green-400">✓ Live</span>
                        </div>
                      ))}
                    </div>
                  </div>

                  <div className="glass rounded-xl p-6">
                    <h3 className="text-lg font-bold text-white mb-4">Version 2.0 — Expansion</h3>

                    <div className="space-y-2">
                      {[
                        { icon: '🏛', name: 'Gov Securities Settlement', desc: 'Municipal, sovereign, corporate bonds', deployed: true },
                        { icon: '🧱', name: 'Digital Trade Blocks',      desc: 'Tokenized trade finance NFTs', deployed: true },
                        { icon: '🌐', name: 'OZF Parliament',            desc: 'Inter-governmental assembly', deployed: true },
                        { icon: '🛡️', name: 'Arms Trade Compliance',     desc: 'ITAR/EAR export license system', deployed: true },
                        { icon: '🚢', name: 'Infrastructure Assets',     desc: 'Ports, corridors, freight tracking', deployed: true },
                        { icon: '🏙️', name: 'Special Economic Zones',    desc: 'Co-managed sovereign SEZs', deployed: true },
                        { icon: '🔮', name: 'Price Oracle Aggregator',   desc: 'Chainlink + Pyth price feeds', deployed: true },
                        { icon: '⚡', name: 'HFT Engine (GLTE)',         desc: 'High-frequency GLTE trading', deployed: true },
                        { icon: '🔀', name: 'Sovereign DEX',             desc: 'Atomic FX swap engine', deployed: true },
                        { icon: '🏷️', name: 'Bond Auction House',        desc: 'Dutch & sealed-bid auctions', deployed: true },
                        { icon: '👥', name: 'Public Broker Registry',    desc: 'On-chain broker onboarding', deployed: true },
                        { icon: '🌍', name: 'AVS Platform',              desc: 'Asset Value Securitization', deployed: true },
                        { icon: '🪙', name: 'OTD Token',                 desc: '500 Octillion supply ERC20 governance', deployed: true },
                        { icon: '🔮', name: 'Orion Score',               desc: '9-variable LIFO sovereign rating', deployed: true },
                        { icon: '🤝', name: 'Free Trade Registry',       desc: 'WTO/OZF bilateral agreements', deployed: true },
                        { icon: '🏗️', name: 'ICF Lending',               desc: '4 loan programs (ICF, First90, FFE)', deployed: true },
                        { icon: '📦', name: 'Pre-Allocation',            desc: 'Validator/shareholder compound schedule', deployed: true },
                        { icon: '💼', name: 'Jobs Board',                desc: 'OICD employment marketplace (8 levels)', deployed: true },
                        { icon: '🏦', name: 'DTX Bourse',               desc: '5-center global exchange (Alpha→Echo)',   deployed: true },
                        { icon: '📐', name: 'DCM Market Charter',        desc: '4-pillar health scoring (400/400)',       deployed: true },
                        { icon: '📡', name: 'Price Oracle Dashboard',    desc: 'Chainlink + Pyth + OZF relayer feeds',   deployed: true },
                        { icon: '📈', name: 'Global Exchange Trading',   desc: '18 exchanges · NYSE, LSE, B3, NSE, Tadawul', deployed: true },
                      ].map(({ icon, name, desc, deployed }) => (
                        <div key={name} className="flex items-center gap-3 p-2.5 bg-white/5 rounded-lg">
                          <span>{icon}</span>
                          <div>
                            <p className="text-sm font-medium text-white">{name}</p>
                            <p className="text-xs text-gray-500">{desc}</p>
                          </div>
                          <span className={`ml-auto text-xs ${deployed ? 'text-blue-400' : 'text-amber-400'}`}>
                            {deployed ? '✓ Deployed' : '⏳ Pending'}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>

                <div className="glass rounded-xl p-6">
                  <h3 className="text-lg font-bold text-white mb-4">System Status</h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                    {[
                      { label: 'Environment',          value: isLocal ? 'Local Anvil' : 'Arbitrum Sepolia', ok: true },
                      { label: 'Chain ID',             value: String(chainId),                              ok: true },
                      { label: 'Core Contracts (13)',    value: 'Deployed',                                   ok: true },
                      { label: 'Phase 2A Contracts (7)', value: isLocal ? 'Deployed' : 'Not yet',           ok: isLocal },
                      { label: 'Phase 2C Contracts (4)', value: isLocal ? 'Deployed' : 'Not yet',           ok: isLocal },
                      { label: 'Phase 3 Contracts (7)',  value: isLocal ? 'Deployed' : 'Not yet',           ok: isLocal },
                      { label: 'Phase 4 Contracts (2)',  value: isLocal ? 'Deployed' : 'Not yet',           ok: isLocal },
                      { label: 'ZK Verifier',            value: 'Dev placeholder keys',                     ok: false },
                      { label: 'Price Oracle',           value: isLocal ? 'Local mode' : 'Not yet',         ok: isLocal },
                      { label: 'HFT Engine (GLTE)',      value: 'Live',                                     ok: true },
                    ].map(({ label, value, ok }) => (
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
            {activeSection === 'exchange-trading' && <GlobalExchangeTrading />}

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
          <p className="text-xs text-gray-500 mt-1">ShadowDapp Version 4.0 &copy; 2025 · 35 Contracts · 61 Currencies · 287 FX Corridors · 18 Global Exchanges</p>
        </div>
      </footer>
    </div>
  );
}
