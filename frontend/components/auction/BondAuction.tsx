'use client';
import React, { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatEther, parseEther } from 'viem';
const safeEther = (v: string) => { try { return parseEther(v || '0'); } catch { return 0n; } };
const safeBig   = (v: string) => { try { return v ? BigInt(v) : 0n; } catch { return 0n; } };
import {
  useAuctionCounter, useTotalCapitalRaised, useGetAuction,
  useGetIssuerAuctions, useGetCurrentDutchPrice,
  useCreateDutchAuction, useCreateSealedBidAuction,
  useDutchBid, useSealedBid, useSettleSealedAuction,
} from '@/hooks/contracts/useBondAuction';

const AUCTION_STATUS = ['Active', 'Settled', 'Cancelled'];
const AUCTION_TYPE = ['Dutch', 'Sealed Bid'];
const STATUS_COLORS: Record<number, string> = {
  0: 'bg-green-500/20 text-green-300',
  1: 'bg-blue-500/20 text-blue-300',
  2: 'bg-gray-500/20 text-gray-400',
};

export default function BondAuction() {
  const { address, isConnected } = useAccount();
  const [tab, setTab] = useState<'overview' | 'create' | 'bid' | 'lookup'>('overview');

  // Create form
  const [auctionType, setAuctionType] = useState<'dutch' | 'sealed'>('dutch');
  const [bondName, setBondName] = useState('');
  const [bondISIN, setBondISIN] = useState('');
  const [faceValue, setFaceValue] = useState('');
  const [supply, setSupply] = useState('');
  const [startPrice, setStartPrice] = useState('');
  const [minPrice, setMinPrice] = useState('');
  const [reservePrice, setReservePrice] = useState('');
  const [decrement, setDecrement] = useState('');
  const [decrInterval, setDecrInterval] = useState('3600');
  const [duration, setDuration] = useState('86400');

  // Bid form
  const [bidAuctionId, setBidAuctionId] = useState('');
  const [bidQty, setBidQty] = useState('');
  const [sealedPrice, setSealedPrice] = useState('');

  // Lookup
  const [lookupId, setLookupId] = useState('');

  const { data: auctionCount } = useAuctionCounter();
  const { data: totalRaised } = useTotalCapitalRaised();
  const { data: lookupAuction, refetch: refetchAuction } = useGetAuction(lookupId ? BigInt(lookupId) : 0n);
  const { data: currentPrice } = useGetCurrentDutchPrice(bidAuctionId ? BigInt(bidAuctionId) : 0n);
  const { data: issuerAuctions } = useGetIssuerAuctions(address);

  const { createDutchAuction, isPending: creatingDutch, isSuccess: dutchCreated } = useCreateDutchAuction();
  const { createSealedBidAuction, isPending: creatingSealed, isSuccess: sealedCreated } = useCreateSealedBidAuction();
  const { dutchBid, isPending: bidding } = useDutchBid();
  const { sealedBid, isPending: sealedBidding } = useSealedBid();
  const { settleSealedAuction, isPending: settling } = useSettleSealedAuction();

  const handleCreate = () => {
    if (!bondName || !faceValue || !supply) return;
    const fv = safeEther(faceValue);
    const s = safeBig(supply);
    const dur = safeBig(duration);
    if (auctionType === 'dutch') {
      createDutchAuction(bondName, bondISIN, fv, s, safeEther(startPrice), safeEther(minPrice), safeEther(decrement), safeBig(decrInterval), dur);
    } else {
      createSealedBidAuction(bondName, bondISIN, fv, s, safeEther(reservePrice), dur);
    }
  };

  const TABS = [
    { id: 'overview', label: 'Overview' },
    { id: 'create', label: 'Create Auction' },
    { id: 'bid', label: 'Place Bid' },
    { id: 'lookup', label: 'Lookup' },
  ] as const;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Bond Auction House</h2>
        <p className="text-gray-400 mt-1">Dutch & sealed-bid auctions for 2DI sovereign bonds</p>
      </div>

      <div className="flex gap-2 border-b border-white/10 pb-2">
        {TABS.map(t => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={`px-4 py-2 rounded-t text-sm font-medium transition-colors ${
              tab === t.id ? 'bg-amber-600 text-white' : 'text-gray-400 hover:text-white'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Overview */}
      {tab === 'overview' && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
            {[
              { label: 'Total Auctions', value: auctionCount?.toString() ?? '—' },
              { label: 'Capital Raised', value: totalRaised ? `${parseFloat(formatEther(totalRaised as bigint)).toFixed(2)} ETH` : '—' },
              { label: 'My Auctions', value: issuerAuctions ? (issuerAuctions as bigint[]).length.toString() : '—' },
            ].map(s => (
              <div key={s.label} className="bg-white/5 rounded-xl p-4 border border-white/10">
                <div className="text-xs text-gray-400">{s.label}</div>
                <div className="text-xl font-bold text-white mt-1">{s.value}</div>
              </div>
            ))}
          </div>
          <div className="grid md:grid-cols-2 gap-4">
            <div className="bg-white/5 rounded-xl p-5 border border-white/10">
              <h3 className="font-semibold text-amber-400 mb-2">Dutch Auction</h3>
              <p className="text-sm text-gray-300">Price starts high and decrements at set intervals. First buyer to accept the current price wins. Auto-settles when all units sold.</p>
            </div>
            <div className="bg-white/5 rounded-xl p-5 border border-white/10">
              <h3 className="font-semibold text-blue-400 mb-2">Sealed-Bid Auction</h3>
              <p className="text-sm text-gray-300">All bids are hidden until settlement. Owner calls settle to reveal winner (highest bidder). Ideal for sovereign bond issuance.</p>
            </div>
          </div>
        </div>
      )}

      {/* Create Auction */}
      {tab === 'create' && (
        <div className="bg-white/5 rounded-xl p-5 border border-white/10 max-w-lg space-y-4">
          <h3 className="font-semibold text-white">Create Bond Auction</h3>
          <div className="flex gap-3">
            {(['dutch', 'sealed'] as const).map(t => (
              <button
                key={t}
                onClick={() => setAuctionType(t)}
                className={`px-4 py-2 rounded text-sm font-medium ${auctionType === t ? 'bg-amber-600 text-white' : 'bg-white/10 text-gray-300'}`}
              >
                {t === 'dutch' ? 'Dutch' : 'Sealed Bid'}
              </button>
            ))}
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="col-span-2">
              <label className="text-xs text-gray-400 block mb-1">Bond Name</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" value={bondName} onChange={e => setBondName(e.target.value)} placeholder="OZF Infrastructure Bond 2026" />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">ISIN</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" value={bondISIN} onChange={e => setBondISIN(e.target.value)} placeholder="OZ0001234567" />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Supply (units)</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" type="number" value={supply} onChange={e => setSupply(e.target.value)} placeholder="1000" />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Face Value (ETH)</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" type="number" value={faceValue} onChange={e => setFaceValue(e.target.value)} placeholder="1" />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Duration (seconds)</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" type="number" value={duration} onChange={e => setDuration(e.target.value)} placeholder="86400" />
            </div>
          </div>

          {auctionType === 'dutch' && (
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs text-gray-400 block mb-1">Start Price (ETH)</label>
                <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" type="number" value={startPrice} onChange={e => setStartPrice(e.target.value)} placeholder="2.0" />
              </div>
              <div>
                <label className="text-xs text-gray-400 block mb-1">Min Price (ETH)</label>
                <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" type="number" value={minPrice} onChange={e => setMinPrice(e.target.value)} placeholder="0.5" />
              </div>
              <div>
                <label className="text-xs text-gray-400 block mb-1">Price Decrement (ETH)</label>
                <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" type="number" value={decrement} onChange={e => setDecrement(e.target.value)} placeholder="0.1" />
              </div>
              <div>
                <label className="text-xs text-gray-400 block mb-1">Decrement Interval (s)</label>
                <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" type="number" value={decrInterval} onChange={e => setDecrInterval(e.target.value)} placeholder="3600" />
              </div>
            </div>
          )}

          {auctionType === 'sealed' && (
            <div>
              <label className="text-xs text-gray-400 block mb-1">Reserve Price (ETH)</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" type="number" value={reservePrice} onChange={e => setReservePrice(e.target.value)} placeholder="1.0" />
            </div>
          )}

          <button
            onClick={handleCreate}
            disabled={(creatingDutch || creatingSealed) || !isConnected || !bondName}
            className="w-full bg-amber-600 hover:bg-amber-700 disabled:opacity-50 text-white font-medium py-2 rounded"
          >
            {(creatingDutch || creatingSealed) ? 'Creating…' : (dutchCreated || sealedCreated) ? 'Auction Created!' : 'Create Auction'}
          </button>
        </div>
      )}

      {/* Place Bid */}
      {tab === 'bid' && (
        <div className="space-y-4 max-w-lg">
          <div className="bg-white/5 rounded-xl p-5 border border-white/10 space-y-4">
            <h3 className="font-semibold text-white">Place Bid</h3>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Auction ID</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" type="number" value={bidAuctionId} onChange={e => setBidAuctionId(e.target.value)} placeholder="1" />
            </div>
            {bidAuctionId && currentPrice !== undefined && (
              <div className="text-sm text-amber-300">Current Dutch price: {formatEther(currentPrice as bigint)} ETH/unit</div>
            )}
            <div>
              <label className="text-xs text-gray-400 block mb-1">Quantity (units)</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" type="number" value={bidQty} onChange={e => setBidQty(e.target.value)} placeholder="10" />
            </div>
            <button
              onClick={() => bidAuctionId && bidQty && dutchBid(safeBig(bidAuctionId), safeBig(bidQty))}
              disabled={bidding || !isConnected || !bidAuctionId || !bidQty}
              className="w-full bg-amber-600 hover:bg-amber-700 disabled:opacity-50 text-white font-medium py-2 rounded"
            >
              {bidding ? 'Bidding…' : 'Dutch Bid (buy at current price)'}
            </button>
          </div>
          <div className="bg-white/5 rounded-xl p-5 border border-white/10 space-y-4">
            <h3 className="font-semibold text-white">Sealed Bid</h3>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Your Bid Price (ETH)</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" type="number" value={sealedPrice} onChange={e => setSealedPrice(e.target.value)} placeholder="1.2" />
            </div>
            <button
              onClick={() => bidAuctionId && sealedPrice && bidQty && sealedBid(safeBig(bidAuctionId), safeEther(sealedPrice), safeBig(bidQty))}
              disabled={sealedBidding || !isConnected || !bidAuctionId || !sealedPrice || !bidQty}
              className="w-full bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white font-medium py-2 rounded"
            >
              {sealedBidding ? 'Submitting…' : 'Submit Sealed Bid'}
            </button>
            <button
              onClick={() => bidAuctionId && settleSealedAuction(BigInt(bidAuctionId))}
              disabled={settling || !isConnected || !bidAuctionId}
              className="w-full bg-green-600 hover:bg-green-700 disabled:opacity-50 text-white font-medium py-2 rounded"
            >
              {settling ? 'Settling…' : 'Settle Auction (owner/time-expired)'}
            </button>
          </div>
        </div>
      )}

      {/* Lookup */}
      {tab === 'lookup' && (
        <div className="space-y-4">
          <div className="flex gap-3 max-w-md">
            <input
              className="flex-1 bg-white/10 text-white rounded px-3 py-2 border border-white/20"
              placeholder="Auction ID"
              value={lookupId}
              onChange={e => setLookupId(e.target.value)}
              type="number"
            />
            <button onClick={() => refetchAuction()} className="bg-amber-600 hover:bg-amber-700 text-white px-4 py-2 rounded">Lookup</button>
          </div>

          {!!lookupAuction && (lookupAuction as { auctionId: bigint }).auctionId > 0n && ((): React.ReactElement | null => {
            const a = lookupAuction as {
              auctionId: bigint; auctionType: number; status: number;
              issuer: string; bondName: string; bondISIN: string;
              faceValue: bigint; totalSupply: bigint; currentPrice: bigint;
              startPrice: bigint; minPrice: bigint; totalRaised: bigint;
              unitsSold: bigint; winner: string; winningBid: bigint;
              endTime: bigint;
            };
            return (
              <div className="bg-white/5 rounded-xl p-5 border border-white/10 space-y-3 max-w-lg">
                <div className="flex items-center justify-between">
                  <span className="font-semibold text-white">{a.bondName} (#{a.auctionId.toString()})</span>
                  <div className="flex gap-2">
                    <span className="text-xs px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-300">{AUCTION_TYPE[a.auctionType]}</span>
                    <span className={`text-xs px-2 py-0.5 rounded-full ${STATUS_COLORS[a.status] ?? ''}`}>{AUCTION_STATUS[a.status]}</span>
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-2 text-sm">
                  <div><span className="text-gray-400">ISIN:</span> <span className="text-white">{a.bondISIN}</span></div>
                  <div><span className="text-gray-400">Face Value:</span> <span className="text-white">{formatEther(a.faceValue)} ETH</span></div>
                  <div><span className="text-gray-400">Supply:</span> <span className="text-white">{a.totalSupply.toString()}</span></div>
                  <div><span className="text-gray-400">Sold:</span> <span className="text-white">{a.unitsSold.toString()}</span></div>
                  <div><span className="text-gray-400">Current Price:</span> <span className="text-white">{formatEther(a.currentPrice)} ETH</span></div>
                  <div><span className="text-gray-400">Raised:</span> <span className="text-white">{formatEther(a.totalRaised)} ETH</span></div>
                  {a.winner !== '0x0000000000000000000000000000000000000000' && (
                    <div className="col-span-2"><span className="text-gray-400">Winner:</span> <span className="text-white font-mono text-xs">{a.winner}</span></div>
                  )}
                </div>
              </div>
            );
          })()}
        </div>
      )}
    </div>
  );
}
