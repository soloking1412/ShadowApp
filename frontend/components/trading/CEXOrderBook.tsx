'use client';

import { useState, useEffect } from 'react';
import { useReadContract, useWriteContract, useAccount } from 'wagmi';
import { CONTRACTS, CURRENCY_NAMES } from '@/lib/contracts';
import { formatEther, parseEther } from 'viem';

interface Order {
  orderId: bigint;
  trader: string;
  tokenId: bigint;
  orderType: number;
  side: number;
  amount: bigint;
  price: bigint;
  filled: bigint;
  timestamp: bigint;
  active: boolean;
}

export default function CEXOrderBook() {
  const { address } = useAccount();
  const [buyOrders, setBuyOrders] = useState<Order[]>([]);
  const [sellOrders, setSellOrders] = useState<Order[]>([]);
  const [selectedPair, setSelectedPair] = useState('OICD/USD');

  useEffect(() => {
    const mockBuyOrders: Order[] = Array.from({ length: 15 }, (_, i) => ({
      orderId: BigInt(i),
      trader: '0x' + '1'.repeat(40),
      tokenId: BigInt(9),
      orderType: 1,
      side: 0,
      amount: parseEther((Math.random() * 10000).toFixed(2)),
      price: parseEther((1.05 - i * 0.001).toFixed(6)),
      filled: BigInt(0),
      timestamp: BigInt(Date.now()),
      active: true,
    }));

    const mockSellOrders: Order[] = Array.from({ length: 15 }, (_, i) => ({
      orderId: BigInt(100 + i),
      trader: '0x' + '2'.repeat(40),
      tokenId: BigInt(9),
      orderType: 1,
      side: 1,
      amount: parseEther((Math.random() * 10000).toFixed(2)),
      price: parseEther((1.06 + i * 0.001).toFixed(6)),
      filled: BigInt(0),
      timestamp: BigInt(Date.now()),
      active: true,
    }));

    setBuyOrders(mockBuyOrders);
    setSellOrders(mockSellOrders);
  }, [selectedPair]);

  const spread = sellOrders[0] && buyOrders[0]
    ? Number(formatEther(sellOrders[0].price - buyOrders[0].price))
    : 0;

  const spreadPercentage = buyOrders[0]
    ? (spread / Number(formatEther(buyOrders[0].price))) * 100
    : 0;

  return (
    <div className="glass rounded-xl p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h3 className="text-xl font-bold text-white">Order Book</h3>
          <p className="text-sm text-gray-400">{selectedPair}</p>
        </div>
        <div className="text-right">
          <p className="text-xs text-gray-400">Spread</p>
          <p className="text-sm font-semibold text-white">
            {spread.toFixed(6)} ({spreadPercentage.toFixed(2)}%)
          </p>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-2 mb-4 text-xs text-gray-400 font-medium">
        <div>Price (USD)</div>
        <div className="text-right">Amount</div>
        <div className="text-right">Total</div>
      </div>

      <div className="space-y-1 mb-2">
        {sellOrders.slice(0, 10).reverse().map((order, index) => {
          const priceNum = Number(formatEther(order.price));
          const amountNum = Number(formatEther(order.amount));
          const total = priceNum * amountNum;
          const percentage = (amountNum / 10000) * 100;

          return (
            <div
              key={order.orderId.toString()}
              className="relative grid grid-cols-3 gap-2 text-sm py-1.5 px-2 rounded hover:bg-red-500/10 cursor-pointer transition-all"
            >
              <div
                className="absolute right-0 top-0 bottom-0 bg-red-500/10"
                style={{ width: `${percentage}%` }}
              />
              <div className="relative z-10 text-red-400 font-mono">{priceNum.toFixed(6)}</div>
              <div className="relative z-10 text-right text-white font-mono">{amountNum.toFixed(2)}</div>
              <div className="relative z-10 text-right text-gray-400 font-mono">{total.toFixed(2)}</div>
            </div>
          );
        })}
      </div>

      <div className="flex items-center justify-center gap-4 py-3 mb-2 bg-gradient-to-r from-red-500/20 via-transparent to-green-500/20">
        <div className="text-center">
          <p className="text-2xl font-bold text-white font-mono">
            {buyOrders[0] ? Number(formatEther(buyOrders[0].price)).toFixed(6) : '-'}
          </p>
          <p className="text-xs text-gray-400">Last Price</p>
        </div>
      </div>

      <div className="space-y-1">
        {buyOrders.slice(0, 10).map((order, index) => {
          const priceNum = Number(formatEther(order.price));
          const amountNum = Number(formatEther(order.amount));
          const total = priceNum * amountNum;
          const percentage = (amountNum / 10000) * 100;

          return (
            <div
              key={order.orderId.toString()}
              className="relative grid grid-cols-3 gap-2 text-sm py-1.5 px-2 rounded hover:bg-green-500/10 cursor-pointer transition-all"
            >
              <div
                className="absolute right-0 top-0 bottom-0 bg-green-500/10"
                style={{ width: `${percentage}%` }}
              />
              <div className="relative z-10 text-green-400 font-mono">{priceNum.toFixed(6)}</div>
              <div className="relative z-10 text-right text-white font-mono">{amountNum.toFixed(2)}</div>
              <div className="relative z-10 text-right text-gray-400 font-mono">{total.toFixed(2)}</div>
            </div>
          );
        })}
      </div>

      <div className="mt-6 grid grid-cols-2 gap-4">
        <div className="p-4 bg-green-500/10 border border-green-500/20 rounded-lg">
          <p className="text-xs text-gray-400 mb-1">Total Bids</p>
          <p className="text-lg font-bold text-green-400">
            {buyOrders.reduce((sum, o) => sum + Number(formatEther(o.amount)), 0).toFixed(2)}
          </p>
        </div>
        <div className="p-4 bg-red-500/10 border border-red-500/20 rounded-lg">
          <p className="text-xs text-gray-400 mb-1">Total Asks</p>
          <p className="text-lg font-bold text-red-400">
            {sellOrders.reduce((sum, o) => sum + Number(formatEther(o.amount)), 0).toFixed(2)}
          </p>
        </div>
      </div>
    </div>
  );
}
