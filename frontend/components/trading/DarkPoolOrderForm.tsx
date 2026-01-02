'use client';

import { useState } from 'react';
import { useWriteContract, useAccount, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther } from 'viem';
import { CONTRACTS, CURRENCIES, CURRENCY_NAMES } from '@/lib/contracts';

type OrderType = 'Market' | 'Limit' | 'Iceberg' | 'VWAP' | 'TWAP';
type OrderSide = 'Buy' | 'Sell';

export default function DarkPoolOrderForm() {
  const { address } = useAccount();
  const [orderType, setOrderType] = useState<OrderType>('Limit');
  const [orderSide, setOrderSide] = useState<OrderSide>('Buy');
  const [tokenId, setTokenId] = useState<number>(CURRENCIES.OICD);
  const [amount, setAmount] = useState<string>('');
  const [price, setPrice] = useState<string>('');
  const [isPublic, setIsPublic] = useState<boolean>(false);
  const [minFillAmount, setMinFillAmount] = useState<string>('');

  const { writeContract, data: hash } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const handleSubmitOrder = async () => {
    if (!address || !amount || (orderType !== 'Market' && !price)) return;

    const orderTypeMap: { [key in OrderType]: number } = {
      Market: 0,
      Limit: 1,
      Iceberg: 2,
      VWAP: 3,
      TWAP: 4,
    };

    try {
      writeContract({
        address: CONTRACTS.DarkPool,
        abi: DARK_POOL_ABI,
        functionName: 'placeOrder',
        args: [
          CONTRACTS.OICDTreasury,
          BigInt(tokenId),
          orderTypeMap[orderType],
          orderSide === 'Buy' ? 0 : 1,
          parseEther(amount),
          parseEther(price || '0'),
          parseEther(minFillAmount || '0'),
          BigInt(Math.floor(Date.now() / 1000) + 86400),
          isPublic,
        ],
      });
    } catch (error) {
      console.error('Error placing order:', error);
    }
  };

  return (
    <div className="glass rounded-xl p-6">
      <div className="flex items-center justify-between mb-6">
        <h3 className="text-xl font-bold text-white">Dark Pool Order</h3>
        <div className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full bg-purple-500 animate-pulse" />
          <span className="text-sm text-gray-400">Stealth Trading</span>
        </div>
      </div>

      <div className="space-y-4">
        <div className="flex gap-2">
          {(['Buy', 'Sell'] as OrderSide[]).map((side) => (
            <button
              key={side}
              onClick={() => setOrderSide(side)}
              className={`flex-1 py-3 rounded-lg font-semibold transition-all ${
                orderSide === side
                  ? side === 'Buy'
                    ? 'bg-green-500 text-white'
                    : 'bg-red-500 text-white'
                  : 'bg-white/5 text-gray-400 hover:bg-white/10'
              }`}
            >
              {side}
            </button>
          ))}
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-400 mb-2">Order Type</label>
          <select
            value={orderType}
            onChange={(e) => setOrderType(e.target.value as OrderType)}
            className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
          >
            <option value="Market">Market Order</option>
            <option value="Limit">Limit Order</option>
            <option value="Iceberg">Iceberg Order (10% visible)</option>
            <option value="VWAP">VWAP Execution</option>
            <option value="TWAP">TWAP Execution</option>
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-400 mb-2">Currency</label>
          <select
            value={tokenId}
            onChange={(e) => setTokenId(Number(e.target.value))}
            className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
          >
            {Object.entries(CURRENCY_NAMES).map(([id, name]) => (
              <option key={id} value={id}>
                {name}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-400 mb-2">Amount</label>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.00"
            className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
          />
        </div>

        {orderType !== 'Market' && (
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">Price</label>
            <input
              type="number"
              value={price}
              onChange={(e) => setPrice(e.target.value)}
              placeholder="0.00"
              className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
            />
          </div>
        )}

        {orderType === 'Iceberg' && (
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">Minimum Fill Amount</label>
            <input
              type="number"
              value={minFillAmount}
              onChange={(e) => setMinFillAmount(e.target.value)}
              placeholder="0.00"
              className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
            />
          </div>
        )}

        <div className="flex items-center justify-between p-4 bg-purple-500/10 border border-purple-500/20 rounded-lg">
          <div>
            <p className="text-sm font-medium text-white">Public Order</p>
            <p className="text-xs text-gray-400">Make order visible in the order book</p>
          </div>
          <button
            onClick={() => setIsPublic(!isPublic)}
            className={`relative w-12 h-6 rounded-full transition-all ${
              isPublic ? 'bg-primary-500' : 'bg-white/20'
            }`}
          >
            <div
              className={`absolute top-1 left-1 w-4 h-4 bg-white rounded-full transition-transform ${
                isPublic ? 'translate-x-6' : ''
              }`}
            />
          </button>
        </div>

        <button
          onClick={handleSubmitOrder}
          disabled={isConfirming || !address}
          className={`w-full py-4 rounded-lg font-bold text-white transition-all ${
            orderSide === 'Buy'
              ? 'bg-green-500 hover:bg-green-600'
              : 'bg-red-500 hover:bg-red-600'
          } disabled:opacity-50 disabled:cursor-not-allowed`}
        >
          {isConfirming ? 'Placing Order...' : `Place ${orderSide} Order`}
        </button>

        {isSuccess && (
          <div className="p-4 bg-green-500/10 border border-green-500/20 rounded-lg">
            <p className="text-sm text-green-400">Order placed successfully!</p>
          </div>
        )}
      </div>

      <div className="mt-6 p-4 bg-white/5 rounded-lg">
        <h4 className="text-sm font-semibold text-white mb-2">Dark Pool Features</h4>
        <ul className="space-y-2 text-xs text-gray-400">
          <li className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-purple-500" />
            Anonymous trading with hidden order details
          </li>
          <li className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-purple-500" />
            Iceberg orders show only 10% of total volume
          </li>
          <li className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-purple-500" />
            VWAP/TWAP execution for minimal market impact
          </li>
          <li className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-purple-500" />
            Verified traders only with role-based access
          </li>
        </ul>
      </div>
    </div>
  );
}

const DARK_POOL_ABI = [
  {
    inputs: [
      { name: 'tokenAddress', type: 'address' },
      { name: 'tokenId', type: 'uint256' },
      { name: 'orderType', type: 'uint8' },
      { name: 'side', type: 'uint8' },
      { name: 'amount', type: 'uint256' },
      { name: 'price', type: 'uint256' },
      { name: 'minFillAmount', type: 'uint256' },
      { name: 'expiry', type: 'uint256' },
      { name: 'isPublic', type: 'bool' },
    ],
    name: 'placeOrder',
    outputs: [{ name: '', type: 'bytes32' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const;
