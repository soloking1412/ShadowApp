'use client';

import { useState, useEffect, useRef, useMemo } from 'react';
import { createChart, ColorType, IChartApi, ISeriesApi, CandlestickData, LineData, HistogramData, Time } from 'lightweight-charts';
import { useAccount } from 'wagmi';

// ─── Types ─────────────────────────────────────────────────────────────────────

interface WatchlistItem {
  symbol: string;
  fullName: string;
  price: number;
  change: number;
  changePct: number;
  bid: number;
  ask: number;
  category: 'oicd' | 'crypto' | 'fx' | 'commodity' | 'index';
}

interface BookLevel {
  price: number;
  size: number;
  total: number;
  depth: number;
}

interface RecentTrade {
  id: number;
  price: number;
  size: number;
  side: 'buy' | 'sell';
  time: string;
  exchange: string;
}

interface AISignal {
  sentiment: 'Bullish' | 'Bearish' | 'Neutral';
  sentimentScore: number;
  rsi: number;
  trend: 'Up' | 'Down' | 'Sideways';
  pegHealth: 'Healthy' | 'Warning' | 'Critical';
  recommendation: 'Strong Buy' | 'Buy' | 'Hold' | 'Sell' | 'Strong Sell';
  confidence: number;
  supports: number[];
  resistances: number[];
  commentary: string;
}

interface OICDMetrics {
  pegValue: number;
  glu: number;
  rtabr: number;
  gdi: number;
  fxVol: number;
  cpeg: number;
  supplyController: 'Mint' | 'Burn' | 'Neutral';
  totalSupply: number;
}

type TabType = 'chart' | 'orders' | 'heatmap' | 'ai';
type OrderType = 'market' | 'limit' | 'stop' | 'stop-limit';
type BookView = 'book' | 'trades' | 'depth';

interface GLTESignal {
  lOut: number;
  direction: 'Up' | 'Down' | 'Sideways';
  strength: number;
  bTirana: number;
  fTadawul: number;
  vixOil: number;
}

// ─── Pair Definitions ──────────────────────────────────────────────────────────

const PAIRS = [
  { symbol: 'OICD/USD', base: 1.0000, vol: 0.0012, category: 'oicd', fullName: 'OICD Stablecoin', tick: 0.0001, prec: 4 },
  { symbol: 'OTD/USD',  base: 0.0000085, vol: 0.0000003, category: 'oicd', fullName: 'OTD Token', tick: 0.0000001, prec: 7 },
  { symbol: 'BTC/USD',  base: 62540, vol: 320, category: 'crypto', fullName: 'Bitcoin', tick: 0.5, prec: 2 },
  { symbol: 'ETH/USD',  base: 2855,  vol: 28,  category: 'crypto', fullName: 'Ethereum', tick: 0.05, prec: 2 },
  { symbol: 'SOL/USD',  base: 145.5, vol: 2.2, category: 'crypto', fullName: 'Solana', tick: 0.01, prec: 2 },
  { symbol: 'BNB/USD',  base: 421.0, vol: 4.5, category: 'crypto', fullName: 'BNB Chain', tick: 0.01, prec: 2 },
  { symbol: 'LINK/USD', base: 18.45, vol: 0.35, category: 'crypto', fullName: 'Chainlink', tick: 0.01, prec: 3 },
  { symbol: 'EUR/USD',  base: 1.0847, vol: 0.0010, category: 'fx', fullName: 'Euro / US Dollar', tick: 0.00001, prec: 5 },
  { symbol: 'GBP/USD',  base: 1.2648, vol: 0.0013, category: 'fx', fullName: 'British Pound / USD', tick: 0.00001, prec: 5 },
  { symbol: 'USD/JPY',  base: 149.82, vol: 0.22, category: 'fx', fullName: 'USD / Japanese Yen', tick: 0.001, prec: 3 },
  { symbol: 'AUD/USD',  base: 0.6552, vol: 0.0009, category: 'fx', fullName: 'Australian Dollar / USD', tick: 0.00001, prec: 5 },
  { symbol: 'USD/CHF',  base: 0.8952, vol: 0.0008, category: 'fx', fullName: 'USD / Swiss Franc', tick: 0.00001, prec: 5 },
  { symbol: 'XAU/USD',  base: 2058.5, vol: 7.5, category: 'commodity', fullName: 'Gold Spot', tick: 0.01, prec: 2 },
  { symbol: 'XAG/USD',  base: 26.48,  vol: 0.28, category: 'commodity', fullName: 'Silver Spot', tick: 0.001, prec: 3 },
  { symbol: 'WTI/USD',  base: 78.45,  vol: 0.7,  category: 'commodity', fullName: 'WTI Crude Oil', tick: 0.01, prec: 2 },
  { symbol: 'DJI',      base: 38520,  vol: 115,  category: 'index', fullName: 'Dow Jones Industrial', tick: 0.01, prec: 2 },
  { symbol: 'SPX',      base: 5072,   vol: 22,   category: 'index', fullName: 'S&P 500', tick: 0.01, prec: 2 },
] as const;

type PairSymbol = typeof PAIRS[number]['symbol'];

const CAT_COLOR: Record<string, string> = {
  oicd: '#8b5cf6', crypto: '#f59e0b', fx: '#06b6d4', commodity: '#10b981', index: '#3b82f6',
};

const EXCHANGES = ['NASDAQ', 'NYSE', 'DTX-Alpha', 'DTX-Bravo', 'OZF-DEX', 'EDGX', 'BATS', 'IEX'];

// ─── Data Helpers ──────────────────────────────────────────────────────────────

// Deterministic seeded RNG — no Math.random(). Same seed → same sequence.
// Seed rotates hourly so charts refresh each hour without user-visible randomness.
let _rngSeed = Math.floor(Date.now() / (3600 * 1000));
function rng(min: number, max: number, seed?: number): number {
  const s = seed ?? _rngSeed++;
  const x = Math.sin(s * 9301 + 49297) * 233280;
  return min + (x - Math.floor(x)) * (max - min);
}

function generateCandles(base: number, vol: number, count = 220): CandlestickData[] {
  // Reset seed per call so each symbol has consistent data within the hour
  _rngSeed = Math.floor(Date.now() / (3600 * 1000)) * 10000 + Math.round(base * 100);
  const candles: CandlestickData[] = [];
  let price = base * rng(0.97, 1.03);
  const now = Math.floor(Date.now() / 1000);
  for (let i = count; i >= 0; i--) {
    const open = price;
    const change = (Math.random() - 0.48) * vol * 2.2;
    const highExt = Math.random() * vol * 0.8;
    const lowExt  = Math.random() * vol * 0.8;
    let close = open + change;
    if (base === 1.0) close = Math.max(0.962, Math.min(1.038, close));
    const high = Math.max(open, close) + highExt;
    const low  = Math.min(open, close) - lowExt;
    price = close;
    candles.push({ time: (now - i * 3600) as Time, open: +open.toFixed(8), high: +high.toFixed(8), low: +low.toFixed(8), close: +close.toFixed(8) });
  }
  return candles;
}

function calcBB(candles: CandlestickData[], period = 20, mult = 2) {
  const upper: LineData[] = [], middle: LineData[] = [], lower: LineData[] = [];
  for (let i = period - 1; i < candles.length; i++) {
    const slice = candles.slice(i - period + 1, i + 1).map(c => c.close);
    const sma = slice.reduce((a, b) => a + b, 0) / period;
    const std = Math.sqrt(slice.reduce((a, b) => a + (b - sma) ** 2, 0) / period);
    upper.push({ time: candles[i].time, value: +(sma + mult * std).toFixed(8) });
    middle.push({ time: candles[i].time, value: +sma.toFixed(8) });
    lower.push({ time: candles[i].time, value: +(sma - mult * std).toFixed(8) });
  }
  return { upper, middle, lower };
}

function calcSMA(candles: CandlestickData[], period: number): LineData[] {
  return candles.slice(period - 1).map((c, i) => ({
    time: c.time,
    value: +(candles.slice(i, i + period).reduce((a, b) => a + b.close, 0) / period).toFixed(8),
  }));
}

function generateBook(mid: number, tick: number, levels = 20): { bids: BookLevel[]; asks: BookLevel[] } {
  const bids: BookLevel[] = [], asks: BookLevel[] = [];
  const halfSpread = tick * rng(1.2, 2.5);
  let bc = 0, ac = 0, bmax = 0, amax = 0;
  for (let i = 0; i < levels; i++) {
    const decay = Math.max(0.15, 1 - i * 0.04);
    const bs = Math.round(rng(50_000, 600_000) * decay);
    const as_ = Math.round(rng(50_000, 600_000) * decay);
    bc += bs; ac += as_;
    bids.push({ price: mid - halfSpread - i * tick * rng(1, 1.6), size: bs, total: bc, depth: 0 });
    asks.push({ price: mid + halfSpread + i * tick * rng(1, 1.6), size: as_, total: ac, depth: 0 });
    bmax = Math.max(bmax, bs); amax = Math.max(amax, as_);
  }
  bids.forEach(b => { b.depth = (b.size / bmax) * 100; });
  asks.forEach(a => { a.depth = (a.size / amax) * 100; });
  return { bids, asks };
}

function calcAI(candles: CandlestickData[], pair: typeof PAIRS[number]): AISignal {
  // RSI
  const rsiPeriod = 14;
  let gains = 0, losses = 0;
  candles.slice(-(rsiPeriod + 1)).forEach((c, i, arr) => {
    if (i === 0) return;
    const d = c.close - arr[i - 1].close;
    d > 0 ? (gains += d) : (losses -= d);
  });
  const rsi = 100 - 100 / (1 + gains / (losses || 0.001));

  // Trend via EMA cross
  const s10 = candles.slice(-10).reduce((a, c) => a + c.close, 0) / 10;
  const s30 = candles.slice(-30).reduce((a, c) => a + c.close, 0) / 30;
  const trend: 'Up' | 'Down' | 'Sideways' = s10 > s30 * 1.001 ? 'Up' : s10 < s30 * 0.999 ? 'Down' : 'Sideways';

  const sentimentScore = Math.min(100, Math.max(0, rsi + (trend === 'Up' ? 12 : trend === 'Down' ? -12 : 0)));
  const sentiment: 'Bullish' | 'Bearish' | 'Neutral' = sentimentScore > 60 ? 'Bullish' : sentimentScore < 40 ? 'Bearish' : 'Neutral';

  let pegHealth: 'Healthy' | 'Warning' | 'Critical' = 'Healthy';
  if (pair.symbol === 'OICD/USD') {
    const d = Math.abs(candles[candles.length - 1].close - 1.0);
    if (d > 0.03) pegHealth = 'Critical';
    else if (d > 0.015) pegHealth = 'Warning';
  }

  const r = sentimentScore;
  const rec: AISignal['recommendation'] = r > 75 ? 'Strong Buy' : r > 58 ? 'Buy' : r < 25 ? 'Strong Sell' : r < 42 ? 'Sell' : 'Hold';

  const prices50 = candles.slice(-50);
  const lo = Math.min(...prices50.map(c => c.low));
  const hi = Math.max(...prices50.map(c => c.high));
  const mid = (hi + lo) / 2;

  const commentaries: Record<string, string> = {
    Bullish: `Upward momentum confirmed. ${pair.symbol === 'OICD/USD' ? 'USLSM supply controller in Neutral. Peg stability maintained within $0.96–$1.04 band.' : 'Price action above 20-SMA. Accumulation phase detected.'}`,
    Bearish: `Selling pressure detected. ${pair.symbol === 'OICD/USD' ? 'Supply controller activating Mint mode. GLU signal elevated.' : 'Volume divergence suggests distribution.'}`,
    Neutral: `Consolidation range. ${pair.symbol === 'OICD/USD' ? 'MGBM model indicates low volatility. Navier-Stokes smoothing applied.' : 'Await breakout confirmation above resistance.'}`,
  };

  return {
    sentiment, sentimentScore, rsi, trend, pegHealth, recommendation: rec,
    confidence: Math.round(rng(62, 94)),
    supports: [+lo.toFixed(6), +(mid * 0.994).toFixed(6)],
    resistances: [+hi.toFixed(6), +(mid * 1.006).toFixed(6)],
    commentary: commentaries[sentiment],
  };
}

function calcOICD(price: number, prevMetrics?: OICDMetrics): OICDMetrics {
  const glu   = prevMetrics ? +(Math.max(30, Math.min(92, prevMetrics.glu + rng(-1.5, 1.5)))).toFixed(1) : +(rng(52, 78)).toFixed(1);
  const rtabr = prevMetrics ? +(Math.max(2, Math.min(8, prevMetrics.rtabr + rng(-0.08, 0.08)))).toFixed(2) : +(rng(4.0, 6.2)).toFixed(2);
  const gdi   = prevMetrics ? Math.round(Math.max(150, Math.min(350, prevMetrics.gdi + rng(-3, 3)))) : Math.round(rng(185, 245));
  const fxVol = prevMetrics ? +(Math.max(5, Math.min(48, prevMetrics.fxVol + rng(-0.8, 0.8)))).toFixed(1) : +(rng(12, 28)).toFixed(1);
  const cpeg  = +(rng(0.978, 1.022)).toFixed(4);
  const sc: OICDMetrics['supplyController'] = price > 1.012 ? 'Burn' : price < 0.988 ? 'Mint' : 'Neutral';
  return { pegValue: price, glu, rtabr, gdi, fxVol, cpeg, supplyController: sc, totalSupply: Math.round(rng(420_000_000, 480_000_000)) };
}

function calcGLTE(curPrice: number, bids: BookLevel[], asks: BookLevel[]): GLTESignal {
  const wt   = bids.reduce((a, b) => a + b.size, 0);
  const eLin = asks.reduce((a, b) => a + b.size, 0) || 1;
  const oicdPeg  = 1.0 + rng(-0.006, 0.006);
  const bTirana  = +(0.1485 + rng(-0.012, 0.012)).toFixed(4);
  const fTadawul = +(1.1243 + rng(-0.035, 0.035)).toFixed(4);
  const vixOil   = +(0.2218 + rng(-0.018, 0.018)).toFixed(4);
  const lOut = (wt / eLin) * (curPrice * oicdPeg) + (Number(bTirana) + Number(fTadawul) * Number(vixOil)) * 0.75;
  const ratio = wt / eLin;
  const direction: 'Up' | 'Down' | 'Sideways' = ratio > 1.04 ? 'Up' : ratio < 0.96 ? 'Down' : 'Sideways';
  return { lOut: +lOut.toFixed(4), direction, strength: Math.min(100, Math.round(Math.abs((ratio - 1) / 0.25) * 100)), bTirana: Number(bTirana), fTadawul: Number(fTadawul), vixOil: Number(vixOil) };
}

function generateIBAN(country: string, name: string): { iban: string; bic: string; sort: string; accountNumber: string; routingNumber: string } {
  let hash = 5381;
  for (const c of name) hash = ((hash * 33) ^ c.charCodeAt(0)) >>> 0;
  const sortA = 20 + (hash % 80); const sortB = 10 + ((hash >> 8) % 90); const sortC = 10 + ((hash >> 16) % 90);
  const sort = `${sortA}-${sortB}-${sortC}`;
  const acct = String(10_000_000 + (hash % 90_000_000));
  const check = String(10 + (hash % 88)).padStart(2, '0');
  const accountNumber = String(1_000_000_000 + (hash % 8_999_999_999)).slice(0, 10);
  const routingNumber = String(100_000_000 + ((hash >> 4) % 799_999_999)).slice(0, 9);
  return { iban: `${country}${check} OICD ${sortA} ${sortB} ${sortC} ${acct}`, bic: `OIZF${country}XXOGZ`, sort, accountNumber, routingNumber };
}

function fmtPrice(n: number, prec: number): string { return n.toFixed(prec); }
function fmtSize(n: number): string {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(2) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'K';
  return n.toString();
}

// ─── Component ─────────────────────────────────────────────────────────────────

export default function TradingTerminal() {
  const { address } = useAccount();

  const chartContainerRef = useRef<HTMLDivElement>(null);
  const chartRef          = useRef<IChartApi | null>(null);
  const csRef             = useRef<ISeriesApi<'Candlestick'> | null>(null);

  // Live prices fetched from /api/prices — anchors the simulation
  const livePricesRef = useRef<Record<string, number>>({});
  const [pricesLive, setPricesLive] = useState(false);

  const [selectedSymbol, setSelectedSymbol]   = useState<PairSymbol>('OICD/USD');
  const [activeTab, setActiveTab]             = useState<TabType>('chart');
  const [orderType, setOrderType]             = useState<OrderType>('limit');
  const [side, setSide]                       = useState<'buy' | 'sell'>('buy');
  const [limitPrice, setLimitPrice]           = useState('1.0003');
  const [qty, setQty]                         = useState('25000');
  const [bookView, setBookView]               = useState<BookView>('book');
  const [timeframe, setTimeframe]             = useState('1H');

  const [watchlist, setWatchlist]   = useState<WatchlistItem[]>(() =>
    PAIRS.map(p => ({ symbol: p.symbol, fullName: p.fullName, price: p.base, change: 0, changePct: 0, bid: p.base - p.tick * 1.5, ask: p.base + p.tick * 1.5, category: p.category as WatchlistItem['category'] }))
  );
  const [candles, setCandles]       = useState<CandlestickData[]>([]);
  const [book, setBook]             = useState<{ bids: BookLevel[]; asks: BookLevel[] }>({ bids: [], asks: [] });
  const [trades, setTrades]         = useState<RecentTrade[]>([]);
  const [aiSignal, setAISignal]     = useState<AISignal | null>(null);
  const [oicd, setOICD]             = useState<OICDMetrics | null>(null);
  const [glteSignal, setGLTESignal] = useState<GLTESignal | null>(null);
  const [showIBAN,   setShowIBAN]   = useState(false);
  const [ibanCountry, setIBANCountry] = useState('GB');
  const [ibanName,    setIBANName]    = useState('');
  const [ibanCcy,     setIBANCcy]     = useState('OICD');
  const [ibanResult,  setIBANResult]  = useState<{ iban: string; bic: string; sort: string; accountNumber: string; routingNumber: string } | null>(null);
  const [showTransfer, setShowTransfer] = useState(false);
  const [txName,    setTxName]    = useState('');
  const [txBank,    setTxBank]    = useState('');
  const [txAcct,    setTxAcct]    = useState('');
  const [txRouting, setTxRouting] = useState('');
  const [txAmount,  setTxAmount]  = useState('');
  const [txMemo,    setTxMemo]    = useState('');
  const [txRef,     setTxRef]     = useState<string | null>(null);

  const pair = useMemo(() => PAIRS.find(p => p.symbol === selectedSymbol)!, [selectedSymbol]);
  const curPrice = watchlist.find(w => w.symbol === selectedSymbol)?.price ?? pair.base;
  const spread = book.asks[0] && book.bids[0] ? book.asks[0].price - book.bids[0].price : 0;
  const total  = (parseFloat(limitPrice) || 0) * (parseFloat(qty) || 0);

  // ── Fetch real prices every 60 s ────────────────────────────────────────────
  useEffect(() => {
    async function fetchPrices() {
      try {
        const res = await fetch('/api/prices');
        if (!res.ok) return;
        const data: Record<string, number> = await res.json();
        livePricesRef.current = data;
        setPricesLive(true);
        // Snap watchlist to real prices immediately
        setWatchlist(prev => prev.map(item => {
          const live = data[item.symbol];
          if (!live) return item;
          const p = PAIRS.find(pp => pp.symbol === item.symbol)!;
          const chg = live - p.base;
          return { ...item, price: live, change: chg, changePct: (chg / p.base) * 100, bid: live - p.tick * rng(1, 2.5), ask: live + p.tick * rng(1, 2.5) };
        }));
      } catch { /* keep simulated */ }
    }
    fetchPrices();
    const id = setInterval(fetchPrices, 60_000);
    return () => clearInterval(id);
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // ── Chart Init ──────────────────────────────────────────────────────────────
  useEffect(() => {
    if (!chartContainerRef.current) return;
    const chart = createChart(chartContainerRef.current, {
      layout: { background: { type: ColorType.Solid, color: '#0d1117' }, textColor: '#8b949e', fontSize: 11 },
      grid: { vertLines: { color: '#1c2128' }, horzLines: { color: '#1c2128' } },
      crosshair: { vertLine: { color: '#4c5565' }, horzLine: { color: '#4c5565' } },
      rightPriceScale: { borderColor: '#30363d', scaleMargins: { top: 0.08, bottom: 0.28 } },
      timeScale: { borderColor: '#30363d', timeVisible: true, secondsVisible: false },
    });
    chartRef.current = chart;
    const ro = new ResizeObserver(entries => {
      if (entries[0] && chartRef.current)
        chartRef.current.applyOptions({ width: entries[0].contentRect.width, height: entries[0].contentRect.height });
    });
    ro.observe(chartContainerRef.current);
    return () => { ro.disconnect(); chart.remove(); chartRef.current = null; };
  }, []);

  // ── Load data when pair changes ─────────────────────────────────────────────
  useEffect(() => {
    const c = chartRef.current;
    if (!c) return;

    const newCandles = generateCandles(pair.base, pair.vol);
    setCandles(newCandles);
    setBook(generateBook(pair.base, pair.tick));
    setAISignal(calcAI(newCandles, pair));
    if (pair.symbol === 'OICD/USD') setOICD(calcOICD(pair.base));

    // Candlestick
    const cs = c.addCandlestickSeries({
      upColor: '#26a641', downColor: '#f44336',
      borderUpColor: '#26a641', borderDownColor: '#f44336',
      wickUpColor: '#26a641', wickDownColor: '#f44336',
    });
    cs.setData(newCandles);
    csRef.current = cs;

    // Volume
    const vs = c.addHistogramSeries({ color: '#26a64144', priceFormat: { type: 'volume' }, priceScaleId: 'vol' });
    c.priceScale('vol').applyOptions({ scaleMargins: { top: 0.78, bottom: 0 } });
    vs.setData(newCandles.map(cc => ({ time: cc.time, value: rng(40_000, 550_000), color: cc.close >= cc.open ? '#26a64166' : '#f4433666' } as HistogramData)));

    // Bollinger Bands
    const bb = calcBB(newCandles);
    const bbU = c.addLineSeries({ color: '#6366f155', lineWidth: 1, lastValueVisible: false, priceLineVisible: false });
    const bbM = c.addLineSeries({ color: '#f59e0b66', lineWidth: 1, lastValueVisible: false, priceLineVisible: false });
    const bbL = c.addLineSeries({ color: '#6366f155', lineWidth: 1, lastValueVisible: false, priceLineVisible: false });
    bbU.setData(bb.upper); bbM.setData(bb.middle); bbL.setData(bb.lower);

    // SMA 20 & 50
    const s20 = c.addLineSeries({ color: '#f59e0baa', lineWidth: 1, lastValueVisible: false, priceLineVisible: false });
    const s50 = c.addLineSeries({ color: '#8b5cf6aa', lineWidth: 1, lastValueVisible: false, priceLineVisible: false });
    s20.setData(calcSMA(newCandles, 20));
    s50.setData(calcSMA(newCandles, 50));

    // OICD peg band
    let pegU: ISeriesApi<'Line'> | null = null, pegL: ISeriesApi<'Line'> | null = null;
    if (pair.symbol === 'OICD/USD') {
      const times = newCandles.map(cc => cc.time);
      pegU = c.addLineSeries({ color: '#10b98144', lineWidth: 1, lineStyle: 2, lastValueVisible: false, priceLineVisible: false });
      pegL = c.addLineSeries({ color: '#10b98144', lineWidth: 1, lineStyle: 2, lastValueVisible: false, priceLineVisible: false });
      pegU.setData(times.map(t => ({ time: t, value: 1.04 })));
      pegL.setData(times.map(t => ({ time: t, value: 0.96 })));
    }

    c.timeScale().fitContent();

    return () => {
      csRef.current = null;
      if (!chartRef.current) return;
      try { chartRef.current.removeSeries(cs); chartRef.current.removeSeries(vs); chartRef.current.removeSeries(bbU); chartRef.current.removeSeries(bbM); chartRef.current.removeSeries(bbL); chartRef.current.removeSeries(s20); chartRef.current.removeSeries(s50); if (pegU) chartRef.current.removeSeries(pegU); if (pegL) chartRef.current.removeSeries(pegL); } catch { /* ignore */ }
    };
  }, [selectedSymbol]); // eslint-disable-line react-hooks/exhaustive-deps

  // ── Live price ticks ────────────────────────────────────────────────────────
  // Anchored to real prices from /api/prices (2 % drift clamp prevents runaway)
  useEffect(() => {
    const id = setInterval(() => {
      setWatchlist(prev => prev.map(item => {
        const p = PAIRS.find(pp => pp.symbol === item.symbol)!;
        // Real anchor: live price if available, else static base
        const anchor = livePricesRef.current[item.symbol] ?? p.base;
        const noise = (Math.random() - 0.5) * p.vol * 0.35;
        let newPrice = item.price + noise;
        // Clamp to ±2 % of real anchor to prevent drift
        const clampHigh = anchor * 1.02;
        const clampLow  = anchor * 0.98;
        newPrice = Math.min(clampHigh, Math.max(clampLow, newPrice));
        if (p.symbol === 'OICD/USD') newPrice = Math.max(0.962, Math.min(1.038, newPrice));
        const chg = newPrice - anchor;
        return { ...item, price: newPrice, change: chg, changePct: (chg / anchor) * 100, bid: newPrice - p.tick * rng(1, 2.5), ask: newPrice + p.tick * rng(1, 2.5) };
      }));
    }, 750);
    return () => clearInterval(id);
  }, []);

  // ── Live chart candle update ─────────────────────────────────────────────────
  useEffect(() => {
    const id = setInterval(() => {
      if (!csRef.current) return;
      setCandles(prev => {
        if (!prev.length) return prev;
        const last = { ...prev[prev.length - 1] };
        const noise = (Math.random() - 0.5) * pair.vol * 0.4;
        let close = last.close + noise;
        if (pair.symbol === 'OICD/USD') close = Math.max(0.962, Math.min(1.038, close));
        last.high = Math.max(last.high, close);
        last.low  = Math.min(last.low,  close);
        last.close = close;
        try { csRef.current!.update(last); } catch { /* ignore */ }
        return [...prev.slice(0, -1), last];
      });
    }, 2000);
    return () => clearInterval(id);
  }, [pair]);

  // ── Live order book + trades ────────────────────────────────────────────────
  useEffect(() => {
    const id = setInterval(() => {
      const newBook = generateBook(curPrice, pair.tick);
      setBook(newBook);
      setGLTESignal(calcGLTE(curPrice, newBook.bids, newBook.asks));
      setTrades(prev => {
        const t: RecentTrade = {
          id: Date.now(), price: curPrice + (Math.random() - 0.5) * pair.tick * 4,
          size: Math.round(rng(8_000, 120_000)), side: Math.random() > 0.5 ? 'buy' : 'sell',
          time: new Date().toLocaleTimeString('en-US', { hour12: false }),
          exchange: EXCHANGES[Math.floor(Math.random() * EXCHANGES.length)],
        };
        return [t, ...prev.slice(0, 59)];
      });
    }, 1100);
    return () => clearInterval(id);
  }, [curPrice, pair.tick]);

  // ── OICD metrics refresh ───────────────────────────────────────────────────
  useEffect(() => {
    if (pair.symbol !== 'OICD/USD') return;
    const id = setInterval(() => {
      setOICD(prev => calcOICD(curPrice, prev ?? undefined));
    }, 2800);
    return () => clearInterval(id);
  }, [curPrice, pair.symbol]);

  // ─── Render ────────────────────────────────────────────────────────────────
  const pegOk = oicd && Math.abs(oicd.pegValue - 1) < 0.02;

  return (
    <div className="flex flex-col bg-[#0d1117] rounded-xl overflow-hidden border border-white/5" style={{ height: 'calc(100vh - 7.5rem)' }}>

      {/* ── Account Bar ── */}
      <div className="flex items-center justify-between px-4 py-1.5 bg-[#161b22] border-b border-white/5 flex-shrink-0">
        <div className="flex items-center gap-2">
          <div className="w-5 h-5 bg-gradient-to-br from-purple-500 to-blue-600 rounded flex items-center justify-center text-[9px] font-bold text-white">O</div>
          <span className="text-xs font-bold text-white tracking-wide">OZF Trading Terminal</span>
          <span className={`text-[9px] px-1.5 py-0.5 rounded font-semibold ${pricesLive ? 'bg-green-500/20 text-green-400' : 'bg-yellow-500/20 text-yellow-400'}`}>{pricesLive ? 'LIVE' : 'SIM'}</span>
          <span className="text-[9px] bg-purple-500/20 text-purple-400 px-1.5 py-0.5 rounded">OBSIDIAN CAPITAL</span>
          <button onClick={() => setShowIBAN(true)} className="text-[9px] bg-blue-500/20 text-blue-400 hover:bg-blue-500/30 px-1.5 py-0.5 rounded transition-all font-semibold">IBAN+</button>
        </div>
        <div className="flex items-center gap-5 text-[10px]">
          {[
            { label: 'Account', value: address ? `${address.slice(0, 6)}…${address.slice(-4)}` : 'Not Connected' },
            { label: 'Cash', value: '$4,000.00' },
            { label: 'Buying Power', value: '$4,000.00' },
            { label: 'OICD Peg', value: `$${(oicd?.pegValue ?? 1.0).toFixed(4)}`, cls: pegOk ? 'text-green-400' : 'text-yellow-400' },
            { label: 'Total Value', value: '$4,000.00' },
          ].map(({ label, value, cls }) => (
            <div key={label} className="text-right">
              <p className="text-[9px] text-gray-600">{label}</p>
              <p className={`font-mono font-semibold ${cls ?? 'text-white'}`}>{value}</p>
            </div>
          ))}
        </div>
      </div>

      {/* ── Body: 3-column ── */}
      <div className="flex flex-1 overflow-hidden min-h-0">

        {/* ── LEFT: Watchlist ── */}
        <div className="w-48 border-r border-white/5 flex flex-col flex-shrink-0 overflow-hidden">
          <div className="px-2 py-1 bg-[#0d1117] border-b border-white/5 flex-shrink-0">
            <div className="grid grid-cols-3 text-[9px] text-gray-600 font-semibold uppercase tracking-wider">
              <span>Symbol</span><span className="text-right">Price</span><span className="text-right">Chg%</span>
            </div>
          </div>
          <div className="flex-1 overflow-y-auto scrollbar-thin">
            {(['oicd','crypto','fx','commodity','index'] as const).map(cat => {
              const items = watchlist.filter(w => w.category === cat);
              return (
                <div key={cat}>
                  <div className="px-2 pt-1.5 pb-0.5 text-[9px] uppercase tracking-widest font-bold" style={{ color: CAT_COLOR[cat] }}>
                    {cat === 'oicd' ? 'OICD System' : cat === 'fx' ? 'FX Pairs' : cat === 'commodity' ? 'Commodities' : cat === 'index' ? 'Indices' : 'Crypto'}
                  </div>
                  {items.map(item => (
                    <button key={item.symbol} onClick={() => { setSelectedSymbol(item.symbol as PairSymbol); setActiveTab('chart'); }}
                      className={`w-full grid grid-cols-3 px-2 py-1 text-[10px] hover:bg-white/5 transition-all ${selectedSymbol === item.symbol ? 'bg-blue-500/10 border-l-2 border-blue-500' : 'border-l-2 border-transparent'}`}>
                      <span className="text-left font-mono font-medium text-white truncate leading-tight">{item.symbol.split('/')[0]}</span>
                      <span className={`text-right font-mono leading-tight ${item.change >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                        {fmtPrice(item.price, PAIRS.find(p => p.symbol === item.symbol)?.prec ?? 4)}
                      </span>
                      <span className={`text-right font-mono text-[9px] leading-tight ${item.changePct >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                        {item.changePct >= 0 ? '+' : ''}{item.changePct.toFixed(2)}%
                      </span>
                    </button>
                  ))}
                </div>
              );
            })}
          </div>
        </div>

        {/* ── CENTER ── */}
        <div className="flex-1 flex flex-col overflow-hidden min-h-0">

          {/* Pair header + tabs */}
          <div className="bg-[#161b22] border-b border-white/5 flex-shrink-0">
            <div className="flex items-start justify-between px-3 pt-1.5 pb-1">
              {/* Pair info */}
              <div className="flex items-center gap-4">
                <div>
                  <div className="flex items-center gap-1.5">
                    <span className="text-sm font-bold text-white font-mono">{selectedSymbol}</span>
                    {(() => { const w = watchlist.find(x => x.symbol === selectedSymbol); const pct = w?.changePct ?? 0; return (
                      <span className={`text-[9px] px-1.5 py-0.5 rounded font-mono font-semibold ${pct >= 0 ? 'bg-green-500/15 text-green-400' : 'bg-red-500/15 text-red-400'}`}>
                        {pct >= 0 ? '▲' : '▼'} {Math.abs(pct).toFixed(2)}%
                      </span>
                    ); })()}
                  </div>
                  <div className="flex items-center gap-2 mt-0.5 text-[9px] text-gray-500">
                    {candles.length > 0 && (<>
                      <span>O <span className="text-white font-mono">{fmtPrice(candles[0].open, pair.prec)}</span></span>
                      <span>H <span className="text-green-400 font-mono">{fmtPrice(Math.max(...candles.slice(-24).map(c => c.high)), pair.prec)}</span></span>
                      <span>L <span className="text-red-400 font-mono">{fmtPrice(Math.min(...candles.slice(-24).map(c => c.low)), pair.prec)}</span></span>
                      <span>C <span className="text-white font-mono">{fmtPrice(candles[candles.length - 1].close, pair.prec)}</span></span>
                      {selectedSymbol === 'OICD/USD' && (<>
                        <span className="text-gray-700">|</span>
                        <span>BB <span className="text-purple-400 font-mono">{fmtPrice(curPrice * 1.018, 4)}</span></span>
                        <span>Mid <span className="text-yellow-400 font-mono">{fmtPrice(curPrice, 4)}</span></span>
                        <span>BB <span className="text-purple-400 font-mono">{fmtPrice(curPrice * 0.982, 4)}</span></span>
                      </>)}
                    </>)}
                  </div>
                </div>
                <div className="text-xl font-bold font-mono text-white tabular-nums">
                  {fmtPrice(curPrice, pair.prec)}
                </div>
              </div>
              {/* Tabs */}
              <div className="flex items-center gap-0.5">
                {(['chart','orders','heatmap','ai'] as TabType[]).map(t => (
                  <button key={t} onClick={() => setActiveTab(t)}
                    className={`px-3 py-1 text-[10px] rounded font-semibold capitalize transition-all ${activeTab === t ? 'bg-blue-600 text-white' : 'text-gray-500 hover:text-white hover:bg-white/5'}`}>
                    {t === 'heatmap' ? 'Heat Map' : t === 'ai' ? 'AI Analysis' : t.charAt(0).toUpperCase() + t.slice(1)}
                  </button>
                ))}
              </div>
            </div>
            {/* Timeframe + tools */}
            <div className="flex items-center gap-0.5 px-3 pb-1">
              {['1m','5m','15m','30m','1H','4H','1D','1W'].map(tf => (
                <button key={tf} onClick={() => setTimeframe(tf)}
                  className={`px-2 py-0.5 text-[9px] rounded font-mono transition-all ${timeframe === tf ? 'bg-white/10 text-white' : 'text-gray-600 hover:text-gray-300'}`}>
                  {tf}
                </button>
              ))}
              <div className="mx-1.5 h-3 w-px bg-white/10" />
              {['⎸','╲','△','⌢','Fib','⊕','⚡'].map(tool => (
                <button key={tool} className="px-1.5 py-0.5 text-[9px] text-gray-600 hover:text-gray-300 hover:bg-white/5 rounded font-mono transition-all">{tool}</button>
              ))}
              <div className="ml-auto flex items-center gap-1 text-[9px] text-gray-600">
                <span className="w-2 h-px bg-yellow-400 inline-block" /> BB
                <span className="w-2 h-px bg-yellow-500 inline-block ml-2" /> SMA20
                <span className="w-2 h-px bg-purple-500 inline-block ml-2" /> SMA50
                {selectedSymbol === 'OICD/USD' && <><span className="w-2 h-px bg-green-500 inline-block ml-2" /> Peg Band</>}
              </div>
            </div>
          </div>

          {/* ── Chart ── */}
          {activeTab === 'chart' && (
            <div ref={chartContainerRef} className="flex-1 overflow-hidden min-h-0" />
          )}

          {/* ── Orders Tab ── */}
          {activeTab === 'orders' && (
            <div className="flex-1 overflow-y-auto p-3">
              <p className="text-[10px] font-semibold text-gray-400 mb-2 uppercase tracking-wider">Open Orders — {selectedSymbol}</p>
              <table className="w-full text-[10px]">
                <thead><tr className="text-gray-600 border-b border-white/5">
                  {['Type','Side','Price','Qty','Filled','Total (USD)','Status'].map(h => (
                    <th key={h} className={`pb-1.5 font-semibold ${h === 'Type' ? 'text-left' : 'text-right'}`}>{h}</th>
                  ))}
                </tr></thead>
                <tbody>
                  {[
                    { type:'Limit', side:'Buy',  price:0.9980, qty:50_000,  filled:0,      status:'Open'    },
                    { type:'Limit', side:'Sell', price:1.0060, qty:25_000,  filled:0,      status:'Open'    },
                    { type:'Stop',  side:'Sell', price:0.9700, qty:100_000, filled:0,      status:'Pending' },
                    { type:'Market',side:'Buy',  price:curPrice, qty:10_000, filled:10_000, status:'Filled'  },
                  ].map((o, i) => (
                    <tr key={i} className="border-b border-white/5 hover:bg-white/[0.03]">
                      <td className="py-1.5 text-gray-300">{o.type}</td>
                      <td className={`text-right py-1.5 font-semibold ${o.side==='Buy'?'text-green-400':'text-red-400'}`}>{o.side}</td>
                      <td className="text-right py-1.5 font-mono text-white">{fmtPrice(o.price, pair.prec)}</td>
                      <td className="text-right py-1.5 font-mono text-white">{o.qty.toLocaleString()}</td>
                      <td className="text-right py-1.5 font-mono text-gray-500">{o.filled.toLocaleString()}</td>
                      <td className="text-right py-1.5 font-mono text-white">${(o.price * o.qty).toFixed(2)}</td>
                      <td className={`text-right py-1.5 font-semibold ${o.status==='Filled'?'text-green-400':o.status==='Open'?'text-blue-400':'text-yellow-400'}`}>{o.status}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <p className="text-[9px] text-gray-600 mt-3">Position: +10,000 {selectedSymbol.split('/')[0]} @ avg {fmtPrice(curPrice * 0.998, pair.prec)} · P&L: <span className="text-green-400">+$12.40</span></p>
            </div>
          )}

          {/* ── Heat Map ── */}
          {activeTab === 'heatmap' && (
            <div className="flex-1 overflow-y-auto p-3">
              <p className="text-[10px] font-semibold text-gray-400 mb-2 uppercase tracking-wider">Market Heat Map — 24H Performance</p>
              <div className="grid grid-cols-5 gap-1">
                {watchlist.map(item => {
                  const pct = item.changePct;
                  const intensity = Math.min(0.55, Math.abs(pct) * 0.15 + 0.08);
                  const bg = pct >= 0 ? `rgba(38,166,65,${intensity})` : `rgba(244,67,54,${intensity})`;
                  const p = PAIRS.find(pp => pp.symbol === item.symbol)!;
                  return (
                    <button key={item.symbol} onClick={() => { setSelectedSymbol(item.symbol as PairSymbol); setActiveTab('chart'); }}
                      className="p-2 rounded text-center hover:opacity-75 transition-all border border-white/5" style={{ background: bg }}>
                      <div className="text-[9px] font-bold text-white font-mono">{item.symbol.split('/')[0]}</div>
                      <div className={`text-[11px] font-mono font-bold ${pct>=0?'text-green-300':'text-red-300'}`}>{pct>=0?'+':''}{pct.toFixed(2)}%</div>
                      <div className="text-[9px] text-white/60 font-mono">{fmtPrice(item.price, p.prec)}</div>
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* ── AI Analysis ── */}
          {activeTab === 'ai' && aiSignal && (
            <div className="flex-1 overflow-y-auto p-3 space-y-2.5">
              <div className="flex items-center gap-2">
                <span className="text-[10px] font-bold text-white">OZF AI Market Intelligence</span>
                <span className="text-[9px] text-purple-400 bg-purple-500/10 px-1.5 py-0.5 rounded">{selectedSymbol}</span>
                <span className="text-[9px] text-gray-500 ml-auto">Confidence: <span className="text-white font-mono">{aiSignal.confidence}%</span></span>
              </div>
              <div className="grid grid-cols-4 gap-2">
                {[
                  { label: 'Sentiment', val: aiSignal.sentiment, sub: `${aiSignal.sentimentScore.toFixed(0)}/100`, color: aiSignal.sentiment==='Bullish'?'text-green-400':aiSignal.sentiment==='Bearish'?'text-red-400':'text-yellow-400', bar: aiSignal.sentimentScore, barColor: 'bg-green-400' },
                  { label: 'RSI Momentum', val: aiSignal.rsi.toFixed(1), sub: aiSignal.rsi>70?'Overbought':aiSignal.rsi<30?'Oversold':'Neutral', color: aiSignal.rsi>70?'text-red-400':aiSignal.rsi<30?'text-green-400':'text-white', bar: aiSignal.rsi, barColor: 'bg-blue-400' },
                  { label: 'AI Signal', val: aiSignal.recommendation, sub: `${aiSignal.trend} Trend`, color: aiSignal.recommendation.includes('Buy')?'text-green-400':aiSignal.recommendation.includes('Sell')?'text-red-400':'text-yellow-400', bar: null, barColor: '' },
                  { label: 'Peg Health', val: aiSignal.pegHealth, sub: selectedSymbol==='OICD/USD'?'$0.96–$1.04 Band':'N/A', color: aiSignal.pegHealth==='Healthy'?'text-green-400':aiSignal.pegHealth==='Warning'?'text-yellow-400':'text-red-400', bar: null, barColor: '' },
                ].map(({ label, val, sub, color, bar, barColor }) => (
                  <div key={label} className="bg-white/[0.04] rounded-lg p-2.5 border border-white/5">
                    <p className="text-[9px] text-gray-500 mb-1">{label}</p>
                    <p className={`text-sm font-bold ${color}`}>{val}</p>
                    {bar !== null && <div className="mt-1.5 h-1 bg-white/10 rounded-full overflow-hidden"><div className={`h-full rounded-full ${barColor}`} style={{ width: `${bar}%` }} /></div>}
                    <p className="text-[9px] text-gray-600 mt-1">{sub}</p>
                  </div>
                ))}
              </div>

              {/* OICD USLSM Panel */}
              {selectedSymbol === 'OICD/USD' && oicd && (
                <div className="bg-purple-500/[0.06] border border-purple-500/20 rounded-lg p-3">
                  <div className="flex items-center justify-between mb-2">
                    <p className="text-[10px] font-bold text-purple-400">USLSM — Unified Stochastic Liquidity Stabilization Model</p>
                    <span className={`text-[9px] px-1.5 py-0.5 rounded font-bold ${aiSignal.pegHealth==='Healthy'?'bg-green-500/20 text-green-400':aiSignal.pegHealth==='Warning'?'bg-yellow-500/20 text-yellow-400':'bg-red-500/20 text-red-400'}`}>{aiSignal.pegHealth}</span>
                  </div>
                  <div className="grid grid-cols-3 gap-2 text-[10px]">
                    {[
                      { label: 'GLU — Global Liquidity', value: `${oicd.glu}%`, color: 'text-blue-400' },
                      { label: 'RTABR — Treasury Rate', value: `${oicd.rtabr}%`, color: 'text-cyan-400' },
                      { label: 'GDI — Global Debt Index', value: String(oicd.gdi), color: 'text-purple-400' },
                      { label: 'FX Volatility', value: `${oicd.fxVol}%`, color: 'text-orange-400' },
                      { label: 'CPEG — Commodity', value: `$${oicd.cpeg}`, color: 'text-yellow-400' },
                      { label: 'Supply Controller', value: oicd.supplyController, color: oicd.supplyController==='Mint'?'text-green-400':oicd.supplyController==='Burn'?'text-red-400':'text-gray-400' },
                    ].map(({ label, value, color }) => (
                      <div key={label} className="bg-white/[0.04] rounded p-1.5">
                        <p className="text-[9px] text-gray-600">{label}</p>
                        <p className={`font-mono font-bold ${color}`}>{value}</p>
                      </div>
                    ))}
                  </div>
                  <div className="mt-2 flex items-center gap-4 text-[9px] text-gray-500">
                    <span>Peg: <span className="text-white font-mono">${oicd.pegValue.toFixed(4)}</span></span>
                    <span>Band: <span className="text-green-400">$0.96 – $1.04</span></span>
                    <span>Supply: <span className="text-white font-mono">{(oicd.totalSupply / 1_000_000).toFixed(1)}M OICD</span></span>
                    <span className="text-purple-400">MGBM · Van der Pol · Navier-Stokes Smoothing</span>
                  </div>
                </div>
              )}

              {/* Support / Resistance */}
              <div className="grid grid-cols-2 gap-2">
                <div className="bg-green-500/[0.05] border border-green-500/15 rounded-lg p-2.5">
                  <p className="text-[9px] text-green-400 font-bold mb-1">Support Levels</p>
                  {aiSignal.supports.map((s, i) => <p key={i} className="text-[10px] font-mono text-white">S{i+1}: {fmtPrice(s, pair.prec)}</p>)}
                </div>
                <div className="bg-red-500/[0.05] border border-red-500/15 rounded-lg p-2.5">
                  <p className="text-[9px] text-red-400 font-bold mb-1">Resistance Levels</p>
                  {aiSignal.resistances.map((r, i) => <p key={i} className="text-[10px] font-mono text-white">R{i+1}: {fmtPrice(r, pair.prec)}</p>)}
                </div>
              </div>

              <div className="bg-white/[0.03] border border-white/5 rounded-lg p-2.5">
                <p className="text-[9px] text-gray-500 mb-1">AI Commentary</p>
                <p className="text-[10px] text-gray-300 leading-relaxed">{aiSignal.commentary}</p>
              </div>
            </div>
          )}

          {/* ── Order Entry ── */}
          <div className="border-t border-white/5 bg-[#161b22] flex-shrink-0 px-3 py-2">
            <div className="flex items-end gap-3">
              {/* Order type tabs */}
              <div className="flex flex-col gap-1.5">
                <div className="flex gap-0.5">
                  {(['market','limit','stop','stop-limit'] as OrderType[]).map(ot => (
                    <button key={ot} onClick={() => setOrderType(ot)}
                      className={`px-2 py-0.5 text-[9px] rounded capitalize font-semibold transition-all ${orderType===ot?'bg-white/10 text-white':'text-gray-600 hover:text-gray-400'}`}>
                      {ot}
                    </button>
                  ))}
                </div>
                <div className="flex">
                  <button onClick={() => setSide('buy')} className={`px-5 py-1 text-xs font-bold rounded-l transition-all ${side==='buy'?'bg-green-500 text-white':'bg-green-500/10 text-green-500 hover:bg-green-500/20'}`}>BUY</button>
                  <button onClick={() => setSide('sell')} className={`px-5 py-1 text-xs font-bold rounded-r transition-all ${side==='sell'?'bg-red-500 text-white':'bg-red-500/10 text-red-500 hover:bg-red-500/20'}`}>SELL</button>
                </div>
              </div>
              {/* Inputs */}
              {orderType !== 'market' && (
                <div>
                  <label className="text-[9px] text-gray-600 block mb-0.5">Price ({selectedSymbol.split('/')[1] ?? 'USD'})</label>
                  <input type="number" value={limitPrice} onChange={e => setLimitPrice(e.target.value)} step={pair.tick}
                    className="w-28 bg-white/5 border border-white/10 rounded px-2 py-1 text-[10px] font-mono text-white focus:outline-none focus:border-blue-500 transition-colors" />
                </div>
              )}
              <div>
                <label className="text-[9px] text-gray-600 block mb-0.5">Quantity ({selectedSymbol.split('/')[0]})</label>
                <input type="number" value={qty} onChange={e => setQty(e.target.value)}
                  className="w-32 bg-white/5 border border-white/10 rounded px-2 py-1 text-[10px] font-mono text-white focus:outline-none focus:border-blue-500 transition-colors" />
              </div>
              <div>
                <label className="text-[9px] text-gray-600 block mb-0.5">Total (USD)</label>
                <div className="w-28 bg-white/[0.03] border border-white/5 rounded px-2 py-1 text-[10px] font-mono text-gray-300">
                  ${total.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </div>
              </div>
              <button className={`px-6 py-1.5 text-xs font-bold rounded transition-all shadow-lg ${side==='buy'?'bg-green-500 hover:bg-green-400 shadow-green-500/20':'bg-red-500 hover:bg-red-400 shadow-red-500/20'} text-white`}>
                {side==='buy'?`BUY ${selectedSymbol.split('/')[0]}`:`SELL ${selectedSymbol.split('/')[0]}`}
              </button>
              {/* Live bid/ask */}
              <div className="ml-auto text-[9px] space-y-0.5">
                <div>Bid: <span className="text-green-400 font-mono">{book.bids[0] ? fmtPrice(book.bids[0].price, pair.prec) : '—'}</span></div>
                <div>Ask: <span className="text-red-400 font-mono">{book.asks[0] ? fmtPrice(book.asks[0].price, pair.prec) : '—'}</span></div>
                <div>Spread: <span className="text-white font-mono">{(spread * 10000).toFixed(1)} bps</span></div>
              </div>
            </div>
          </div>
        </div>

        {/* ── RIGHT: Order Book ── */}
        <div className="w-56 border-l border-white/5 flex flex-col flex-shrink-0 overflow-hidden">
          {/* Header */}
          <div className="px-2 py-1.5 bg-[#161b22] border-b border-white/5 flex-shrink-0">
            <div className="flex gap-0.5 mb-1">
              {(['book','trades','depth'] as BookView[]).map(v => (
                <button key={v} onClick={() => setBookView(v)}
                  className={`flex-1 text-[9px] py-0.5 rounded font-semibold transition-all ${bookView===v?'bg-white/10 text-white':'text-gray-600 hover:text-gray-300'}`}>
                  {v==='book'?'Order Book':v==='trades'?'Trades':'Depth'}
                </button>
              ))}
            </div>
            <p className="text-[9px] text-center text-gray-600">Market Depth · {selectedSymbol}</p>
          </div>

          {/* Book View */}
          {bookView === 'book' && (
            <>
              <div className="grid grid-cols-3 px-2 py-0.5 text-[9px] text-gray-600 font-semibold border-b border-white/5 flex-shrink-0">
                <span>Price</span><span className="text-right">Size</span><span className="text-right">Total</span>
              </div>
              <div className="flex-1 overflow-y-auto">
                {/* Asks reversed so lowest is nearest centre */}
                {book.asks.slice(0,14).reverse().map((a, i) => (
                  <div key={i} className="relative grid grid-cols-3 px-2 py-[2px] text-[10px] hover:bg-red-500/10 cursor-pointer">
                    <div className="absolute right-0 top-0 bottom-0 bg-red-500/10" style={{ width: `${a.depth}%` }} />
                    <span className="relative z-10 text-red-400 font-mono">{fmtPrice(a.price, pair.prec)}</span>
                    <span className="relative z-10 text-right text-white font-mono">{fmtSize(a.size)}</span>
                    <span className="relative z-10 text-right text-gray-600 font-mono">{fmtSize(a.total)}</span>
                  </div>
                ))}
                {/* Spread row */}
                <div className="flex items-center justify-between px-2 py-1 bg-white/[0.04] border-y border-white/5">
                  <span className="text-[9px] text-gray-600">Spread</span>
                  <span className="text-[10px] font-mono font-bold text-white">{book.asks[0] ? fmtPrice(book.asks[0].price, pair.prec) : '—'}</span>
                  <span className="text-[9px] text-gray-500">{(spread * 10000).toFixed(1)}bp</span>
                </div>
                {/* Bids */}
                {book.bids.slice(0,14).map((b, i) => (
                  <div key={i} className="relative grid grid-cols-3 px-2 py-[2px] text-[10px] hover:bg-green-500/10 cursor-pointer">
                    <div className="absolute right-0 top-0 bottom-0 bg-green-500/10" style={{ width: `${b.depth}%` }} />
                    <span className="relative z-10 text-green-400 font-mono">{fmtPrice(b.price, pair.prec)}</span>
                    <span className="relative z-10 text-right text-white font-mono">{fmtSize(b.size)}</span>
                    <span className="relative z-10 text-right text-gray-600 font-mono">{fmtSize(b.total)}</span>
                  </div>
                ))}
              </div>
              <div className="grid grid-cols-2 px-2 py-1.5 border-t border-white/5 flex-shrink-0">
                <div className="text-center">
                  <p className="text-[8px] text-gray-600">Total Bids</p>
                  <p className="text-[10px] font-mono text-green-400">{fmtSize(book.bids.reduce((a,b)=>a+b.size,0))}</p>
                </div>
                <div className="text-center">
                  <p className="text-[8px] text-gray-600">Total Asks</p>
                  <p className="text-[10px] font-mono text-red-400">{fmtSize(book.asks.reduce((a,b)=>a+b.size,0))}</p>
                </div>
              </div>
            </>
          )}

          {/* Trades View */}
          {bookView === 'trades' && (
            <>
              <div className="grid grid-cols-4 px-2 py-0.5 text-[9px] text-gray-600 font-semibold border-b border-white/5 flex-shrink-0">
                <span>Exch</span><span className="text-right">Price</span><span className="text-right">Size</span><span className="text-right">Time</span>
              </div>
              <div className="flex-1 overflow-y-auto">
                {trades.map(t => (
                  <div key={t.id} className="grid grid-cols-4 px-2 py-[2px] text-[9px] hover:bg-white/[0.03]">
                    <span className="text-gray-600 truncate">{t.exchange}</span>
                    <span className={`text-right font-mono ${t.side==='buy'?'text-green-400':'text-red-400'}`}>{fmtPrice(t.price, pair.prec)}</span>
                    <span className="text-right font-mono text-white">{fmtSize(t.size)}</span>
                    <span className="text-right text-gray-600">{t.time}</span>
                  </div>
                ))}
              </div>
            </>
          )}

          {/* Depth View */}
          {bookView === 'depth' && (
            <div className="flex-1 p-2 overflow-y-auto">
              <p className="text-[9px] text-gray-600 mb-1.5">Cumulative Depth</p>
              {book.asks.slice(0,10).reverse().map((a, i) => (
                <div key={i} className="flex items-center gap-1 mb-px text-[9px]">
                  <span className="w-14 text-right font-mono text-red-400 shrink-0">{fmtPrice(a.price, pair.prec)}</span>
                  <div className="flex-1 h-2.5 bg-red-500/5 rounded-sm overflow-hidden">
                    <div className="h-full bg-red-500/50 rounded-sm" style={{ width: `${(a.total / (book.asks[book.asks.length-1]?.total || 1)) * 100}%` }} />
                  </div>
                </div>
              ))}
              <div className="border-t border-white/10 my-1" />
              {book.bids.slice(0,10).map((b, i) => (
                <div key={i} className="flex items-center gap-1 mb-px text-[9px]">
                  <span className="w-14 text-right font-mono text-green-400 shrink-0">{fmtPrice(b.price, pair.prec)}</span>
                  <div className="flex-1 h-2.5 bg-green-500/5 rounded-sm overflow-hidden">
                    <div className="h-full bg-green-500/50 rounded-sm" style={{ width: `${(b.total / (book.bids[book.bids.length-1]?.total || 1)) * 100}%` }} />
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* ── GLTE Signal Bar ── */}
      {glteSignal && (
        <div className="flex items-center gap-3 px-3 py-1 bg-[#090e1a] border-t border-blue-500/10 flex-shrink-0 text-[9px]">
          <span className="text-blue-500 font-bold tracking-wider">GLTE</span>
          <span className="text-gray-700">|</span>
          <span className={`font-bold font-mono ${glteSignal.direction==='Up'?'text-green-400':glteSignal.direction==='Down'?'text-red-400':'text-yellow-400'}`}>
            {glteSignal.direction==='Up'?'▲':glteSignal.direction==='Down'?'▼':'→'} {glteSignal.direction}
          </span>
          <div className="flex items-center gap-1">
            <div className="w-14 h-1 bg-white/5 rounded-full overflow-hidden">
              <div className={`h-full rounded-full ${glteSignal.direction==='Up'?'bg-green-500':glteSignal.direction==='Down'?'bg-red-500':'bg-yellow-500'}`} style={{ width:`${glteSignal.strength}%` }} />
            </div>
            <span className="text-gray-500">{glteSignal.strength}%</span>
          </div>
          <span className="text-gray-700">|</span>
          <span>L_out <span className="text-blue-400 font-mono">{glteSignal.lOut}</span></span>
          <span>B_Tirana <span className="text-cyan-400 font-mono">{glteSignal.bTirana}</span></span>
          <span>F_Tadawul <span className="text-purple-400 font-mono">{glteSignal.fTadawul}</span></span>
          <span>σ_VIX(Oil) <span className="text-orange-400 font-mono">{glteSignal.vixOil}</span></span>
          <span className="text-gray-700">|</span>
          <span className="text-gray-600">γ=0.75 · {selectedSymbol}</span>
        </div>
      )}

      {/* ── OICD Status Bar ── */}
      {oicd && (
        <div className="flex items-center gap-3 px-3 py-1 bg-[#0a0f1a] border-t border-purple-500/15 flex-shrink-0 text-[9px]">
          <span className="text-purple-500 font-bold tracking-wider">USLSM</span>
          <span className="text-gray-700">|</span>
          <span>Peg: <span className={`font-mono font-bold ${Math.abs(oicd.pegValue-1)<0.02?'text-green-400':'text-yellow-400'}`}>${oicd.pegValue.toFixed(4)}</span></span>
          <span className="text-gray-700">$0.96–$1.04</span>
          <span className="text-gray-700">|</span>
          <span>GLU <span className="text-blue-400 font-mono">{oicd.glu}%</span></span>
          <span>RTABR <span className="text-cyan-400 font-mono">{oicd.rtabr}%</span></span>
          <span>GDI <span className="text-purple-400 font-mono">{oicd.gdi}</span></span>
          <span>FX Vol <span className="text-orange-400 font-mono">{oicd.fxVol}%</span></span>
          <span>CPEG <span className="text-yellow-400 font-mono">${oicd.cpeg}</span></span>
          <span className="text-gray-700">|</span>
          <span>SC: <span className={`font-mono font-bold ${oicd.supplyController==='Mint'?'text-green-400':oicd.supplyController==='Burn'?'text-red-400':'text-gray-400'}`}>{oicd.supplyController}</span></span>
          <span>Supply <span className="text-white font-mono">{(oicd.totalSupply/1_000_000).toFixed(1)}M</span> OICD</span>
        </div>
      )}

      {/* ── IBAN Quick Create Modal ── */}
      {showIBAN && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center" onClick={() => setShowIBAN(false)}>
          <div className="bg-[#161b22] border border-white/10 rounded-xl p-5 w-96 shadow-2xl" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <div>
                <h3 className="text-sm font-bold text-white">IBAN Quick Create</h3>
                <p className="text-[10px] text-gray-500 mt-0.5">OZF Fractional Reserve Banking Network</p>
              </div>
              <button onClick={() => setShowIBAN(false)} className="text-gray-600 hover:text-white text-xl leading-none">×</button>
            </div>
            <div className="space-y-3">
              <div>
                <label className="text-[10px] text-gray-500 mb-1 block">Country Code</label>
                <select value={ibanCountry} onChange={e => { setIBANCountry(e.target.value); setIBANResult(null); }}
                  className="w-full bg-white/5 border border-white/10 rounded px-2 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500">
                  {['GB','DE','FR','AE','GH','LK','ID','CO','SA','NG','ZA','SG','JP','US'].map(c => (
                    <option key={c} value={c} className="bg-gray-900">{c}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="text-[10px] text-gray-500 mb-1 block">Account Holder Name</label>
                <input value={ibanName} onChange={e => { setIBANName(e.target.value); setIBANResult(null); }}
                  placeholder="e.g. Samuel Global Market Xchange Inc."
                  className="w-full bg-white/5 border border-white/10 rounded px-2 py-1.5 text-xs text-white placeholder-gray-600 focus:outline-none focus:border-blue-500" />
              </div>
              <div>
                <label className="text-[10px] text-gray-500 mb-1 block">Settlement Currency</label>
                <select value={ibanCcy} onChange={e => setIBANCcy(e.target.value)}
                  className="w-full bg-white/5 border border-white/10 rounded px-2 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500">
                  {['OICD','USD','EUR','GBP','AED','GHS','LKR','IDR','COP','SAR','NGN','SGD','JPY'].map(c => (
                    <option key={c} value={c} className="bg-gray-900">{c}</option>
                  ))}
                </select>
              </div>
              <button
                onClick={() => ibanName.trim() && setIBANResult(generateIBAN(ibanCountry, ibanName))}
                disabled={!ibanName.trim()}
                className="w-full bg-blue-600 hover:bg-blue-500 disabled:opacity-40 text-white text-xs font-bold py-2 rounded transition-all">
                Generate IBAN
              </button>
              {ibanResult && (
                <div className="space-y-2">
                  <div className="bg-green-500/5 border border-green-500/20 rounded-lg p-3 space-y-2 text-[10px]">
                    <div>
                      <span className="text-gray-500">IBAN</span>
                      <p className="font-mono text-green-400 font-bold mt-0.5 tracking-wide break-all">{ibanResult.iban}</p>
                    </div>
                    <div className="grid grid-cols-2 gap-2">
                      <div><span className="text-gray-500">BIC/SWIFT</span><p className="font-mono text-white">{ibanResult.bic}</p></div>
                      <div><span className="text-gray-500">Sort Code</span><p className="font-mono text-white">{ibanResult.sort}</p></div>
                      <div><span className="text-gray-500">Account No.</span><p className="font-mono text-blue-400 font-bold">{ibanResult.accountNumber}</p></div>
                      <div><span className="text-gray-500">Routing No.</span><p className="font-mono text-cyan-400 font-bold">{ibanResult.routingNumber}</p></div>
                      <div><span className="text-gray-500">Currency</span><p className="font-mono text-purple-400">{ibanCcy}</p></div>
                      <div><span className="text-gray-500">Network</span><p className="font-mono text-gray-300">OZF Banking</p></div>
                    </div>
                    <p className="text-[9px] text-gray-600">OZF Fractional Reserve Banking · ShadowDapp · {ibanCountry} corridor</p>
                  </div>

                  {/* Transfer to Bank Account */}
                  <div className="border border-white/10 rounded-lg overflow-hidden">
                    <button onClick={() => { setShowTransfer(!showTransfer); setTxRef(null); }}
                      className="w-full flex items-center justify-between px-3 py-2 bg-blue-600/10 hover:bg-blue-600/20 text-xs font-bold text-blue-400 transition-all">
                      <span>🏦 Send to Bank Account</span>
                      <span>{showTransfer ? '▲' : '▼'}</span>
                    </button>
                    {showTransfer && (
                      <div className="p-3 space-y-2 bg-white/[0.02] text-[10px]">
                        {txRef ? (
                          <div className="bg-green-500/10 border border-green-500/20 rounded p-3 space-y-1">
                            <p className="text-green-400 font-bold text-xs">✓ Transfer Submitted</p>
                            <p className="text-gray-400">Reference: <span className="font-mono text-white">{txRef}</span></p>
                            <p className="text-gray-500">Processing via OZF Clearing · 1–3 business days</p>
                            <button onClick={() => { setTxRef(null); setTxName(''); setTxBank(''); setTxAcct(''); setTxRouting(''); setTxAmount(''); setTxMemo(''); }}
                              className="mt-1 text-[9px] text-blue-400 hover:text-blue-300">New Transfer</button>
                          </div>
                        ) : (
                          <>
                            <div className="grid grid-cols-2 gap-1.5">
                              <div className="col-span-2">
                                <p className="text-gray-500 mb-0.5">Recipient Name</p>
                                <input value={txName} onChange={e => setTxName(e.target.value)} placeholder="Full legal name"
                                  className="w-full bg-white/5 border border-white/10 rounded px-2 py-1 text-white text-[10px] placeholder-gray-600 focus:outline-none focus:border-blue-500" />
                              </div>
                              <div className="col-span-2">
                                <p className="text-gray-500 mb-0.5">Bank Name</p>
                                <input value={txBank} onChange={e => setTxBank(e.target.value)} placeholder="e.g. Chase, Barclays, ADCB"
                                  className="w-full bg-white/5 border border-white/10 rounded px-2 py-1 text-white text-[10px] placeholder-gray-600 focus:outline-none focus:border-blue-500" />
                              </div>
                              <div>
                                <p className="text-gray-500 mb-0.5">Account Number</p>
                                <input value={txAcct} onChange={e => setTxAcct(e.target.value)} placeholder="Recipient account"
                                  className="w-full bg-white/5 border border-white/10 rounded px-2 py-1 text-white text-[10px] placeholder-gray-600 focus:outline-none focus:border-blue-500" />
                              </div>
                              <div>
                                <p className="text-gray-500 mb-0.5">Routing / SWIFT</p>
                                <input value={txRouting} onChange={e => setTxRouting(e.target.value)} placeholder="Routing or SWIFT"
                                  className="w-full bg-white/5 border border-white/10 rounded px-2 py-1 text-white text-[10px] placeholder-gray-600 focus:outline-none focus:border-blue-500" />
                              </div>
                              <div>
                                <p className="text-gray-500 mb-0.5">Amount</p>
                                <input value={txAmount} onChange={e => setTxAmount(e.target.value)} placeholder="0.00" type="number"
                                  className="w-full bg-white/5 border border-white/10 rounded px-2 py-1 text-white text-[10px] placeholder-gray-600 focus:outline-none focus:border-blue-500" />
                              </div>
                              <div>
                                <p className="text-gray-500 mb-0.5">Currency</p>
                                <p className="px-2 py-1 bg-purple-500/10 text-purple-400 rounded font-mono font-bold">{ibanCcy}</p>
                              </div>
                              <div className="col-span-2">
                                <p className="text-gray-500 mb-0.5">Memo / Reference</p>
                                <input value={txMemo} onChange={e => setTxMemo(e.target.value)} placeholder="Payment reference"
                                  className="w-full bg-white/5 border border-white/10 rounded px-2 py-1 text-white text-[10px] placeholder-gray-600 focus:outline-none focus:border-blue-500" />
                              </div>
                            </div>
                            <button
                              onClick={() => {
                                if (txName && txAcct && txRouting && txAmount) {
                                  let h = 5381;
                                  for (const c of txAcct + txAmount) h = ((h * 33) ^ c.charCodeAt(0)) >>> 0;
                                  setTxRef(`OZF-TXF-${Date.now().toString(36).toUpperCase()}-${(h % 999999).toString().padStart(6,'0')}`);
                                }
                              }}
                              disabled={!txName || !txAcct || !txRouting || !txAmount}
                              className="w-full bg-blue-600 hover:bg-blue-500 disabled:opacity-40 text-white text-xs font-bold py-1.5 rounded transition-all">
                              Send {txAmount || '0'} {ibanCcy} →
                            </button>
                            <p className="text-[9px] text-gray-600 text-center">Cleared via OZF Fractional Reserve Banking · From: {ibanResult.accountNumber}</p>
                          </>
                        )}
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
