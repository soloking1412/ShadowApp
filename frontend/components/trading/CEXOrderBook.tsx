'use client';

import { useState } from 'react';
import { useAccount, useReadContracts } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';
import { HFTEngineABI } from '@/lib/abis';
import { formatEther } from 'viem';
import { useOrderCounter } from '@/hooks/contracts/useHFTEngine';

interface Order {
  orderId: bigint;
  trader: string;
  baseCurrency: string;
  quoteCurrency: string;
  orderType: number;
  status: number;
  direction: number;
  quantity: bigint;
  limitPrice: bigint;
  filledQty: bigint;
  placedAt: bigint;
}

const SIDE_BUY  = 0; // Direction.Buy
const STATUS_OPEN = 0; // OrderStatus.Open

export default function CEXOrderBook() {
  const { address } = useAccount();
  const [selectedPair, setSelectedPair] = useState('OICD/USD');

  const { data: counterRaw } = useOrderCounter();
  const totalOrders = typeof counterRaw === 'bigint' ? Number(counterRaw) : 0;

  // Read last 20 orders in a single batch
  const readCount = Math.min(20, totalOrders);
  const orderContracts = Array.from({ length: readCount }, (_, i) => ({
    address: CONTRACTS.HFTEngine,
    abi: HFTEngineABI,
    functionName: 'getOrder' as const,
    args: [BigInt(totalOrders - i)] as [bigint],
  }));

  const { data: ordersRaw } = useReadContracts({
    contracts: orderContracts,
    query: { enabled: readCount > 0 },
  });

  const orders: Order[] = (ordersRaw ?? [])
    .filter(r => r.status === 'success' && r.result)
    .map(r => r.result as Order);

  const buyOrders  = orders.filter(o => o.direction === SIDE_BUY  && o.status === STATUS_OPEN)
    .sort((a, b) => Number(b.limitPrice - a.limitPrice));
  const sellOrders = orders.filter(o => o.direction !== SIDE_BUY && o.status === STATUS_OPEN)
    .sort((a, b) => Number(a.limitPrice - b.limitPrice));

  const bestBid  = buyOrders[0]?.limitPrice;
  const bestAsk  = sellOrders[0]?.limitPrice;
  const spread   = bestBid && bestAsk ? Number(formatEther(bestAsk - bestBid)) : 0;
  const spreadPct = bestBid ? (spread / Number(formatEther(bestBid))) * 100 : 0;

  const maxBidSize = buyOrders.reduce((m, o) => Math.max(m, Number(formatEther(o.quantity))), 1);
  const maxAskSize = sellOrders.reduce((m, o) => Math.max(m, Number(formatEther(o.quantity))), 1);

  return (
    <div className="glass rounded-xl p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h3 className="text-xl font-bold text-white">Order Book</h3>
          <p className="text-sm text-gray-400">{selectedPair} · HFTEngine live orders</p>
        </div>
        <div className="text-right">
          <p className="text-xs text-gray-400">Spread</p>
          <p className="text-sm font-semibold text-white">
            {spread > 0 ? `${spread.toFixed(6)} (${spreadPct.toFixed(2)}%)` : '—'}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-2 mb-4 text-xs text-gray-400 font-medium">
        <div>Price</div>
        <div className="text-right">Quantity</div>
        <div className="text-right">Total</div>
      </div>

      {/* Sell side */}
      <div className="space-y-1 mb-2">
        {sellOrders.slice(0, 10).reverse().map(order => {
          const p = Number(formatEther(order.limitPrice));
          const q = Number(formatEther(order.quantity));
          const pct = (q / maxAskSize) * 100;
          return (
            <div key={order.orderId.toString()}
              className="relative grid grid-cols-3 gap-2 text-sm py-1.5 px-2 rounded hover:bg-red-500/10 cursor-pointer">
              <div className="absolute right-0 top-0 bottom-0 bg-red-500/10" style={{ width: `${pct}%` }} />
              <div className="relative z-10 text-red-400 font-mono">{p.toFixed(6)}</div>
              <div className="relative z-10 text-right text-white font-mono">{q.toFixed(4)}</div>
              <div className="relative z-10 text-right text-gray-400 font-mono">{(p * q).toFixed(2)}</div>
            </div>
          );
        })}
      </div>

      {/* Mid price */}
      <div className="flex items-center justify-center gap-4 py-3 mb-2 bg-gradient-to-r from-red-500/20 via-transparent to-green-500/20">
        <div className="text-center">
          {bestBid ? (
            <p className="text-2xl font-bold text-white font-mono">{Number(formatEther(bestBid)).toFixed(6)}</p>
          ) : (
            <p className="text-lg text-gray-400">No active orders</p>
          )}
          <p className="text-xs text-gray-400">Best Bid</p>
        </div>
      </div>

      {/* Buy side */}
      <div className="space-y-1">
        {buyOrders.slice(0, 10).map(order => {
          const p = Number(formatEther(order.limitPrice));
          const q = Number(formatEther(order.quantity));
          const pct = (q / maxBidSize) * 100;
          return (
            <div key={order.orderId.toString()}
              className="relative grid grid-cols-3 gap-2 text-sm py-1.5 px-2 rounded hover:bg-green-500/10 cursor-pointer">
              <div className="absolute right-0 top-0 bottom-0 bg-green-500/10" style={{ width: `${pct}%` }} />
              <div className="relative z-10 text-green-400 font-mono">{p.toFixed(6)}</div>
              <div className="relative z-10 text-right text-white font-mono">{q.toFixed(4)}</div>
              <div className="relative z-10 text-right text-gray-400 font-mono">{(p * q).toFixed(2)}</div>
            </div>
          );
        })}
      </div>

      {orders.length === 0 && (
        <div className="text-center py-8 text-gray-500 text-sm">
          {totalOrders === 0 ? 'No orders placed yet. Place an order in HFT Engine to see it here.' : 'Loading orders…'}
        </div>
      )}

      <div className="mt-6 grid grid-cols-2 gap-4">
        <div className="p-4 bg-green-500/10 border border-green-500/20 rounded-lg">
          <p className="text-xs text-gray-400 mb-1">Total Bids ({buyOrders.length})</p>
          <p className="text-lg font-bold text-green-400">
            {buyOrders.reduce((s, o) => s + Number(formatEther(o.quantity)), 0).toFixed(4)}
          </p>
        </div>
        <div className="p-4 bg-red-500/10 border border-red-500/20 rounded-lg">
          <p className="text-xs text-gray-400 mb-1">Total Asks ({sellOrders.length})</p>
          <p className="text-lg font-bold text-red-400">
            {sellOrders.reduce((s, o) => s + Number(formatEther(o.quantity)), 0).toFixed(4)}
          </p>
        </div>
      </div>
    </div>
  );
}
