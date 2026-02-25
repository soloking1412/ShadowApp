import { NextResponse } from 'next/server';

// ── Fallback prices used when APIs are unavailable ───────────────────────────
const FALLBACK: Record<string, number> = {
  'BTC/USD':  62540,
  'ETH/USD':  2855,
  'SOL/USD':  145.5,
  'BNB/USD':  421.0,
  'LINK/USD': 18.45,
  'EUR/USD':  1.0847,
  'GBP/USD':  1.2648,
  'USD/JPY':  149.82,
  'AUD/USD':  0.6552,
  'USD/CHF':  0.8952,
  'XAU/USD':  2058.5,
  'XAG/USD':  26.48,
  'WTI/USD':  78.45,
  'DJI':      38520,
  'SPX':      5072,
  'OICD/USD': 1.0000,
  'OTD/USD':  0.0000085,
};

// ── CoinGecko symbol → our pair key ─────────────────────────────────────────
const GECKO_MAP: Record<string, string> = {
  bitcoin:      'BTC/USD',
  ethereum:     'ETH/USD',
  solana:       'SOL/USD',
  binancecoin:  'BNB/USD',
  chainlink:    'LINK/USD',
};

// ── open.er-api.com base USD → our pair keys ─────────────────────────────────
// Rates from open.er-api.com are expressed as units of X per 1 USD
// e.g.  EUR rate ≈ 0.92 means 1 USD = 0.92 EUR  →  EUR/USD = 1/0.92 ≈ 1.087
const FX_MAP: Record<string, { key: string; invert: boolean }> = {
  EUR: { key: 'EUR/USD', invert: true  },
  GBP: { key: 'GBP/USD', invert: true  },
  JPY: { key: 'USD/JPY', invert: false },
  AUD: { key: 'AUD/USD', invert: true  },
  CHF: { key: 'USD/CHF', invert: false },
  XAU: { key: 'XAU/USD', invert: true  },
  XAG: { key: 'XAG/USD', invert: true  },
};

export const dynamic = 'force-dynamic';

export async function GET() {
  const prices: Record<string, number> = { ...FALLBACK };

  try {
    // ── 1. Crypto via CoinGecko simple/price ─────────────────────────────────
    const geckoRes = await fetch(
      'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin%2Cethereum%2Csolana%2Cbinancecoin%2Cchainlink&vs_currencies=usd',
      { headers: { Accept: 'application/json' }, next: { revalidate: 30 } },
    );
    if (geckoRes.ok) {
      const geckoData: Record<string, { usd: number }> = await geckoRes.json();
      for (const [id, val] of Object.entries(geckoData)) {
        const key = GECKO_MAP[id];
        if (key && typeof val.usd === 'number' && val.usd > 0) prices[key] = val.usd;
      }
    }
  } catch { /* use fallback */ }

  try {
    // ── 2. Forex + metals via open.er-api.com (free, no key) ─────────────────
    const fxRes = await fetch(
      'https://open.er-api.com/v6/latest/USD',
      { headers: { Accept: 'application/json' }, next: { revalidate: 30 } },
    );
    if (fxRes.ok) {
      const fxData: { result: string; rates: Record<string, number> } = await fxRes.json();
      if (fxData.result === 'success' && fxData.rates) {
        for (const [code, mapping] of Object.entries(FX_MAP)) {
          const rate = fxData.rates[code];
          if (typeof rate === 'number' && rate > 0) {
            prices[mapping.key] = mapping.invert ? +(1 / rate).toFixed(6) : +rate.toFixed(6);
          }
        }
      }
    }
  } catch { /* use fallback */ }

  return NextResponse.json(prices, {
    headers: {
      'Cache-Control': 'public, s-maxage=30, stale-while-revalidate=10',
    },
  });
}
