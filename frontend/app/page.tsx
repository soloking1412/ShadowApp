'use client';

import { useState } from 'react';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import IchimokuChart from '@/components/trading/IchimokuChart';
import DarkPoolOrderForm from '@/components/trading/DarkPoolOrderForm';
import CEXOrderBook from '@/components/trading/CEXOrderBook';
import TreasuryDashboard from '@/components/treasury/TreasuryDashboard';
import TwoDIBondManager from '@/components/bonds/TwoDIBondManager';
import IBANBanking from '@/components/banking/IBANBanking';
import FractionalReserveDashboard from '@/components/banking/FractionalReserveDashboard';
import ForexReservesTracker from '@/components/forex/ForexReservesTracker';
import GovernanceDashboard from '@/components/dao/GovernanceDashboard';
import ChatWindow from '@/components/chat/ChatWindow';
import PublicLobby from '@/components/lobby/PublicLobby';
import MediaMonitor from '@/components/media/MediaMonitor';
import SecureChat from '@/components/chat/SecureChat';
import BlacklistRegistry from '@/components/registry/BlacklistRegistry';

type Section =
  | 'overview'
  | 'trading'
  | 'treasury'
  | 'bonds'
  | 'banking'
  | 'forex'
  | 'governance'
  | 'chat'
  | 'lobby'
  | 'media'
  | 'registry';

export default function Home() {
  const [activeSection, setActiveSection] = useState<Section>('overview');
  const [showChat, setShowChat] = useState(false);

  const navigation = [
    { id: 'overview' as Section, name: 'Overview', icon: '📊' },
    { id: 'trading' as Section, name: 'Trading', icon: '📈' },
    { id: 'treasury' as Section, name: 'Treasury', icon: '💰' },
    { id: 'bonds' as Section, name: '2DI Bonds', icon: '📜' },
    { id: 'banking' as Section, name: 'Banking', icon: '🏦' },
    { id: 'forex' as Section, name: 'Forex', icon: '💱' },
    { id: 'governance' as Section, name: 'Governance', icon: '🏛️' },
    { id: 'lobby' as Section, name: 'Public Lobby', icon: '🗣️' },
    { id: 'media' as Section, name: 'Media Monitor', icon: '📰' },
    { id: 'registry' as Section, name: 'OZF Registry', icon: '📋' },
    { id: 'chat' as Section, name: 'Secure Chat', icon: '💬' },
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-dark-900 via-dark-800 to-dark-900">
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
                <span className="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white text-xs font-bold rounded-full flex items-center justify-center">
                  3
                </span>
              </button>
              <ConnectButton />
            </div>
          </div>
        </div>
      </nav>

      <div className="container mx-auto px-6 py-8">
        <div className="flex gap-6">
          <aside className="w-64 flex-shrink-0">
            <div className="glass rounded-xl p-4 sticky top-24">
              <nav className="space-y-2">
                {navigation.map((item) => (
                  <button
                    key={item.id}
                    onClick={() => setActiveSection(item.id)}
                    className={`w-full text-left px-4 py-3 rounded-lg font-medium transition-all flex items-center gap-3 ${
                      activeSection === item.id
                        ? 'bg-primary-500 text-white'
                        : 'text-gray-300 hover:bg-white/5'
                    }`}
                  >
                    <span className="text-xl">{item.icon}</span>
                    {item.name}
                  </button>
                ))}
              </nav>
            </div>
          </aside>

          <main className="flex-1">
            {activeSection === 'overview' && (
              <div className="space-y-6">
                <div className="glass rounded-xl p-6">
                  <h2 className="text-3xl font-bold text-white mb-2">Welcome to ShadowDapp</h2>
                  <p className="text-gray-400 mb-6">
                    Decentralized infrastructure financing and sovereign investment platform
                  </p>

                  <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                    <div className="p-6 bg-gradient-to-br from-blue-500/20 to-blue-600/20 border border-blue-500/30 rounded-xl">
                      <div className="text-3xl mb-2">💰</div>
                      <p className="text-sm text-gray-400 mb-1">Deployed Contracts</p>
                      <p className="text-2xl font-bold text-white">6</p>
                    </div>
                    <div className="p-6 bg-gradient-to-br from-green-500/20 to-green-600/20 border border-green-500/30 rounded-xl">
                      <div className="text-3xl mb-2">🌍</div>
                      <p className="text-sm text-gray-400 mb-1">Supported Currencies</p>
                      <p className="text-2xl font-bold text-white">46</p>
                    </div>
                    <div className="p-6 bg-gradient-to-br from-purple-500/20 to-purple-600/20 border border-purple-500/30 rounded-xl">
                      <div className="text-3xl mb-2">📈</div>
                      <p className="text-sm text-gray-400 mb-1">Network</p>
                      <p className="text-2xl font-bold text-white">Arbitrum</p>
                    </div>
                    <div className="p-6 bg-gradient-to-br from-amber-500/20 to-amber-600/20 border border-amber-500/30 rounded-xl">
                      <div className="text-3xl mb-2">🏛️</div>
                      <p className="text-sm text-gray-400 mb-1">Testnet</p>
                      <p className="text-2xl font-bold text-white">Sepolia</p>
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  <div className="glass rounded-xl p-6">
                    <h3 className="text-xl font-bold text-white mb-4">Platform Features</h3>
                    <div className="space-y-3">
                      {[
                        { icon: '💱', title: 'Forex Reserves', desc: '45 currencies, $12.8T reserves' },
                        { icon: '📜', title: '2DI Bonds', desc: 'Infrastructure investment bonds' },
                        { icon: '🌑', title: 'Dark Pool', desc: 'Anonymous stealth trading' },
                        { icon: '🏦', title: 'IBAN Banking', desc: 'International bank transfers' },
                        { icon: '📊', title: 'Fractional Reserve', desc: '46 country holdings' },
                        { icon: '🏛️', title: 'DAO Governance', desc: '7 ministry voting system' },
                      ].map((feature, index) => (
                        <div key={index} className="flex items-center gap-3 p-3 bg-white/5 rounded-lg hover:bg-white/10 transition-all">
                          <div className="text-2xl">{feature.icon}</div>
                          <div>
                            <p className="font-semibold text-white">{feature.title}</p>
                            <p className="text-xs text-gray-400">{feature.desc}</p>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>

                  <div className="glass rounded-xl p-6">
                    <h3 className="text-xl font-bold text-white mb-4">Platform Status</h3>
                    <div className="space-y-4">
                      <div className="p-4 bg-white/5 rounded-lg">
                        <div className="flex justify-between items-center mb-2">
                          <span className="text-sm text-gray-400">Smart Contracts</span>
                          <span className="text-green-400 font-bold flex items-center gap-2">
                            <div className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
                            Deployed
                          </span>
                        </div>
                      </div>
                      <div className="p-4 bg-white/5 rounded-lg">
                        <div className="flex justify-between items-center mb-2">
                          <span className="text-sm text-gray-400">Network Status</span>
                          <span className="text-green-400 font-bold flex items-center gap-2">
                            <div className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
                            Online
                          </span>
                        </div>
                      </div>
                      <div className="p-4 bg-white/5 rounded-lg">
                        <div className="flex justify-between items-center mb-2">
                          <span className="text-sm text-gray-400">Chain ID</span>
                          <span className="text-white font-bold">421614</span>
                        </div>
                      </div>
                      <div className="p-4 bg-white/5 rounded-lg">
                        <div className="flex justify-between items-center mb-2">
                          <span className="text-sm text-gray-400">Environment</span>
                          <span className="text-blue-400 font-bold">Testnet</span>
                        </div>
                      </div>
                    </div>
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

            {activeSection === 'treasury' && <TreasuryDashboard />}

            {activeSection === 'bonds' && <TwoDIBondManager />}

            {activeSection === 'banking' && (
              <div className="space-y-6">
                <IBANBanking />
                <FractionalReserveDashboard />
              </div>
            )}

            {activeSection === 'forex' && <ForexReservesTracker />}

            {activeSection === 'governance' && <GovernanceDashboard />}

            {activeSection === 'lobby' && <PublicLobby />}

            {activeSection === 'media' && <MediaMonitor />}

            {activeSection === 'registry' && <BlacklistRegistry />}

            {activeSection === 'chat' && <SecureChat />}
          </main>
        </div>
      </div>

      {showChat && (
        <div className="fixed bottom-6 right-6 w-[800px] shadow-2xl z-50 animate-slide-in">
          <div className="flex items-center justify-between bg-gradient-to-r from-primary-500 to-purple-600 p-3 rounded-t-xl">
            <h3 className="text-white font-bold">Team Chat</h3>
            <button
              onClick={() => setShowChat(false)}
              className="text-white hover:bg-white/20 rounded-lg p-1 transition-all"
            >
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          <ChatWindow />
        </div>
      )}

      <footer className="mt-16 border-t border-white/10 bg-white/5 backdrop-blur-xl">
        <div className="container mx-auto px-6 py-8">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
            <div>
              <h4 className="text-white font-bold mb-3">ShadowDapp</h4>
              <p className="text-sm text-gray-400">
                Global financial infrastructure for sovereign investment and decentralized finance.
              </p>
            </div>
            <div>
              <h4 className="text-white font-bold mb-3">Platform</h4>
              <ul className="space-y-2 text-sm text-gray-400">
                <li>Trading</li>
                <li>Bonds</li>
                <li>Banking</li>
                <li>Governance</li>
              </ul>
            </div>
            <div>
              <h4 className="text-white font-bold mb-3">Resources</h4>
              <ul className="space-y-2 text-sm text-gray-400">
                <li>Documentation</li>
                <li>API</li>
                <li>Support</li>
                <li>Status</li>
              </ul>
            </div>
            <div>
              <h4 className="text-white font-bold mb-3">Network</h4>
              <p className="text-sm text-gray-400 mb-2">Deployed on Arbitrum</p>
              <div className="flex items-center gap-2 text-xs text-gray-400">
                <div className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
                Network Status: Online
              </div>
            </div>
          </div>
          <div className="mt-8 pt-8 border-t border-white/10 text-center">
            <p className="text-sm text-purple-400 font-semibold mb-1">OZHUMANILL ZAYED FEDERATION (OZF)</p>
            <p className="text-sm text-gray-400">© 2025 ShadowDapp. All rights reserved.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}
