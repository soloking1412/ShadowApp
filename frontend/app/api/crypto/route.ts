import { NextResponse } from 'next/server';

// Proxies CoinGecko free API — no key required, 50 calls/min rate limit
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const page    = searchParams.get('page') ?? '1';
  const perPage = searchParams.get('per_page') ?? '50';

  try {
    const url = `https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=${perPage}&page=${page}&sparkline=false&price_change_percentage=1h%2C24h%2C7d`;
    const res = await fetch(url, {
      headers: { 'Accept': 'application/json' },
      next: { revalidate: 60 }, // cache 60 s
    });
    if (!res.ok) throw new Error(`CoinGecko ${res.status}`);
    const data = await res.json();
    return NextResponse.json(data);
  } catch (err) {
    // Return simulated fallback data so UI still works without internet
    return NextResponse.json(FALLBACK_CRYPTO);
  }
}

const FALLBACK_CRYPTO = [
  { id:'bitcoin',  symbol:'btc',  name:'Bitcoin',  current_price:62540,  price_change_percentage_24h:1.24,  market_cap:1_231_000_000_000, total_volume:28_500_000_000, image:'https://assets.coingecko.com/coins/images/1/small/bitcoin.png' },
  { id:'ethereum', symbol:'eth',  name:'Ethereum', current_price:2855,   price_change_percentage_24h:-0.82, market_cap:343_000_000_000,   total_volume:14_200_000_000, image:'https://assets.coingecko.com/coins/images/279/small/ethereum.png' },
  { id:'tether',   symbol:'usdt', name:'Tether',   current_price:1.0002, price_change_percentage_24h:0.01,  market_cap:107_000_000_000,   total_volume:52_000_000_000, image:'https://assets.coingecko.com/coins/images/325/small/Tether.png' },
  { id:'bnb',      symbol:'bnb',  name:'BNB',      current_price:421,    price_change_percentage_24h:0.45,  market_cap:61_000_000_000,    total_volume:1_800_000_000,  image:'https://assets.coingecko.com/coins/images/825/small/bnb-icon2_2x.png' },
  { id:'solana',   symbol:'sol',  name:'Solana',   current_price:145.5,  price_change_percentage_24h:2.31,  market_cap:67_000_000_000,    total_volume:4_200_000_000,  image:'https://assets.coingecko.com/coins/images/4128/small/solana.png' },
  { id:'xrp',      symbol:'xrp',  name:'XRP',      current_price:0.523,  price_change_percentage_24h:-1.12, market_cap:29_000_000_000,    total_volume:2_100_000_000,  image:'https://assets.coingecko.com/coins/images/44/small/xrp-symbol-white-128.png' },
  { id:'cardano',  symbol:'ada',  name:'Cardano',  current_price:0.614,  price_change_percentage_24h:0.88,  market_cap:21_800_000_000,    total_volume:890_000_000,    image:'https://assets.coingecko.com/coins/images/975/small/cardano.png' },
  { id:'dogecoin', symbol:'doge', name:'Dogecoin', current_price:0.1483, price_change_percentage_24h:3.21,  market_cap:21_200_000_000,    total_volume:1_400_000_000,  image:'https://assets.coingecko.com/coins/images/5/small/dogecoin.png' },
  { id:'avalanche-2', symbol:'avax', name:'Avalanche', current_price:38.24, price_change_percentage_24h:-1.45, market_cap:15_700_000_000, total_volume:780_000_000, image:'https://assets.coingecko.com/coins/images/12559/small/Avalanche_Circle_RedWhite_Trans.png' },
  { id:'chainlink', symbol:'link', name:'Chainlink', current_price:18.45, price_change_percentage_24h:1.87, market_cap:10_800_000_000, total_volume:650_000_000, image:'https://assets.coingecko.com/coins/images/877/small/chainlink-new-logo.png' },
];
