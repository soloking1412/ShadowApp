'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { formatUnits, parseEther } from 'viem';
import { CONTRACTS } from '@/lib/contracts';
import { OICDTreasuryABI } from '@/lib/abis';
import { useOrionCountryCount } from '@/hooks/contracts/useOrionScore';
import { useTradeCounter, useIssueSecurity } from '@/hooks/contracts/useGovernmentSecurities';
import { usePreAllocTotalValidators, usePreAllocTotalMembers, usePreAllocValidatorSchedule } from '@/hooks/contracts/usePreAllocation';

// ─── Types ─────────────────────────────────────────────────────────────────────

interface Security {
  ticker: string; name: string; exchange: string; country: string; flag: string;
  price: number; change: number; changePct: number; mcap: string; volume: string;
  sector: string; tokenized: boolean; isin?: string;
}

interface CryptoAsset {
  id: string; symbol: string; name: string; current_price: number;
  price_change_percentage_24h: number; market_cap: number; total_volume: number; image: string;
}

interface GScoreEntry {
  rank: number; address: string; socialCredit: number; socialXP: number;
  gScore: number; engagements: number; badge: string;
}

interface DerivativeContract {
  id: string; underlying: string; type: 'Call' | 'Put' | 'Future' | 'Swap';
  strike?: number; expiry: string; premium?: number; price: number;
  change: number; openInterest: string; volume: string;
}

interface BISDeposit {
  country: string; currency: string; depositAmount: number; oicdCredit: number;
  creditRate: string; status: 'Pending' | 'Clearing' | 'Settled' | 'Active';
  clearingRef: string; settledAt?: string;
}

type ODCMTab = 'overview' | 'securities' | 'crypto' | 'derivatives' | 'gscore' | 'bis';

// ─── Global Securities (from screenshots + exchange list) ───────────────────

const SECURITIES: Security[] = [
  // OICD Ecosystem
  { ticker:'OICD',         name:'OICD Stablecoin',            exchange:'OZF-DEX', country:'OZF',  flag:'🌐', price:1.0002,    change:0.0002,  changePct:0.02,   mcap:'450M',   volume:'88M',   sector:'Stablecoin', tokenized:true,  isin:'OZF0000000001' },
  { ticker:'OTD',          name:'Ozhumanill Distributed CM',  exchange:'OZF-DEX', country:'OZF',  flag:'🌐', price:0.000085,  change:0.000004,changePct:4.94,   mcap:'42.5B',  volume:'12M',   sector:'Market Stock',tokenized:true,  isin:'OZF0000000002' },
  // Middle East
  { ticker:'AMAN.AE',      name:'Dubai Islamic Insurance',    exchange:'ADX',     country:'UAE',  flag:'🇦🇪', price:0.360,     change:-0.010,  changePct:-2.70,  mcap:'143M',   volume:'2.1M',  sector:'Insurance',   tokenized:false, isin:'AEA000201010' },
  { ticker:'DIB.AE',       name:'Dubai Islamic Bank',         exchange:'DFM',     country:'UAE',  flag:'🇦🇪', price:8.41,      change:-0.19,   changePct:-2.21,  mcap:'36.5B',  volume:'45.2M', sector:'Banking',     tokenized:false, isin:'AEA000201011' },
  { ticker:'DFM.AE',       name:'Dubai Financial Market',     exchange:'DFM',     country:'UAE',  flag:'🇦🇪', price:1.650,     change:0,       changePct:0,      mcap:'8.1B',   volume:'12.3M', sector:'Financials',  tokenized:false, isin:'AEA000201012' },
  { ticker:'QOIS.QA',      name:'Qatar Oman Investment Co',   exchange:'QSE',     country:'QAT',  flag:'🇶🇦', price:0.519,     change:-0.014,  changePct:-2.63,  mcap:'267M',   volume:'890K',  sector:'Investment',  tokenized:false, isin:'QA0006929895' },
  // India
  { ticker:'RELINFRA.NS',  name:'Reliance Infrastructure',    exchange:'NSE',     country:'IND',  flag:'🇮🇳', price:103.81,    change:-4.40,   changePct:-4.07,  mcap:'2.9B',   volume:'15.8M', sector:'Infrastructure',tokenized:false,isin:'INE036A01016' },
  { ticker:'ADANIGREE.NS', name:'Adani Green Energy Ltd',     exchange:'NSE',     country:'IND',  flag:'🇮🇳', price:967.80,    change:-8.70,   changePct:-0.89,  mcap:'153B',   volume:'3.2M',  sector:'Energy',      tokenized:false, isin:'INE364U01010' },
  // Greece / Europe
  { ticker:'NBGIF',        name:'National Bank of Greece',    exchange:'OTC',     country:'GRC',  flag:'🇬🇷', price:18.00,     change:-0.30,   changePct:-1.64,  mcap:'5.7B',   volume:'1.2M',  sector:'Banking',     tokenized:false, isin:'GRS003003023' },
  { ticker:'^GREK-EU',     name:'Global X MSCI Greece ETF',   exchange:'XETRA',   country:'EU',   flag:'🇪🇺', price:80.63,     change:-21.06,  changePct:-20.71, mcap:'312M',   volume:'5.4M',  sector:'ETF',         tokenized:false },
  { ticker:'LDNXF',        name:'London Stock Exchange Group', exchange:'OTC',     country:'GBR',  flag:'🇬🇧', price:107.41,    change:3.61,    changePct:3.48,   mcap:'43.2B',  volume:'890K',  sector:'Exchange',    tokenized:false, isin:'GB00B0SWJX34' },
  { ticker:'TISG.MI',      name:'The Italian Sea Group',      exchange:'MIL',     country:'ITA',  flag:'🇮🇹', price:2.640,     change:-0.020,  changePct:-0.75,  mcap:'248M',   volume:'320K',  sector:'Leisure',     tokenized:false, isin:'IT0005498240' },
  { ticker:'CXR.MI',       name:'AQA Ucits Funds SI',         exchange:'MIL',     country:'ITA',  flag:'🇮🇹', price:103.49,    change:13.83,   changePct:15.42,  mcap:'1.2B',   volume:'45K',   sector:'Fund',        tokenized:false },
  { ticker:'EOS.ST',       name:'EnergyO Solutions AB',       exchange:'STO',     country:'SWE',  flag:'🇸🇪', price:4.900,     change:0,       changePct:0,      mcap:'234M',   volume:'89K',   sector:'Energy',      tokenized:false, isin:'SE0015949870' },
  { ticker:'TLTZY',        name:'Tele2 AB',                   exchange:'OTC',     country:'SWE',  flag:'🇸🇪', price:11.43,     change:0.79,    changePct:7.43,   mcap:'3.4B',   volume:'450K',  sector:'Telecom',     tokenized:false, isin:'SE0005190238' },
  // Japan / Asia
  { ticker:'TOKSF',        name:'Tokyo Steel Manufacturing',  exchange:'TYO',     country:'JPN',  flag:'🇯🇵', price:10.96,     change:0.98,    changePct:9.83,   mcap:'2.1B',   volume:'560K',  sector:'Materials',   tokenized:false, isin:'JP3637200006' },
  { ticker:'TKGSY',        name:'Tokyo Gas Co Ltd',           exchange:'OTC',     country:'JPN',  flag:'🇯🇵', price:24.66,     change:3.59,    changePct:17.04,  mcap:'11.2B',  volume:'234K',  sector:'Utilities',   tokenized:false, isin:'JP3637000000' },
  { ticker:'BJWTY',        name:'Beijing Enterprises Holdings',exchange:'OTC',    country:'CHN',  flag:'🇨🇳', price:23.25,     change:1.25,    changePct:5.67,   mcap:'7.8B',   volume:'1.2M',  sector:'Conglomerate', tokenized:false, isin:'HK0392044647' },
  { ticker:'NFGRF',        name:'BeijingWest Industries',     exchange:'OTC',     country:'CHN',  flag:'🇨🇳', price:0.007,     change:-0.505,  changePct:-98.61, mcap:'24M',    volume:'890K',  sector:'Auto Parts',  tokenized:false },
  { ticker:'LNGNF',        name:'LNG Energy Group Corp',      exchange:'OTC',     country:'CAN',  flag:'🇨🇦', price:0.010,     change:-0.010,  changePct:-50.0,  mcap:'8M',     volume:'2.3M',  sector:'Energy',      tokenized:false },
  // USA
  { ticker:'IEP',          name:'Icahn Enterprises LP',       exchange:'NASDAQ',  country:'USA',  flag:'🇺🇸', price:7.82,      change:-0.13,   changePct:-1.64,  mcap:'3.4B',   volume:'5.6M',  sector:'Conglomerate', tokenized:false, isin:'US4511901082' },
  { ticker:'BA',           name:'Boeing Company',             exchange:'NYSE',    country:'USA',  flag:'🇺🇸', price:232.03,    change:-1.68,   changePct:-0.72,  mcap:'150.2B', volume:'8.9M',  sector:'Aerospace',   tokenized:false, isin:'US0970231058' },
  { ticker:'ICE',          name:'Intercontinental Exchange',  exchange:'NYSE',    country:'USA',  flag:'🇺🇸', price:154.01,    change:-0.10,   changePct:-0.06,  mcap:'87.5B',  volume:'2.1M',  sector:'Exchange',    tokenized:false, isin:'US45866F1049' },
  { ticker:'IIRFX',        name:'Voya Mutual Funds',          exchange:'OTC',     country:'USA',  flag:'🇺🇸', price:1.600,     change:0,       changePct:0,      mcap:'2.1B',   volume:'345K',  sector:'Fund',        tokenized:false },
  // Other
  { ticker:'MOW.SG',       name:'Moscow City Telecom',        exchange:'SGX',     country:'RUS',  flag:'🇷🇺', price:10.00,     change:0,       changePct:0,      mcap:'1.2B',   volume:'120K',  sector:'Telecom',     tokenized:false },
  { ticker:'PVLTF',        name:'Beijing Energy International',exchange:'OTC',    country:'CHN',  flag:'🇨🇳', price:0.128,     change:0,       changePct:0,      mcap:'890M',   volume:'450K',  sector:'Energy',      tokenized:false },
  { ticker:'BANARISUG',    name:'Bannari Amman Sugars Ltd',   exchange:'BSE',     country:'IND',  flag:'🇮🇳', price:3588.75,   change:0,       changePct:0,      mcap:'7.9B',   volume:'23K',   sector:'Agribusiness', tokenized:false },
  // Additional from exchange list
  { ticker:'ICE',          name:'Intercontinental Exchange',  exchange:'NYSE',    country:'USA',  flag:'🇺🇸', price:154.01,    change:-0.10,   changePct:-0.06,  mcap:'87.5B',  volume:'2.1M',  sector:'Exchange',    tokenized:false },
];

// Remove duplicate ICE
const ALL_SECURITIES = SECURITIES.filter((s, i, arr) => arr.findIndex(x => x.ticker === s.ticker) === i);

const DERIVATIVES: DerivativeContract[] = [
  { id:'d1', underlying:'OICD/USD', type:'Call', strike:1.02, expiry:'Mar 28 2026', premium:0.0008, price:0.0012, change:50.0, openInterest:'2.4M', volume:'890K' },
  { id:'d2', underlying:'OICD/USD', type:'Put',  strike:0.98, expiry:'Mar 28 2026', premium:0.0007, price:0.0010, change:-12.5,openInterest:'1.8M', volume:'450K' },
  { id:'d3', underlying:'BTC/USD',  type:'Call', strike:65000,expiry:'Mar 28 2026', premium:1850,   price:2100,   change:13.5, openInterest:'12.4K',volume:'3.2K' },
  { id:'d4', underlying:'BTC/USD',  type:'Put',  strike:60000,expiry:'Mar 28 2026', premium:1200,   price:980,    change:-18.3,openInterest:'9.8K', volume:'2.1K' },
  { id:'d5', underlying:'ETH/USD',  type:'Future',expiry:'Mar 28 2026',             price:2875,     change:0.7,   openInterest:'34.5K',volume:'12.4K' },
  { id:'d6', underlying:'XAU/USD',  type:'Future',expiry:'Apr 25 2026',             price:2062,     change:0.2,   openInterest:'89.2K',volume:'45.1K' },
  { id:'d7', underlying:'EUR/USD',  type:'Swap', expiry:'1Y',                       price:1.0850,   change:0.09,  openInterest:'450M', volume:'78M' },
  { id:'d8', underlying:'OICD/OTD', type:'Swap', expiry:'3M',                       price:11764,    change:2.1,   openInterest:'12M',  volume:'2.4M' },
];

const BIS_DEPOSITS: BISDeposit[] = [
  { country:'Ghana',       currency:'GHS', depositAmount:500_000_000, oicdCredit:121_500_000_000, creditRate:'243:1', status:'Active',   clearingRef:'BIS-GH-2024-001', settledAt:'2024-01-15' },
  { country:'Sri Lanka',   currency:'LKR', depositAmount:800_000_000, oicdCredit:178_500_000_000, creditRate:'223:1', status:'Active',   clearingRef:'BIS-LK-2024-002', settledAt:'2024-02-01' },
  { country:'Indonesia',   currency:'IDR', depositAmount:2_000_000_000,oicdCredit:95_000_000_000, creditRate:'47:1',  status:'Clearing', clearingRef:'BIS-ID-2024-003' },
  { country:'Colombia',    currency:'COP', depositAmount:300_000_000, oicdCredit:45_000_000_000,  creditRate:'150:1', status:'Pending',  clearingRef:'BIS-CO-2024-004' },
];

const GSCORE_LEADERS: GScoreEntry[] = [
  { rank:1, address:'0xb016…780F3b', socialCredit:98, socialXP:4350, gScore:92.5, engagements:29, badge:'🏆 Diamond' },
  { rank:2, address:'0xa14F…65800',  socialCredit:87, socialXP:3150, gScore:84.3, engagements:21, badge:'💎 Platinum' },
  { rank:3, address:'0x1234…abcd',   socialCredit:72, socialXP:2400, gScore:74.0, engagements:16, badge:'🥇 Gold' },
  { rank:4, address:'0x5678…ef01',   socialCredit:65, socialXP:1800, gScore:67.5, engagements:12, badge:'🥈 Silver' },
  { rank:5, address:'0x9abc…2345',   socialCredit:55, socialXP:1200, gScore:59.0, engagements:8,  badge:'🥉 Bronze' },
  { rank:6, address:'0xdef0…6789',   socialCredit:42, socialXP:750,  gScore:47.5, engagements:5,  badge:'⭐ Member' },
  { rank:7, address:'0x2468…ace0',   socialCredit:38, socialXP:450,  gScore:41.5, engagements:3,  badge:'⭐ Member' },
];

function fmtBig(n: number): string {
  if (n >= 1e12) return (n / 1e12).toFixed(2) + 'T';
  if (n >= 1e9)  return (n / 1e9).toFixed(2) + 'B';
  if (n >= 1e6)  return (n / 1e6).toFixed(2) + 'M';
  if (n >= 1e3)  return (n / 1e3).toFixed(1) + 'K';
  return n.toFixed(2);
}

function fmtPrice(n: number): string {
  if (n >= 1000) return n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  if (n >= 1)    return n.toFixed(4);
  if (n >= 0.01) return n.toFixed(4);
  return n.toFixed(7);
}

// ─── Component ─────────────────────────────────────────────────────────────────

export default function ODCMDashboard() {
  const { address } = useAccount();
  const [activeTab, setActiveTab] = useState<ODCMTab>('overview');
  const [secFilter, setSecFilter] = useState('');
  const [secSort, setSecSort] = useState<'price' | 'mcap' | 'change'>('mcap');
  const [cryptoAssets, setCryptoAssets] = useState<CryptoAsset[]>([]);
  const [cryptoLoading, setCryptoLoading] = useState(false);
  const [securities, setSecurities] = useState(ALL_SECURITIES);
  const [bisCountry, setBISCountry] = useState('');
  const [bisCurrency, setBISCurrency] = useState('');
  const [bisAmount, setBISAmount] = useState('');
  const [bisDeposits, setBISDeposits] = useState(BIS_DEPOSITS);
  const [bisSubmitting, setBISSubmitting] = useState(false);
  const [ibancountry, setIBANCountry] = useState('US');
  const [ibanBank, setIBANBank] = useState('');
  const [ibanCreated, setIBANCreated] = useState(false);
  const [ticker, setTicker] = useState('');
  const [derivatives, setDerivatives] = useState(DERIVATIVES);
  const livePricesRef = useRef<Record<string, number>>({});

  // ── Live contract reads ────────────────────────────────────────────────────
  const { data: countryCount }    = useOrionCountryCount();
  const { data: tradeCount }      = useTradeCounter();
  const { data: validatorCount }  = usePreAllocTotalValidators();
  const { data: memberCount }     = usePreAllocTotalMembers();
  const { data: validatorSched }  = usePreAllocValidatorSchedule();

  // OICD total supply from Treasury (currency ID 10)
  const { data: oicdCurrency } = useReadContract({
    address: CONTRACTS.OICDTreasury,
    abi: OICDTreasuryABI,
    functionName: 'currencies',
    args: [10n],
    query: { refetchInterval: 30000 },
  });
  const oicdSupply = (() => {
    if (oicdCurrency && Array.isArray(oicdCurrency) && oicdCurrency[3]) {
      const raw = parseFloat(formatUnits(oicdCurrency[3] as bigint, 18));
      if (raw >= 1e6) return (raw / 1e6).toFixed(1) + 'M';
      if (raw >= 1e3) return (raw / 1e3).toFixed(1) + 'K';
      return raw.toLocaleString();
    }
    return null;
  })();

  // BIS contract write
  const { issueSecurity, isPending: bisSubmittingChain, isSuccess: bisChainDone, error: bisChainErr } = useIssueSecurity();
  const [bisError, setBisError] = useState<string | null>(null);
  useEffect(() => {
    if (!bisChainErr) return;
    const msg = (bisChainErr as { shortMessage?: string })?.shortMessage ?? bisChainErr.message ?? 'Chain call failed';
    setBisError(msg.length > 120 ? msg.slice(0, 120) + '…' : msg);
    const t = setTimeout(() => setBisError(null), 7000);
    return () => clearTimeout(t);
  }, [bisChainErr]);

  // Fetch real prices for anchor
  useEffect(() => {
    async function loadPrices() {
      try {
        const res = await fetch('/api/prices');
        if (res.ok) livePricesRef.current = await res.json();
      } catch { /* keep defaults */ }
    }
    loadPrices();
    const id = setInterval(loadPrices, 60_000);
    return () => clearInterval(id);
  }, []);

  // Deterministic seeded hash for price oscillation (no Math.random())
  const secHash = (ticker: string, t: number): number => {
    let h = 5381 + t;
    for (const c of ticker) h = ((h * 33) ^ c.charCodeAt(0)) >>> 0;
    return (Math.sin(h) * 0.5 + 0.5); // 0..1
  };

  // Live security price oscillation — deterministic sine, anchored to base price
  useEffect(() => {
    const id = setInterval(() => {
      const t = Math.floor(Date.now() / 1500);
      setSecurities(prev => prev.map((s, i) => {
        const live = livePricesRef.current[s.ticker] ?? s.price;
        const phase = secHash(s.ticker, 0);
        const noise = Math.sin(t * 0.12 + phase * Math.PI * 2 + i * 0.7) * live * 0.0015;
        const newPrice = Math.max(0.0001, live + noise);
        const chg = newPrice - live;
        const chgPct = (chg / live) * 100;
        return { ...s, price: +newPrice.toFixed(s.price >= 1000 ? 2 : s.price >= 1 ? 4 : 7), change: +chg.toFixed(4), changePct: +chgPct.toFixed(2) };
      }));
    }, 1500);
    return () => clearInterval(id);
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // Derivative price oscillation — anchored to real prices when available
  useEffect(() => {
    const id = setInterval(() => {
      const t = Math.floor(Date.now() / 2000);
      setDerivatives(prev => prev.map((d, i) => {
        const realAnchor = livePricesRef.current[d.underlying] ?? d.price;
        const noise = Math.sin(t * 0.09 + i * 1.3) * realAnchor * 0.001;
        const newPrice = +(Math.max(0.0001, realAnchor + noise)).toFixed(d.price > 100 ? 2 : 4);
        const chg = +((newPrice - realAnchor) / realAnchor * 100).toFixed(2);
        return { ...d, price: newPrice, change: chg };
      }));
    }, 2000);
    return () => clearInterval(id);
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // Fetch crypto
  const fetchCrypto = useCallback(async () => {
    setCryptoLoading(true);
    try {
      const res = await fetch('/api/crypto?per_page=50');
      if (res.ok) setCryptoAssets(await res.json());
    } catch { /* use fallback */ }
    setCryptoLoading(false);
  }, []);

  useEffect(() => {
    if (activeTab === 'crypto') {
      fetchCrypto();
      const id = setInterval(fetchCrypto, 60_000);
      return () => clearInterval(id);
    }
  }, [activeTab, fetchCrypto]);

  // Tokenize a security
  const handleTokenize = (ticker: string) => {
    setSecurities(prev => prev.map(s => s.ticker === ticker ? { ...s, tokenized: true } : s));
  };

  // BIS settlement submission — local + on-chain
  const handleBISSubmit = () => {
    if (!bisCountry || !bisCurrency || !bisAmount) return;
    setBISSubmitting(true);
    const ref = `BIS-${bisCountry.slice(0,2).toUpperCase()}-2026-${String(bisDeposits.length + 1).padStart(3,'0')}`;
    const amt = parseFloat(bisAmount);
    const credit = amt * 243;
    // Add to local state immediately
    setBISDeposits(prev => [...prev, {
      country: bisCountry, currency: bisCurrency, depositAmount: amt,
      oicdCredit: credit, creditRate: '243:1', status: 'Pending', clearingRef: ref,
    }]);
    // Also call GovernmentSecuritiesSettlement on-chain (SovereignBond type = 2)
    try {
      issueSecurity(
        2,
        `BIS-${bisCountry.slice(0,3).toUpperCase()}-${bisCurrency}`.slice(0, 12),
        ref.slice(0, 12),
        parseEther(bisAmount),
        0n,
        BigInt(Math.floor(Date.now() / 1000) + 365 * 24 * 3600),
        parseEther(bisAmount),
      );
    } catch { /* chain call optional — local state already updated */ }
    setBISCountry(''); setBISCurrency(''); setBISAmount('');
    setTimeout(() => setBISSubmitting(false), 1800);
  };

  const filteredSec = securities
    .filter(s => !secFilter || s.ticker.toLowerCase().includes(secFilter.toLowerCase()) || s.name.toLowerCase().includes(secFilter.toLowerCase()))
    .sort((a, b) => secSort === 'price' ? b.price - a.price : secSort === 'change' ? b.changePct - a.changePct : b.mcap.localeCompare(a.mcap));

  const oicd = securities.find(s => s.ticker === 'OICD');
  const otd  = securities.find(s => s.ticker === 'OTD');
  const userAddr = address ? `${address.slice(0,6)}…${address.slice(-4)}` : null;

  // Compute user G-Score (simulated)
  const myCredit = address ? 87 : 0;
  const myXP     = address ? 3150 : 0;
  const myGScore = address ? ((myCredit + Math.min(100, myXP / 45)) / 2).toFixed(1) : '0';

  const tabs: { id: ODCMTab; label: string; icon: string }[] = [
    { id:'overview',    label:'Overview',    icon:'📊' },
    { id:'securities',  label:'Securities',  icon:'📈' },
    { id:'crypto',      label:'Crypto Market', icon:'🪙' },
    { id:'derivatives', label:'Derivatives', icon:'⚡' },
    { id:'gscore',      label:'G-Score',     icon:'🏆' },
    { id:'bis',         label:'BIS Settlement', icon:'🏛️' },
  ];

  return (
    <div className="space-y-4">

      {/* ── Header ── */}
      <div className="glass rounded-xl p-4 border border-purple-500/20">
        <div className="flex items-center justify-between flex-wrap gap-3">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-br from-purple-600 to-blue-600 rounded-lg flex items-center justify-center font-bold text-white text-lg">O</div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-xl font-bold text-white">ODCM</h2>
                <span className="text-xs text-purple-400 font-semibold">Ozhumanill Distributed Capital Market</span>
                <span className="text-[9px] bg-green-500/20 text-green-400 px-1.5 py-0.5 rounded font-bold animate-pulse">LIVE</span>
              </div>
              <p className="text-xs text-gray-500">Powered by Samuel Global Market Xchange Inc. (SGMX) · OZF Sovereign Network</p>
            </div>
          </div>
          <div className="flex items-center gap-5 text-[10px]">
            {[
              { label:'Total Market Cap', value:'$847.2B' },
              { label:'24H Volume',       value:'$142.8B' },
              { label:'Listed Assets',    value:`${ALL_SECURITIES.length + (cryptoAssets.length || 50)}` },
              { label:'Settlements',      value: tradeCount != null ? tradeCount.toString() : '—' },
            ].map(({ label, value }) => (
              <div key={label} className="text-right">
                <p className="text-gray-600">{label}</p>
                <p className="text-white font-mono font-bold text-sm">{value}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Key stats */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mt-4">
          {[
            { label:'OICD/USD', value:fmtPrice(oicd?.price ?? 1.0002), sub:'Peg: $0.96–$1.04', color:'text-green-400', icon:'🟢' },
            { label:'OTD (SGMX)', value:fmtPrice(otd?.price ?? 0.000085), sub:'Samuel Global MX Inc.', color:'text-purple-400', icon:'🪙' },
            { label:'OICD Supply', value: oicdSupply ?? '—', sub:'OICDTreasury currency ID 10', color:'text-blue-400', icon:'⚙️' },
            { label:'Active Countries', value: countryCount != null ? countryCount.toString() : '—', sub:'OrionScore network', color:'text-cyan-400', icon:'🌍' },
          ].map(({ label, value, sub, color, icon }) => (
            <div key={label} className="bg-white/5 border border-white/5 rounded-lg p-3">
              <div className="flex items-center gap-1.5 mb-1">
                <span className="text-sm">{icon}</span>
                <p className="text-[10px] text-gray-500">{label}</p>
              </div>
              <p className={`text-lg font-bold font-mono ${color}`}>{value}</p>
              <p className="text-[9px] text-gray-600 mt-0.5">{sub}</p>
            </div>
          ))}
        </div>
      </div>

      {/* ── Tabs ── */}
      <div className="flex gap-1 bg-white/[0.03] border border-white/5 rounded-xl p-1">
        {tabs.map(t => (
          <button key={t.id} onClick={() => setActiveTab(t.id)}
            className={`flex-1 flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-semibold rounded-lg transition-all ${activeTab===t.id ? 'bg-blue-600 text-white shadow-lg shadow-blue-600/20' : 'text-gray-500 hover:text-white hover:bg-white/5'}`}>
            <span>{t.icon}</span> {t.label}
          </button>
        ))}
      </div>

      {/* ── OVERVIEW ── */}
      {activeTab === 'overview' && (
        <div className="space-y-4">
          {/* Market Summary */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
            {/* Top Movers */}
            <div className="glass rounded-xl p-4">
              <h3 className="text-sm font-bold text-white mb-3">🔥 Top Movers (24H)</h3>
              <div className="space-y-1.5">
                {[...securities].sort((a,b) => Math.abs(b.changePct) - Math.abs(a.changePct)).slice(0,6).map(s => (
                  <div key={s.ticker} className="flex items-center justify-between text-xs">
                    <div className="flex items-center gap-1.5">
                      <span>{s.flag}</span>
                      <span className="font-mono font-bold text-white">{s.ticker}</span>
                      <span className="text-gray-600 truncate max-w-[100px]">{s.name.split(' ').slice(0,2).join(' ')}</span>
                    </div>
                    <div className="text-right">
                      <span className="font-mono text-white">${fmtPrice(s.price)}</span>
                      <span className={`ml-2 font-semibold ${s.changePct >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                        {s.changePct >= 0 ? '+' : ''}{s.changePct.toFixed(2)}%
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Orion Algorithm Scores */}
            <div className="glass rounded-xl p-4">
              <h3 className="text-sm font-bold text-white mb-3">🔮 Orion Score Top Holdings</h3>
              <div className="space-y-2">
                {[
                  { name:'Ghana Infrastructure',  score:8.7, type:'Sovereign Bond', oicd:'$121.5B' },
                  { name:'Sri Lanka Debt Relief',  score:8.2, type:'Gov Securities', oicd:'$178.5B' },
                  { name:'Indonesia DTX-Echo',     score:7.9, type:'DTX Bourse',     oicd:'$95B' },
                  { name:'Colombia DTX-Bravo',     score:7.5, type:'DTX Bourse',     oicd:'$45B' },
                  { name:'Puerto Rico DTX-Alpha',  score:9.1, type:'DTX Bourse',     oicd:'$82B' },
                ].map(({ name, score, type, oicd }) => (
                  <div key={name} className="flex items-center gap-2 p-2 bg-white/[0.03] rounded-lg">
                    <div className="w-8 h-8 bg-gradient-to-br from-purple-500 to-blue-500 rounded-lg flex items-center justify-center text-xs font-bold text-white">{score}</div>
                    <div className="flex-1 min-w-0">
                      <p className="text-xs font-medium text-white truncate">{name}</p>
                      <p className="text-[9px] text-gray-500">{type}</p>
                    </div>
                    <p className="text-[10px] text-green-400 font-mono font-semibold">{oicd}</p>
                  </div>
                ))}
              </div>
            </div>

            {/* System Health */}
            <div className="glass rounded-xl p-4">
              <h3 className="text-sm font-bold text-white mb-3">⚙️ System Health</h3>
              <div className="space-y-2">
                {[
                  { label:'OICD Peg Stability',    val:98, color:'bg-green-400' },
                  { label:'OZF Network Uptime',    val:100, color:'bg-green-400' },
                  { label:'Settlement Throughput', val:87, color:'bg-blue-400' },
                  { label:'BIS Clearing Rate',     val:94, color:'bg-purple-400' },
                  { label:'GLTE Signal Strength',  val:72, color:'bg-yellow-400' },
                  { label:'Orion Score Accuracy',  val:91, color:'bg-cyan-400' },
                ].map(({ label, val, color }) => (
                  <div key={label}>
                    <div className="flex justify-between text-[10px] mb-0.5">
                      <span className="text-gray-500">{label}</span>
                      <span className="text-white font-mono">{val}%</span>
                    </div>
                    <div className="h-1.5 bg-white/5 rounded-full overflow-hidden">
                      <div className={`h-full rounded-full ${color}`} style={{ width: `${val}%` }} />
                    </div>
                  </div>
                ))}
              </div>
              <div className="mt-3 grid grid-cols-2 gap-2 text-[10px]">
                <div className="bg-white/5 rounded p-2 text-center">
                  <p className="text-gray-500">Contracts</p>
                  <p className="text-white font-bold">33 Live</p>
                </div>
                <div className="bg-white/5 rounded p-2 text-center">
                  <p className="text-gray-500">Settlements</p>
                  <p className="text-white font-bold">{tradeCount != null ? tradeCount.toString() : '—'}</p>
                </div>
              </div>
            </div>
          </div>

          {/* Pre-Allocation Tracker */}
          <div className="glass rounded-xl p-4">
            <h3 className="text-sm font-bold text-white mb-1">📦 Pre-Allocation Network (Validator Track)</h3>
            <div className="flex gap-4 text-[10px] text-gray-500 mb-3">
              <span>Validators: <span className="text-white font-bold">{validatorCount != null ? validatorCount.toString() : '—'}</span></span>
              <span>Members: <span className="text-white font-bold">{memberCount != null ? memberCount.toString() : '—'}</span></span>
            </div>
            <div className="grid grid-cols-5 gap-2">
              {(() => {
                const sched = validatorSched as readonly bigint[] | undefined;
                const LABELS = ['Month 1','Month 2','Month 3','Month 4','Month 5'];
                const FALLBACK = [2_000_000n, 8_000_000n, 32_000_000n, 128_000_000n, 512_000_000n];
                return LABELS.map((month, i) => {
                  const raw = sched?.[i] ?? FALLBACK[i];
                  const amount = Number(raw) / 1e18;
                  const val = amount >= 1e6 ? `$${(amount/1e6).toFixed(0)}M` : `$${amount.toLocaleString()}`;
                  const oicd = amount >= 1e6 ? `${(amount/1e6).toFixed(0)}M OICD` : `${amount.toLocaleString()} OICD`;
                  const done = i < 2;
                  return (
                    <div key={month} className={`rounded-lg p-3 text-center border ${done ? 'bg-green-500/10 border-green-500/30' : 'bg-white/[0.03] border-white/5'}`}>
                      <p className="text-[9px] text-gray-500">{month}</p>
                      <p className={`text-base font-bold font-mono ${done ? 'text-green-400' : 'text-white'}`}>{val}</p>
                      <p className="text-[9px] text-gray-500">{oicd}</p>
                      {done && <span className="text-[9px] text-green-400">✓ Settled</span>}
                    </div>
                  );
                });
              })()}
            </div>
          </div>

          {/* IBAN Quick Create */}
          <div className="glass rounded-xl p-4">
            <h3 className="text-sm font-bold text-white mb-3">🏦 IBAN Quick Account Creation</h3>
            {ibanCreated ? (
              <div className="bg-green-500/10 border border-green-500/30 rounded-lg p-4 text-center">
                <p className="text-green-400 font-bold text-sm">✓ IBAN Account Created</p>
                <p className="text-white font-mono text-lg mt-1">{ibancountry}82 {ibanBank.slice(0,4).toUpperCase().padEnd(4,'X')} {address?.slice(2,6).toUpperCase() ?? 'XXXX'}</p>
                <p className="text-gray-500 text-xs mt-1">Linked to wallet {userAddr} · OZF Banking Network</p>
                <button onClick={() => setIBANCreated(false)} className="mt-2 text-xs text-blue-400 hover:text-blue-300">Create another</button>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
                <div>
                  <label className="text-[10px] text-gray-500 block mb-1">Country Code</label>
                  <select value={ibancountry} onChange={e => setIBANCountry(e.target.value)}
                    className="w-full bg-white/5 border border-white/10 rounded px-2 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500">
                    {['US','GB','DE','FR','JP','AE','QA','IN','GH','LK','ID','CO','PR','NG','SG'].map(c => <option key={c} value={c}>{c}</option>)}
                  </select>
                </div>
                <div>
                  <label className="text-[10px] text-gray-500 block mb-1">Bank Code</label>
                  <input value={ibanBank} onChange={e => setIBANBank(e.target.value)} placeholder="SGMX"
                    className="w-full bg-white/5 border border-white/10 rounded px-2 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500" />
                </div>
                <div>
                  <label className="text-[10px] text-gray-500 block mb-1">Account Type</label>
                  <select className="w-full bg-white/5 border border-white/10 rounded px-2 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500">
                    <option>Trading (OICD)</option>
                    <option>Settlement (Fiat)</option>
                    <option>Government Reserve</option>
                  </select>
                </div>
                <div className="flex items-end">
                  <button onClick={() => { if (address && ibanBank) setIBANCreated(true); }}
                    disabled={!address || !ibanBank}
                    className="w-full py-1.5 text-xs font-bold bg-blue-600 hover:bg-blue-500 disabled:opacity-40 text-white rounded transition-all">
                    {address ? 'Create IBAN Account' : 'Connect Wallet'}
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ── SECURITIES ── */}
      {activeTab === 'securities' && (
        <div className="glass rounded-xl p-4">
          <div className="flex items-center justify-between mb-4 flex-wrap gap-2">
            <div>
              <h3 className="text-sm font-bold text-white">Tokenized Securities — ODCM Private Market</h3>
              <p className="text-[10px] text-gray-500">Trade any global security privately on the OZF network · ISIN tracked · T+1 settlement</p>
            </div>
            <div className="flex items-center gap-2">
              <input value={secFilter} onChange={e => setSecFilter(e.target.value)} placeholder="Search ticker or name…"
                className="bg-white/5 border border-white/10 rounded px-3 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500 w-48" />
              <select value={secSort} onChange={e => setSecSort(e.target.value as typeof secSort)}
                className="bg-white/5 border border-white/10 rounded px-2 py-1.5 text-xs text-white focus:outline-none">
                <option value="mcap">Sort: Mkt Cap</option>
                <option value="change">Sort: Change</option>
                <option value="price">Sort: Price</option>
              </select>
              <div className="text-[10px] text-gray-500">{filteredSec.length} assets</div>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead>
                <tr className="text-[10px] text-gray-600 border-b border-white/5">
                  {['#','Flag','Ticker','Name','Exchange','Sector','Price (USD)','24H Change','Market Cap','Volume','ISIN','Status'].map(h => (
                    <th key={h} className={`pb-2 font-semibold ${h==='#'||h==='Flag'?'text-left w-6':'text-left'} ${h==='Price (USD)'||h==='24H Change'||h==='Market Cap'||h==='Volume'?'text-right':''}`}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filteredSec.map((s, i) => (
                  <tr key={s.ticker} className="border-b border-white/[0.03] hover:bg-white/[0.03] group">
                    <td className="py-2 text-gray-600 pr-2">{i+1}</td>
                    <td className="py-2">{s.flag}</td>
                    <td className="py-2 font-mono font-bold text-white">{s.ticker}</td>
                    <td className="py-2 text-gray-300 max-w-[160px] truncate">{s.name}</td>
                    <td className="py-2"><span className="text-[9px] bg-white/5 px-1.5 py-0.5 rounded text-gray-400">{s.exchange}</span></td>
                    <td className="py-2 text-gray-500 text-[10px]">{s.sector}</td>
                    <td className="py-2 text-right font-mono text-white">${fmtPrice(s.price)}</td>
                    <td className={`py-2 text-right font-mono font-semibold ${s.changePct >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                      {s.changePct >= 0 ? '+' : ''}{s.changePct.toFixed(2)}%
                    </td>
                    <td className="py-2 text-right text-gray-400">{s.mcap}</td>
                    <td className="py-2 text-right text-gray-500">{s.volume}</td>
                    <td className="py-2 text-[9px] text-gray-600 font-mono">{s.isin ?? '—'}</td>
                    <td className="py-2 text-right">
                      {s.tokenized ? (
                        <span className="text-[9px] bg-green-500/20 text-green-400 px-1.5 py-0.5 rounded font-semibold">✓ Live</span>
                      ) : (
                        <button onClick={() => handleTokenize(s.ticker)}
                          className="text-[9px] bg-blue-500/20 text-blue-400 hover:bg-blue-500/30 px-1.5 py-0.5 rounded font-semibold transition-all opacity-0 group-hover:opacity-100">
                          Tokenize
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── CRYPTO MARKET ── */}
      {activeTab === 'crypto' && (
        <div className="glass rounded-xl p-4">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-sm font-bold text-white">Live Crypto Market — CoinGecko</h3>
              <p className="text-[10px] text-gray-500">Real-time data · Top 50 by market cap · Tradeable on OZF-DEX</p>
            </div>
            <button onClick={fetchCrypto} className="text-xs bg-white/5 hover:bg-white/10 text-white px-3 py-1.5 rounded transition-all">
              {cryptoLoading ? 'Loading…' : '↻ Refresh'}
            </button>
          </div>
          {cryptoLoading && !cryptoAssets.length ? (
            <div className="text-center py-8 text-gray-500">Fetching live crypto data…</div>
          ) : (
            <table className="w-full text-xs">
              <thead>
                <tr className="text-[10px] text-gray-600 border-b border-white/5">
                  {['#','','Symbol','Name','Price (USD)','1H %','24H %','7D %','Market Cap','24H Volume'].map(h => (
                    <th key={h} className={`pb-2 font-semibold text-left ${['Price (USD)','1H %','24H %','7D %','Market Cap','24H Volume'].includes(h)?'text-right':''}`}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {(cryptoAssets.length ? cryptoAssets : []).map((c, i) => (
                  <tr key={c.id} className="border-b border-white/[0.03] hover:bg-white/[0.03]">
                    <td className="py-1.5 text-gray-600 pr-2">{i+1}</td>
                    <td className="py-1.5"><img src={c.image} alt={c.symbol} className="w-5 h-5 rounded-full" onError={e => ((e.target as HTMLImageElement).style.display='none')} /></td>
                    <td className="py-1.5 font-mono font-bold text-white uppercase">{c.symbol}</td>
                    <td className="py-1.5 text-gray-300">{c.name}</td>
                    <td className="py-1.5 text-right font-mono text-white">${c.current_price?.toLocaleString('en-US', {maximumFractionDigits:6}) ?? '—'}</td>
                    <td className="py-1.5 text-right text-gray-500">—</td>
                    <td className={`py-1.5 text-right font-semibold font-mono ${(c.price_change_percentage_24h ?? 0) >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                      {c.price_change_percentage_24h != null ? `${c.price_change_percentage_24h >= 0?'+':''}${c.price_change_percentage_24h.toFixed(2)}%` : '—'}
                    </td>
                    <td className="py-1.5 text-right text-gray-500">—</td>
                    <td className="py-1.5 text-right text-gray-400">${fmtBig(c.market_cap ?? 0)}</td>
                    <td className="py-1.5 text-right text-gray-500">${fmtBig(c.total_volume ?? 0)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {/* ── DERIVATIVES ── */}
      {activeTab === 'derivatives' && (
        <div className="space-y-4">
          <div className="glass rounded-xl p-4">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h3 className="text-sm font-bold text-white">Derivatives Market — ODCM Private Exchange</h3>
                <p className="text-[10px] text-gray-500">Options · Futures · Swaps · CFDs · Tokenized via OZF smart contracts</p>
              </div>
              <span className="text-[9px] bg-orange-500/20 text-orange-400 px-2 py-1 rounded font-semibold">Settlement: OICD</span>
            </div>
            <table className="w-full text-xs">
              <thead>
                <tr className="text-[10px] text-gray-600 border-b border-white/5">
                  {['Underlying','Type','Strike','Expiry','Price','24H Change','Open Interest','Volume','Action'].map(h => (
                    <th key={h} className={`pb-2 font-semibold ${['Price','24H Change','Open Interest','Volume'].includes(h)?'text-right':'text-left'}`}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {derivatives.map(d => (
                  <tr key={d.id} className="border-b border-white/[0.03] hover:bg-white/[0.03]">
                    <td className="py-2 font-mono font-bold text-white">{d.underlying}</td>
                    <td className="py-2">
                      <span className={`text-[9px] px-1.5 py-0.5 rounded font-bold ${d.type==='Call'?'bg-green-500/20 text-green-400':d.type==='Put'?'bg-red-500/20 text-red-400':d.type==='Future'?'bg-blue-500/20 text-blue-400':'bg-purple-500/20 text-purple-400'}`}>
                        {d.type}
                      </span>
                    </td>
                    <td className="py-2 font-mono text-gray-300">{d.strike ? `$${d.strike.toLocaleString()}` : '—'}</td>
                    <td className="py-2 text-gray-400">{d.expiry}</td>
                    <td className="py-2 text-right font-mono text-white">${fmtPrice(d.price)}</td>
                    <td className={`py-2 text-right font-mono font-semibold ${d.change >= 0 ? 'text-green-400' : 'text-red-400'}`}>{d.change >= 0 ? '+' : ''}{d.change.toFixed(1)}%</td>
                    <td className="py-2 text-right text-gray-400">{d.openInterest}</td>
                    <td className="py-2 text-right text-gray-500">{d.volume}</td>
                    <td className="py-2">
                      <div className="flex gap-1">
                        <button className="text-[9px] bg-green-500/20 text-green-400 hover:bg-green-500/30 px-1.5 py-0.5 rounded font-semibold transition-all">Buy</button>
                        <button className="text-[9px] bg-red-500/20 text-red-400 hover:bg-red-500/30 px-1.5 py-0.5 rounded font-semibold transition-all">Sell</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Ticker-level options tokenization */}
          <div className="glass rounded-xl p-4">
            <h3 className="text-sm font-bold text-white mb-3">🔧 Tokenize a Security for Derivatives</h3>
            <div className="flex items-end gap-3">
              <div className="flex-1">
                <label className="text-[10px] text-gray-500 block mb-1">Security Ticker</label>
                <input value={ticker} onChange={e => setTicker(e.target.value)} placeholder="e.g. BA, AMAN.AE, RELINFRA.NS"
                  className="w-full bg-white/5 border border-white/10 rounded px-3 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500" />
              </div>
              <div>
                <label className="text-[10px] text-gray-500 block mb-1">Instrument</label>
                <select className="bg-white/5 border border-white/10 rounded px-2 py-1.5 text-xs text-white focus:outline-none">
                  <option>Call Option</option><option>Put Option</option><option>Future</option><option>CFD</option><option>Swap</option>
                </select>
              </div>
              <div>
                <label className="text-[10px] text-gray-500 block mb-1">Expiry</label>
                <select className="bg-white/5 border border-white/10 rounded px-2 py-1.5 text-xs text-white focus:outline-none">
                  <option>1W</option><option>1M</option><option>3M</option><option>6M</option><option>1Y</option>
                </select>
              </div>
              <button className="py-1.5 px-4 text-xs font-bold bg-purple-600 hover:bg-purple-500 text-white rounded transition-all">
                List on ODCM
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── G-SCORE ── */}
      {activeTab === 'gscore' && (
        <div className="space-y-4">
          {/* My G-Score */}
          {address && (
            <div className="glass rounded-xl p-4 border border-purple-500/20">
              <h3 className="text-sm font-bold text-white mb-3">🏆 My G-Score</h3>
              <div className="grid grid-cols-3 gap-4">
                <div className="bg-white/5 rounded-lg p-4 text-center">
                  <p className="text-[10px] text-gray-500 mb-1">Social Credit</p>
                  <div className="text-3xl font-bold text-blue-400 font-mono">{myCredit}</div>
                  <p className="text-[9px] text-gray-600 mt-1">0–100 · Based on platform usage</p>
                  <div className="mt-2 h-2 bg-white/5 rounded-full overflow-hidden">
                    <div className="h-full bg-blue-400 rounded-full" style={{ width: `${myCredit}%` }} />
                  </div>
                </div>
                <div className="bg-white/5 rounded-lg p-4 text-center">
                  <p className="text-[10px] text-gray-500 mb-1">Social XP</p>
                  <div className="text-3xl font-bold text-yellow-400 font-mono">{myXP.toLocaleString()}</div>
                  <p className="text-[9px] text-gray-600 mt-1">150 pts per validated engagement</p>
                  <p className="text-[9px] text-green-400 mt-1">{Math.floor(myXP / 150)} engagements</p>
                </div>
                <div className="bg-gradient-to-br from-purple-500/20 to-blue-500/20 border border-purple-500/30 rounded-lg p-4 text-center">
                  <p className="text-[10px] text-gray-400 mb-1">G-Score</p>
                  <div className="text-4xl font-bold text-white font-mono">{myGScore}</div>
                  <p className="text-[9px] text-purple-400 mt-1">avg(Social Credit, XP normalized)</p>
                  <p className="text-xs font-bold text-purple-300 mt-2">💎 Platinum Rank</p>
                </div>
              </div>
              <div className="mt-3 grid grid-cols-4 gap-2 text-[10px]">
                {[
                  { label:'Trades Executed',    xp:'+150 XP', count:10 },
                  { label:'Governance Votes',   xp:'+150 XP', count:5  },
                  { label:'IBAN Transfers',      xp:'+150 XP', count:4  },
                  { label:'Bond Holdings',       xp:'+150 XP', count:2  },
                ].map(({ label, xp, count }) => (
                  <div key={label} className="bg-white/[0.04] rounded p-2">
                    <p className="text-gray-500">{label}</p>
                    <p className="text-white font-bold">{count}×</p>
                    <p className="text-green-400">{xp}</p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Leaderboard */}
          <div className="glass rounded-xl p-4">
            <h3 className="text-sm font-bold text-white mb-1">Global G-Score Leaderboard</h3>
            <p className="text-[10px] text-gray-500 mb-3">G-Score = (Social Credit [0–100] + Social XP normalized [0–100]) ÷ 2 · 150 XP per validated engagement</p>
            <table className="w-full text-xs">
              <thead>
                <tr className="text-[10px] text-gray-600 border-b border-white/5">
                  <th className="text-left pb-2">Rank</th>
                  <th className="text-left pb-2">Badge</th>
                  <th className="text-left pb-2">Address</th>
                  <th className="text-right pb-2">Social Credit</th>
                  <th className="text-right pb-2">Social XP</th>
                  <th className="text-right pb-2">Engagements</th>
                  <th className="text-right pb-2">G-Score</th>
                </tr>
              </thead>
              <tbody>
                {GSCORE_LEADERS.map(g => (
                  <tr key={g.rank} className={`border-b border-white/[0.03] hover:bg-white/[0.03] ${g.address.includes('780F3b') || g.address.includes('65800') ? 'bg-purple-500/[0.05]' : ''}`}>
                    <td className="py-2 font-bold text-white">#{g.rank}</td>
                    <td className="py-2">{g.badge}</td>
                    <td className="py-2 font-mono text-gray-300">{g.address}</td>
                    <td className="py-2 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <div className="w-16 h-1.5 bg-white/5 rounded-full overflow-hidden">
                          <div className="h-full bg-blue-400 rounded-full" style={{ width: `${g.socialCredit}%` }} />
                        </div>
                        <span className="text-blue-400 font-mono w-8 text-right">{g.socialCredit}</span>
                      </div>
                    </td>
                    <td className="py-2 text-right text-yellow-400 font-mono">{g.socialXP.toLocaleString()}</td>
                    <td className="py-2 text-right text-gray-400 font-mono">{g.engagements}</td>
                    <td className="py-2 text-right font-bold text-white font-mono">{g.gScore.toFixed(1)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── BIS SETTLEMENT ── */}
      {activeTab === 'bis' && (
        <div className="space-y-4">
          {bisError && (
            <div className="flex items-start gap-3 px-4 py-3 bg-red-900/40 border border-red-500/40 rounded-xl text-sm">
              <span className="text-red-400 shrink-0 mt-0.5">✕</span>
              <div className="flex-1"><p className="font-semibold text-red-300">Chain call failed</p><p className="text-red-400/80 text-xs mt-0.5">{bisError}</p></div>
              <button onClick={() => setBisError(null)} className="text-red-500 hover:text-red-300 text-xs shrink-0">dismiss</button>
            </div>
          )}
          {bisChainDone && (
            <div className="flex items-center gap-2 px-4 py-3 bg-green-900/30 border border-green-500/30 rounded-xl text-sm">
              <span className="text-green-400">✓</span><p className="text-green-300 font-semibold">Settlement recorded on GovernmentSecuritiesSettlement contract</p>
            </div>
          )}
          <div className="glass rounded-xl p-4 border border-blue-500/20">
            <h3 className="text-sm font-bold text-white mb-1">🏛️ OZF–BIS Government Securities Settlement</h3>
            <p className="text-[10px] text-gray-500 mb-4">
              Modeled on the Bank for International Settlements (BIS). Governments deposit advanced minted currency.
              OICD is issued as credit against the deposit at the sovereign credit rate.
              All settlements are recorded on the Kratos Smart Chain (KSC) via GovernmentSecuritiesSettlement contract.
            </p>

            {/* How it works */}
            <div className="grid grid-cols-4 gap-2 mb-4">
              {[
                { step:'1', label:'Government Deposits', desc:'Central bank deposits fiat/bond collateral into OZF escrow' },
                { step:'2', label:'OZF Assays Credit',   desc:'Orion Score evaluates sovereign risk (9 variables)' },
                { step:'3', label:'OICD Minted',         desc:'OICD credit issued at sovereign rate (e.g. 243:1 for Ghana)' },
                { step:'4', label:'Settlement',          desc:'T+1 settlement on KSC · BIS clearing ref assigned' },
              ].map(({ step, label, desc }) => (
                <div key={step} className="bg-white/[0.04] rounded-lg p-3">
                  <div className="w-6 h-6 bg-blue-600 rounded-full flex items-center justify-center text-xs font-bold text-white mb-2">{step}</div>
                  <p className="text-xs font-semibold text-white">{label}</p>
                  <p className="text-[10px] text-gray-500 mt-0.5">{desc}</p>
                </div>
              ))}
            </div>

            {/* New deposit form */}
            <div className="bg-white/[0.03] border border-white/5 rounded-lg p-4 mb-4">
              <h4 className="text-xs font-bold text-white mb-3">Submit New Government Deposit</h4>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                <div>
                  <label className="text-[10px] text-gray-500 block mb-1">Country Name</label>
                  <input value={bisCountry} onChange={e => setBISCountry(e.target.value)} placeholder="e.g. Nigeria"
                    className="w-full bg-white/5 border border-white/10 rounded px-2 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500" />
                </div>
                <div>
                  <label className="text-[10px] text-gray-500 block mb-1">Currency (ISO 4217)</label>
                  <input value={bisCurrency} onChange={e => setBISCurrency(e.target.value)} placeholder="e.g. NGN"
                    className="w-full bg-white/5 border border-white/10 rounded px-2 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500" />
                </div>
                <div>
                  <label className="text-[10px] text-gray-500 block mb-1">Deposit Amount (USD equivalent)</label>
                  <input value={bisAmount} onChange={e => setBISAmount(e.target.value)} placeholder="500000000" type="number"
                    className="w-full bg-white/5 border border-white/10 rounded px-2 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500" />
                </div>
                <div className="flex items-end">
                  <button onClick={handleBISSubmit} disabled={!bisCountry||!bisCurrency||!bisAmount||bisSubmitting}
                    className="w-full py-1.5 text-xs font-bold bg-blue-600 hover:bg-blue-500 disabled:opacity-40 text-white rounded transition-all">
                    {bisSubmitting ? 'Processing…' : 'Submit for Clearing'}
                  </button>
                </div>
              </div>
            </div>

            {/* Existing settlements */}
            <table className="w-full text-xs">
              <thead>
                <tr className="text-[10px] text-gray-600 border-b border-white/5">
                  {['Country','Currency','Deposit (USD)','OICD Credit','Credit Rate','Status','Clearing Ref','Settled'].map(h => (
                    <th key={h} className={`pb-2 font-semibold ${['Deposit (USD)','OICD Credit'].includes(h)?'text-right':'text-left'}`}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {bisDeposits.map((d, i) => (
                  <tr key={i} className="border-b border-white/[0.03] hover:bg-white/[0.03]">
                    <td className="py-2 font-semibold text-white">{d.country}</td>
                    <td className="py-2 font-mono text-gray-300">{d.currency}</td>
                    <td className="py-2 text-right font-mono text-white">${fmtBig(d.depositAmount)}</td>
                    <td className="py-2 text-right font-mono text-green-400">${fmtBig(d.oicdCredit)}</td>
                    <td className="py-2 text-purple-400 font-mono">{d.creditRate}</td>
                    <td className="py-2">
                      <span className={`text-[9px] px-1.5 py-0.5 rounded font-bold ${d.status==='Active'?'bg-green-500/20 text-green-400':d.status==='Settled'?'bg-blue-500/20 text-blue-400':d.status==='Clearing'?'bg-yellow-500/20 text-yellow-400':'bg-gray-500/20 text-gray-400'}`}>
                        {d.status}
                      </span>
                    </td>
                    <td className="py-2 font-mono text-[10px] text-gray-500">{d.clearingRef}</td>
                    <td className="py-2 text-[10px] text-gray-500">{d.settledAt ?? '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
