import { NextResponse } from 'next/server';

/**
 * Server-side Anvil health check.
 * The browser calls /api/anvil-status (always succeeds),
 * and the server makes the RPC call — so no ERR_CONNECTION_REFUSED
 * ever appears in the browser console.
 */
export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const rpcUrl = process.env.NEXT_PUBLIC_RPC_URL ?? 'http://localhost:8545';
    const res = await fetch(rpcUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', method: 'eth_blockNumber', params: [], id: 1 }),
      signal: AbortSignal.timeout(2500),
    });
    if (!res.ok) return NextResponse.json({ status: 'offline' });
    const data = await res.json();
    if (data?.result) {
      return NextResponse.json({ status: 'online', blockNumber: parseInt(data.result, 16) });
    }
    return NextResponse.json({ status: 'offline' });
  } catch {
    return NextResponse.json({ status: 'offline' });
  }
}
