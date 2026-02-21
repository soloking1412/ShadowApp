'use client';
import { useState } from 'react';
import { useAccount } from 'wagmi';

interface Exchange {
  id: string;
  name: string;
  country: string;
  flag: string;
  region: string;
  currency: string;
  index: string;
  indexValue: string;
  change: string;
  volume: string;
  status: 'open' | 'closed' | 'pre';
  mic: string;  // Market Identifier Code
}

const EXCHANGES: Exchange[] = [
  { id: 'nyse',     name: 'NYSE',           country: 'United States', flag: '🇺🇸', region: 'Americas', currency: 'USD', index: 'NYSE Composite', indexValue: '18,244.32', change: '+0.42%', volume: '$24.8B', status: 'open',   mic: 'XNYS' },
  { id: 'nasdaq',   name: 'NASDAQ',         country: 'United States', flag: '🇺🇸', region: 'Americas', currency: 'USD', index: 'NASDAQ Composite', indexValue: '16,412.71', change: '+0.87%', volume: '$18.3B', status: 'open',   mic: 'XNAS' },
  { id: 'lse',      name: 'LSE',            country: 'United Kingdom', flag: '🇬🇧', region: 'Europe',  currency: 'GBP', index: 'FTSE 100',        indexValue: '8,012.45',  change: '-0.18%', volume: '£6.2B',  status: 'closed', mic: 'XLON' },
  { id: 'euronext', name: 'Euronext',       country: 'EU',            flag: '🇪🇺', region: 'Europe',  currency: 'EUR', index: 'CAC 40',          indexValue: '7,893.20',  change: '+0.31%', volume: '€9.1B',  status: 'closed', mic: 'XPAR' },
  { id: 'db',       name: 'Deutsche Börse', country: 'Germany',       flag: '🇩🇪', region: 'Europe',  currency: 'EUR', index: 'DAX',             indexValue: '18,312.88', change: '+0.55%', volume: '€7.4B',  status: 'closed', mic: 'XFRA' },
  { id: 'tsx',      name: 'TSX',            country: 'Canada',        flag: '🇨🇦', region: 'Americas', currency: 'CAD', index: 'S&P/TSX Composite', indexValue: '22,134.10', change: '+0.22%', volume: 'C$4.8B', status: 'open',   mic: 'XTSE' },
  { id: 'b3',       name: 'B3 (Brazil)',    country: 'Brazil',        flag: '🇧🇷', region: 'Americas', currency: 'BRL', index: 'IBOVESPA',        indexValue: '128,445.0', change: '-0.44%', volume: 'R$28.1B', status: 'open',  mic: 'BVMF' },
  { id: 'jse',      name: 'JSE',            country: 'South Africa',  flag: '🇿🇦', region: 'Africa',  currency: 'ZAR', index: 'JSE Top 40',      indexValue: '74,832.5',  change: '+0.67%', volume: 'R14.2B', status: 'closed', mic: 'XJSE' },
  { id: 'nse',      name: 'NSE India',      country: 'India',         flag: '🇮🇳', region: 'Asia',    currency: 'INR', index: 'NIFTY 50',        indexValue: '22,513.70', change: '+0.93%', volume: '₹412B',  status: 'closed', mic: 'XNSE' },
  { id: 'bse',      name: 'BSE Mumbai',     country: 'India',         flag: '🇮🇳', region: 'Asia',    currency: 'INR', index: 'SENSEX',          indexValue: '74,119.83', change: '+0.88%', volume: '₹189B',  status: 'closed', mic: 'XBOM' },
  { id: 'hkex',     name: 'HKEX',           country: 'Hong Kong',     flag: '🇭🇰', region: 'Asia',    currency: 'HKD', index: 'Hang Seng',       indexValue: '17,012.35', change: '-1.22%', volume: 'HK$82B', status: 'open',   mic: 'XHKG' },
  { id: 'sgx',      name: 'SGX',            country: 'Singapore',     flag: '🇸🇬', region: 'Asia',    currency: 'SGD', index: 'STI',             indexValue: '3,212.88',  change: '+0.14%', volume: 'S$1.8B', status: 'open',   mic: 'XSES' },
  { id: 'asx',      name: 'ASX',            country: 'Australia',     flag: '🇦🇺', region: 'Asia',    currency: 'AUD', index: 'S&P/ASX 200',    indexValue: '7,812.44',  change: '+0.37%', volume: 'A$6.4B', status: 'open',   mic: 'XASX' },
  { id: 'tadawul',  name: 'Tadawul (Saudi)', country: 'Saudi Arabia', flag: '🇸🇦', region: 'MENA',   currency: 'SAR', index: 'TASI',            indexValue: '12,304.18', change: '+0.21%', volume: '₨8.9B',  status: 'open',   mic: 'XSAU' },
  { id: 'tirana',   name: 'Tirana SE',      country: 'Albania',       flag: '🇦🇱', region: 'Europe',  currency: 'ALL', index: 'ALSE',            indexValue: '1,842.70',  change: '+0.08%', volume: 'L312M',  status: 'closed', mic: 'XTIR' },
  { id: 'bursa',    name: 'Bursa Malaysia', country: 'Malaysia',      flag: '🇲🇾', region: 'Asia',    currency: 'MYR', index: 'KLCI',            indexValue: '1,512.33',  change: '+0.45%', volume: 'RM2.8B', status: 'open',   mic: 'XKLS' },
  { id: 'bist',     name: 'Borsa Istanbul', country: 'Turkey',        flag: '🇹🇷', region: 'Europe',  currency: 'TRY', index: 'BIST 100',        indexValue: '10,212.81', change: '+1.32%', volume: '₺48.2B', status: 'closed', mic: 'XIST' },
  { id: 'krx',      name: 'KRX',            country: 'South Korea',   flag: '🇰🇷', region: 'Asia',    currency: 'KRW', index: 'KOSPI',           indexValue: '2,631.44',  change: '+0.62%', volume: '₩9.8T',  status: 'open',   mic: 'XKRX' },
];

const ASSET_CLASSES = ['Equities', 'Government Bonds', 'Corporate Bonds', 'Commodities', 'FX Derivatives', 'ETFs'];
const ORDER_TYPES   = ['Market', 'Limit', 'Stop-Loss', 'Stop-Limit', 'MOC', 'LOC'];
const REGIONS       = ['All', 'Americas', 'Europe', 'Asia', 'MENA', 'Africa'];

interface Position {
  exchange: string;
  ticker: string;
  side: 'BUY' | 'SELL';
  qty: number;
  price: number;
  pnl: number;
  currency: string;
}

const SEED_POSITIONS: Position[] = [
  { exchange: 'NYSE',    ticker: 'SPY',   side: 'BUY',  qty: 500,   price: 521.48, pnl:  14_220, currency: 'USD' },
  { exchange: 'LSE',     ticker: 'SHEL',  side: 'BUY',  qty: 2000,  price: 26.32,  pnl:   3_840, currency: 'GBP' },
  { exchange: 'B3',      ticker: 'PETR4', side: 'BUY',  qty: 10000, price: 38.12,  pnl:  -9_200, currency: 'BRL' },
  { exchange: 'NSE',     ticker: 'RELIANCE', side: 'BUY', qty: 300, price: 2_891.5, pnl: 82_140, currency: 'INR' },
  { exchange: 'Tadawul', ticker: '2222',  side: 'BUY',  qty: 1000,  price: 29.70,  pnl:   5_340, currency: 'SAR' },
];

export default function GlobalExchangeTrading() {
  const { isConnected } = useAccount();
  const [selectedRegion, setSelectedRegion] = useState('All');
  const [selectedExchange, setSelectedExchange] = useState<Exchange | null>(null);
  const [tab, setTab] = useState<'exchanges' | 'trade' | 'positions' | 'analytics'>('exchanges');
  const [positions] = useState<Position[]>(SEED_POSITIONS);

  // Trade form state
  const [orderExchange, setOrderExchange] = useState('NYSE');
  const [ticker, setTicker] = useState('');
  const [assetClass, setAssetClass] = useState(ASSET_CLASSES[0]);
  const [orderType, setOrderType] = useState(ORDER_TYPES[0]);
  const [side, setSide] = useState<'BUY' | 'SELL'>('BUY');
  const [qty, setQty] = useState('');
  const [price, setPrice] = useState('');
  const [orderPlaced, setOrderPlaced] = useState(false);

  const filtered = selectedRegion === 'All' ? EXCHANGES : EXCHANGES.filter(e => e.region === selectedRegion);

  const totalPnL = positions.reduce((s, p) => s + p.pnl, 0);
  const openPnL  = positions.filter(p => p.pnl > 0).reduce((s, p) => s + p.pnl, 0);

  const tc = (a: boolean) =>
    a ? 'px-4 py-2 rounded-t text-sm font-medium bg-emerald-600 text-white'
      : 'px-4 py-2 rounded-t text-sm font-medium text-gray-400 hover:text-white';

  const TABS = [
    { id: 'exchanges', label: 'Exchanges' },
    { id: 'trade',     label: 'Place Order' },
    { id: 'positions', label: `Positions (${positions.length})` },
    { id: 'analytics', label: 'Analytics' },
  ] as const;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Global Exchange Trading</h2>
        <p className="text-gray-400 mt-1 text-sm">
          Access {EXCHANGES.length} global exchanges · NYSE · LSE · B3 · NSE · Tadawul · Tirana and more
        </p>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 flex-wrap border-b border-white/10 pb-2">
        {TABS.map(t => <button key={t.id} onClick={() => setTab(t.id)} className={tc(tab === t.id)}>{t.label}</button>)}
      </div>

      {/* Exchange Directory */}
      {tab === 'exchanges' && (
        <div className="space-y-4">
          {/* Region filter */}
          <div className="flex gap-2 flex-wrap">
            {REGIONS.map(r => (
              <button
                key={r}
                onClick={() => setSelectedRegion(r)}
                className={`px-3 py-1 rounded-full text-sm transition-all ${
                  selectedRegion === r
                    ? 'bg-emerald-600 text-white'
                    : 'bg-white/10 text-gray-400 hover:text-white'
                }`}
              >
                {r}
              </button>
            ))}
          </div>

          {/* Exchange grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {filtered.map(ex => (
              <button
                key={ex.id}
                onClick={() => { setSelectedExchange(ex); setOrderExchange(ex.name); setTab('trade'); }}
                className="bg-white/5 hover:bg-white/10 rounded-xl p-4 text-left transition-all border border-white/5 hover:border-emerald-500/30"
              >
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <span className="text-xl">{ex.flag}</span>
                    <div>
                      <p className="text-white font-semibold text-sm">{ex.name}</p>
                      <p className="text-gray-500 text-xs">{ex.mic}</p>
                    </div>
                  </div>
                  <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                    ex.status === 'open'   ? 'bg-green-500/20 text-green-400' :
                    ex.status === 'pre'    ? 'bg-yellow-500/20 text-yellow-400' :
                                             'bg-gray-500/20 text-gray-400'
                  }`}>
                    {ex.status === 'open' ? '● Open' : ex.status === 'pre' ? '◐ Pre' : '○ Closed'}
                  </span>
                </div>
                <div className="space-y-1">
                  <div className="flex justify-between">
                    <span className="text-xs text-gray-500">{ex.index}</span>
                  </div>
                  <div className="flex justify-between items-baseline">
                    <span className="text-lg font-bold text-white">{ex.indexValue}</span>
                    <span className={`text-sm font-semibold ${ex.change.startsWith('+') ? 'text-green-400' : 'text-red-400'}`}>
                      {ex.change}
                    </span>
                  </div>
                  <div className="flex justify-between mt-2 pt-2 border-t border-white/5">
                    <span className="text-xs text-gray-500">Volume</span>
                    <span className="text-xs text-gray-300">{ex.volume}</span>
                  </div>
                </div>
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Place Order */}
      {tab === 'trade' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="bg-white/5 rounded-xl p-5 space-y-4">
            <h3 className="text-white font-semibold">New Order</h3>
            {!isConnected && (
              <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-3 text-xs text-yellow-400">
                Connect wallet to place orders (settlement via ObsidianCapital)
              </div>
            )}

            <div>
              <label className="text-xs text-gray-400 mb-1 block">Exchange</label>
              <select className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm"
                value={orderExchange} onChange={e => setOrderExchange(e.target.value)}>
                {EXCHANGES.map(ex => <option key={ex.id} value={ex.name}>{ex.flag} {ex.name}</option>)}
              </select>
            </div>

            <div>
              <label className="text-xs text-gray-400 mb-1 block">Asset Class</label>
              <select className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm"
                value={assetClass} onChange={e => setAssetClass(e.target.value)}>
                {ASSET_CLASSES.map(a => <option key={a}>{a}</option>)}
              </select>
            </div>

            <div>
              <label className="text-xs text-gray-400 mb-1 block">Ticker / ISIN</label>
              <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500"
                placeholder="e.g. SPY, MSFT, US912810TM56"
                value={ticker} onChange={e => setTicker(e.target.value.toUpperCase())} />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs text-gray-400 mb-1 block">Order Type</label>
                <select className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm"
                  value={orderType} onChange={e => setOrderType(e.target.value)}>
                  {ORDER_TYPES.map(o => <option key={o}>{o}</option>)}
                </select>
              </div>
              <div>
                <label className="text-xs text-gray-400 mb-1 block">Side</label>
                <div className="flex rounded overflow-hidden border border-white/10">
                  <button onClick={() => setSide('BUY')}
                    className={`flex-1 py-2 text-sm font-semibold transition-all ${side === 'BUY' ? 'bg-green-600 text-white' : 'bg-white/5 text-gray-400'}`}>
                    BUY
                  </button>
                  <button onClick={() => setSide('SELL')}
                    className={`flex-1 py-2 text-sm font-semibold transition-all ${side === 'SELL' ? 'bg-red-600 text-white' : 'bg-white/5 text-gray-400'}`}>
                    SELL
                  </button>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs text-gray-400 mb-1 block">Quantity</label>
                <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500"
                  placeholder="Units" value={qty} onChange={e => setQty(e.target.value)} type="number" min="0" />
              </div>
              {orderType !== 'Market' && orderType !== 'MOC' && (
                <div>
                  <label className="text-xs text-gray-400 mb-1 block">Limit Price</label>
                  <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500"
                    placeholder="0.00" value={price} onChange={e => setPrice(e.target.value)} type="number" min="0" step="0.01" />
                </div>
              )}
            </div>

            <button
              onClick={() => { setOrderPlaced(true); setTimeout(() => setOrderPlaced(false), 3000); }}
              disabled={!isConnected || !ticker || !qty}
              className={`w-full py-2.5 rounded text-sm font-bold transition-all ${
                side === 'BUY'
                  ? 'bg-green-600 hover:bg-green-700 disabled:opacity-50 text-white'
                  : 'bg-red-600 hover:bg-red-700 disabled:opacity-50 text-white'
              }`}
            >
              {orderPlaced ? '✓ Order Submitted' : `${side} ${ticker || '—'} on ${orderExchange}`}
            </button>

            <p className="text-xs text-gray-500 text-center">
              Orders routed via Bloomberg Terminal API · Cash leg settled via FractionalReserveBanking SWIFT
            </p>
          </div>

          {/* Order book simulation */}
          <div className="bg-white/5 rounded-xl p-5">
            <h3 className="text-white font-semibold mb-4">
              {selectedExchange ? `${selectedExchange.flag} ${selectedExchange.name} — ${selectedExchange.index}` : 'Select an Exchange'}
            </h3>
            {selectedExchange ? (
              <div className="space-y-4">
                <div className="grid grid-cols-2 gap-3">
                  <div className="bg-green-500/10 rounded-lg p-3 text-center">
                    <p className="text-xs text-gray-400 mb-1">Index Value</p>
                    <p className="text-xl font-bold text-green-400">{selectedExchange.indexValue}</p>
                    <p className="text-xs text-green-400 mt-1">{selectedExchange.change}</p>
                  </div>
                  <div className="bg-white/5 rounded-lg p-3 text-center">
                    <p className="text-xs text-gray-400 mb-1">Volume</p>
                    <p className="text-xl font-bold text-white">{selectedExchange.volume}</p>
                    <p className="text-xs text-gray-500 mt-1">{selectedExchange.currency}</p>
                  </div>
                </div>

                {/* Simulated order book */}
                <div>
                  <p className="text-xs text-gray-500 font-semibold mb-2">Order Book (simulated)</p>
                  <div className="space-y-0.5">
                    {[0.15, 0.12, 0.09, 0.06, 0.03].map((d, i) => {
                      const base = parseFloat(selectedExchange.indexValue.replace(/,/g, ''));
                      return (
                        <div key={i} className="flex items-center gap-2 text-xs">
                          <span className="text-red-400 w-20 text-right font-mono">{(base * (1 + d / 100)).toLocaleString('en', { maximumFractionDigits: 2 })}</span>
                          <div className="flex-1 h-3 bg-red-500/20 rounded" style={{ width: `${(5 - i) * 20}%` }} />
                        </div>
                      );
                    })}
                    <div className="flex items-center gap-2 text-sm font-bold py-1 border-y border-white/10">
                      <span className="text-white w-20 text-right font-mono">{selectedExchange.indexValue}</span>
                      <span className={`text-xs ml-2 ${selectedExchange.change.startsWith('+') ? 'text-green-400' : 'text-red-400'}`}>{selectedExchange.change}</span>
                    </div>
                    {[0.03, 0.06, 0.09, 0.12, 0.15].map((d, i) => {
                      const base = parseFloat(selectedExchange.indexValue.replace(/,/g, ''));
                      return (
                        <div key={i} className="flex items-center gap-2 text-xs">
                          <span className="text-green-400 w-20 text-right font-mono">{(base * (1 - d / 100)).toLocaleString('en', { maximumFractionDigits: 2 })}</span>
                          <div className="flex-1 h-3 bg-green-500/20 rounded" style={{ width: `${(i + 1) * 20}%` }} />
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>
            ) : (
              <div className="flex items-center justify-center h-48 text-gray-500">
                <div className="text-center">
                  <p className="text-4xl mb-3">🌐</p>
                  <p className="text-sm">Click an exchange from the directory</p>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Positions */}
      {tab === 'positions' && (
        <div className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {[
              { label: 'Open Positions', value: String(positions.length), color: 'text-white' },
              { label: 'Total P&L',      value: `${totalPnL >= 0 ? '+' : ''}${totalPnL.toLocaleString()}`, color: totalPnL >= 0 ? 'text-green-400' : 'text-red-400' },
              { label: 'Winning Pos.',   value: String(positions.filter(p => p.pnl > 0).length), color: 'text-green-400' },
            ].map(s => (
              <div key={s.label} className="bg-white/5 rounded-xl p-4">
                <p className="text-xs text-gray-400 mb-1">{s.label}</p>
                <p className={`text-2xl font-bold ${s.color}`}>{s.value}</p>
              </div>
            ))}
          </div>

          <div className="bg-white/5 rounded-xl overflow-hidden">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-white/10">
                  <th className="text-left px-4 py-3 text-gray-400 font-medium text-xs">Exchange</th>
                  <th className="text-left px-4 py-3 text-gray-400 font-medium text-xs">Ticker</th>
                  <th className="text-left px-4 py-3 text-gray-400 font-medium text-xs">Side</th>
                  <th className="text-right px-4 py-3 text-gray-400 font-medium text-xs">Qty</th>
                  <th className="text-right px-4 py-3 text-gray-400 font-medium text-xs">Avg Price</th>
                  <th className="text-right px-4 py-3 text-gray-400 font-medium text-xs">P&L</th>
                </tr>
              </thead>
              <tbody>
                {positions.map((p, i) => (
                  <tr key={i} className="border-b border-white/5 hover:bg-white/5">
                    <td className="px-4 py-3 text-gray-300">{p.exchange}</td>
                    <td className="px-4 py-3 text-white font-mono font-semibold">{p.ticker}</td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-0.5 rounded text-xs font-bold ${p.side === 'BUY' ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'}`}>
                        {p.side}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-right text-gray-300">{p.qty.toLocaleString()}</td>
                    <td className="px-4 py-3 text-right text-gray-300 font-mono">{p.price.toLocaleString()}</td>
                    <td className={`px-4 py-3 text-right font-semibold ${p.pnl >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                      {p.pnl >= 0 ? '+' : ''}{p.pnl.toLocaleString()} {p.currency}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <p className="text-xs text-gray-500 text-center">
            Positions tracked via ObsidianCapital contract · P&L settled on-chain · Cash leg via FractionalReserveBanking SWIFT
          </p>
        </div>
      )}

      {/* Analytics */}
      {tab === 'analytics' && (
        <div className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Region exposure */}
            <div className="bg-white/5 rounded-xl p-5">
              <h3 className="text-white font-semibold mb-4">Exchange Coverage by Region</h3>
              <div className="space-y-3">
                {[
                  { region: 'Americas',  count: 3, pct: 17, color: 'bg-blue-500' },
                  { region: 'Europe',    count: 5, pct: 28, color: 'bg-purple-500' },
                  { region: 'Asia',      count: 7, pct: 39, color: 'bg-green-500' },
                  { region: 'MENA',      count: 2, pct: 11, color: 'bg-yellow-500' },
                  { region: 'Africa',    count: 1, pct: 5,  color: 'bg-orange-500' },
                ].map(r => (
                  <div key={r.region}>
                    <div className="flex justify-between text-sm mb-1">
                      <span className="text-gray-300">{r.region}</span>
                      <span className="text-gray-400">{r.count} exchanges · {r.pct}%</span>
                    </div>
                    <div className="h-2 bg-white/5 rounded-full overflow-hidden">
                      <div className={`h-full ${r.color} rounded-full`} style={{ width: `${r.pct}%` }} />
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* GLTE integration */}
            <div className="bg-white/5 rounded-xl p-5">
              <h3 className="text-white font-semibold mb-4">GLTE Integration Status</h3>
              <div className="space-y-3">
                {[
                  { label: 'Bloomberg Terminal API',   status: 'Phase 2C', color: 'text-yellow-400' },
                  { label: 'Reuters Eikon Integration', status: 'Phase 2C', color: 'text-yellow-400' },
                  { label: 'Exchange Adapter (OICD)',   status: 'Phase 2A',  color: 'text-yellow-400' },
                  { label: 'On-chain P&L Settlement',  status: 'Live',     color: 'text-green-400'  },
                  { label: 'SWIFT Cash Leg Settlement', status: 'Phase 2A',  color: 'text-yellow-400' },
                  { label: 'ObsidianCapital Reporting', status: 'Live',     color: 'text-green-400'  },
                ].map(item => (
                  <div key={item.label} className="flex justify-between items-center py-1.5 border-b border-white/5">
                    <span className="text-sm text-gray-300">{item.label}</span>
                    <span className={`text-xs font-semibold ${item.color}`}>{item.status}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Revenue model */}
          <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-xl p-5">
            <p className="text-emerald-300 font-semibold mb-3">Revenue Model — Exchange Trading</p>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
              <div>
                <p className="text-gray-400 text-xs mb-1">Commission Markup</p>
                <p className="text-white font-bold">5 bps per trade</p>
                <p className="text-gray-500 text-xs">On top of exchange fee</p>
              </div>
              <div>
                <p className="text-gray-400 text-xs mb-1">HFT Engine Arb</p>
                <p className="text-white font-bold">GLTE delta capture</p>
                <p className="text-gray-500 text-xs">Yield differential across 197 markets</p>
              </div>
              <div>
                <p className="text-gray-400 text-xs mb-1">P&L Settlement</p>
                <p className="text-white font-bold">OICD + SWIFT</p>
                <p className="text-gray-500 text-xs">Crypto or fiat wire payout</p>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
