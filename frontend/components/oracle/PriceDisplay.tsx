'use client';

import { formatUnits } from 'viem';
import { useGetLatestPrice, useGetAggregatedPrice, useIsPriceStale } from '@/hooks/contracts';

interface PriceDisplayProps {
  assetAddress: `0x${string}`;
  assetSymbol: string;
  decimals?: number;
}

export function PriceDisplay({ assetAddress, assetSymbol, decimals = 18 }: PriceDisplayProps) {
  const { data: latestPrice, isLoading: priceLoading } = useGetLatestPrice(assetAddress);
  const { data: aggregatedPrice, isLoading: aggLoading } = useGetAggregatedPrice(assetAddress);
  const { data: isStale } = useIsPriceStale(assetAddress);

  if (priceLoading || aggLoading) {
    return (
      <div className="animate-pulse bg-gray-200 h-20 rounded-lg"></div>
    );
  }

  const price = (latestPrice && Array.isArray(latestPrice) && latestPrice.length > 0) ? latestPrice[0] : 0n;
  const timestamp = (latestPrice && Array.isArray(latestPrice) && latestPrice.length > 1) ? latestPrice[1] : 0n;
  const aggPrice = (aggregatedPrice && Array.isArray(aggregatedPrice) && aggregatedPrice.length > 0) ? aggregatedPrice[0] : 0n;
  const confidence = (aggregatedPrice && Array.isArray(aggregatedPrice) && aggregatedPrice.length > 1) ? aggregatedPrice[1] : 0n;

  const formattedPrice = price ? formatUnits(price, decimals) : '0.00';
  const formattedAggPrice = aggPrice ? formatUnits(aggPrice, decimals) : '0.00';

  return (
    <div className="border rounded-lg p-4 space-y-3">
      <div className="flex justify-between items-start">
        <div>
          <h3 className="text-lg font-semibold">{assetSymbol}</h3>
          <p className="text-sm text-gray-500">{assetAddress.slice(0, 10)}...</p>
        </div>
        {isStale ? (
          <span className="px-2 py-1 text-xs bg-yellow-100 text-yellow-800 rounded-full">
            Stale
          </span>
        ) : null}
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <p className="text-sm text-gray-500">Latest Price</p>
          <p className="text-2xl font-bold">${formattedPrice}</p>
          {timestamp > 0n && (
            <p className="text-xs text-gray-400">
              {new Date(Number(timestamp) * 1000).toLocaleString()}
            </p>
          )}
        </div>

        <div>
          <p className="text-sm text-gray-500">Aggregated Price</p>
          <p className="text-2xl font-bold">${formattedAggPrice}</p>
          {confidence > 0n && (
            <p className="text-xs text-gray-400">
              Confidence: {confidence.toString()}%
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
