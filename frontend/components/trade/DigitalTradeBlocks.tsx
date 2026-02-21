'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatEther, parseEther } from 'viem';
import {
  useBlockCounter,
  useTotalTradeBlockValue,
  useGetTradeBlock,
  useGetOwnerBlocks,
  useCreateTradeBlock,
  useOfferTradeBlock,
  BLOCK_TYPES,
} from '@/hooks/contracts/useDigitalTradeBlocks';

type Tab = 'overview' | 'create' | 'my-blocks' | 'lookup';

const TYPE_COLORS: Record<string, string> = {
  Infrastructure: 'text-blue-400',
  Commodities: 'text-amber-400',
  Energy: 'text-orange-400',
  Technology: 'text-purple-400',
  Agriculture: 'text-green-400',
  Logistics: 'text-cyan-400',
};

export default function DigitalTradeBlocksDashboard() {
  const { address } = useAccount();
  const [tab, setTab] = useState<Tab>('overview');

  const { data: blockCount } = useBlockCounter();
  const { data: totalValue } = useTotalTradeBlockValue();
  const { data: ownerBlocks } = useGetOwnerBlocks(address);
  const ownedIds = ownerBlocks as bigint[] | undefined;

  // Create form
  const [blockType, setBlockType] = useState(0);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [faceValue, setFaceValue] = useState('');
  const [maturityDays, setMaturityDays] = useState('');
  const [yieldRate, setYieldRate] = useState('');
  const [underlyingAssets, setUnderlyingAssets] = useState('');
  const [minInvestment, setMinInvestment] = useState('');
  const [jurisdiction, setJurisdiction] = useState('');
  const [fractional, setFractional] = useState(false);

  // Offer
  const [offerTokenId, setOfferTokenId] = useState('');
  const [offerPrice, setOfferPrice] = useState('');
  const [offerExpiry] = useState('30');

  // Lookup
  const [lookupId, setLookupId] = useState('');
  const parsedLookup = lookupId ? BigInt(lookupId) : undefined;
  const { data: blockData } = useGetTradeBlock(parsedLookup);

  const { createTradeBlock, isPending: creating, isConfirming: createConfirming, isSuccess: createSuccess, error: createError } = useCreateTradeBlock();
  const { offerTradeBlock, isPending: offering, isConfirming: offerConfirming, isSuccess: offerSuccess } = useOfferTradeBlock();

  const handleCreate = () => {
    if (!name || !faceValue) return;
    const maturity = maturityDays
      ? BigInt(Math.floor(Date.now() / 1000) + Number(maturityDays) * 86400)
      : BigInt(0);
    createTradeBlock(
      blockType, name, description, parseEther(faceValue), maturity,
      yieldRate ? BigInt(Math.round(parseFloat(yieldRate) * 100)) : 0n,
      underlyingAssets, minInvestment ? parseEther(minInvestment) : 0n,
      jurisdiction, fractional,
    );
  };

  const handleOffer = (tokenId: string) => {
    if (!tokenId || !offerPrice) return;
    offerTradeBlock(BigInt(tokenId), parseEther(offerPrice), BigInt(offerExpiry));
  };

  const block = blockData as any;

  const TABS: { id: Tab; label: string }[] = [
    { id: 'overview', label: 'Overview' },
    { id: 'create', label: 'Create Block' },
    { id: 'my-blocks', label: 'My Blocks' },
    { id: 'lookup', label: 'Block Lookup' },
  ];

  return (
    <div className="space-y-6">
      <div className="glass rounded-xl p-6">
        <h2 className="text-2xl font-bold text-white mb-1">2DI Digital Trade Blocks</h2>
        <p className="text-gray-400">Tokenized trade finance instruments — infrastructure, commodities, energy, and beyond</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Total Blocks Issued</p>
          <p className="text-3xl font-bold text-white">{blockCount?.toString() ?? '—'}</p>
          <p className="text-xs text-blue-400 mt-1">NFT instruments</p>
        </div>
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Total Block Value</p>
          <p className="text-3xl font-bold text-white">
            {totalValue ? `${parseFloat(formatEther(totalValue as bigint)).toLocaleString()} ETH` : '—'}
          </p>
          <p className="text-xs text-green-400 mt-1">Face value total</p>
        </div>
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Asset Classes</p>
          <p className="text-3xl font-bold text-white">{BLOCK_TYPES.length}</p>
          <p className="text-xs text-purple-400 mt-1">Supported categories</p>
        </div>
      </div>

      <div className="glass rounded-xl overflow-hidden">
        <div className="flex border-b border-white/10 overflow-x-auto">
          {TABS.map((t) => (
            <button
              key={t.id}
              onClick={() => setTab(t.id)}
              className={`px-6 py-4 text-sm font-medium whitespace-nowrap transition-colors ${
                tab === t.id ? 'border-b-2 border-primary-500 text-white bg-white/5' : 'text-gray-400 hover:text-white'
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>

        <div className="p-6">
          {tab === 'overview' && (
            <div className="space-y-4">
              <h3 className="text-lg font-bold text-white">Asset Classes</h3>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                {BLOCK_TYPES.map((type, i) => (
                  <div
                    key={type}
                    className="p-4 bg-white/5 border border-white/10 rounded-lg hover:bg-white/10 transition-all cursor-pointer"
                    onClick={() => { setBlockType(i); setTab('create'); }}
                  >
                    <p className="text-xs text-gray-400 mb-1">Type {i}</p>
                    <p className={`font-bold ${TYPE_COLORS[type] ?? 'text-white'}`}>{type}</p>
                  </div>
                ))}
              </div>
              <div className="p-4 bg-blue-500/10 border border-blue-500/20 rounded-lg mt-4">
                <p className="text-sm font-semibold text-white mb-2">2DI Bond Architecture</p>
                <ul className="space-y-1 text-xs text-gray-400">
                  <li>• ERC-1155 multi-token standard — fractional ownership supported</li>
                  <li>• On-chain yield and maturity tracking</li>
                  <li>• Secondary market offering with expiry</li>
                  <li>• Jurisdiction-aware compliance layer</li>
                  <li>• Underlying asset basket documentation</li>
                </ul>
              </div>
            </div>
          )}

          {tab === 'create' && (
            <div className="space-y-4 max-w-lg">
              <h3 className="text-lg font-bold text-white">Create Trade Block</h3>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Asset Class</label>
                <select
                  value={blockType}
                  onChange={(e) => setBlockType(Number(e.target.value))}
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
                >
                  {BLOCK_TYPES.map((t, i) => (
                    <option key={t} value={i}>{t}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Block Name</label>
                <input
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g. Lagos Port Infrastructure Bond"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Description</label>
                <textarea
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Describe the underlying asset and trade structure..."
                  rows={2}
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 resize-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Face Value (ETH)</label>
                  <input
                    type="number"
                    value={faceValue}
                    onChange={(e) => setFaceValue(e.target.value)}
                    placeholder="1000"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Yield Rate (%)</label>
                  <input
                    type="number"
                    value={yieldRate}
                    onChange={(e) => setYieldRate(e.target.value)}
                    placeholder="6.5"
                    step="0.01"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Maturity (days)</label>
                  <input
                    type="number"
                    value={maturityDays}
                    onChange={(e) => setMaturityDays(e.target.value)}
                    placeholder="1825"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Min Investment (ETH)</label>
                  <input
                    type="number"
                    value={minInvestment}
                    onChange={(e) => setMinInvestment(e.target.value)}
                    placeholder="10"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Underlying Assets</label>
                <input
                  value={underlyingAssets}
                  onChange={(e) => setUnderlyingAssets(e.target.value)}
                  placeholder="Port infrastructure, 3 terminals, capacity 2M TEU/yr"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Jurisdiction</label>
                <input
                  value={jurisdiction}
                  onChange={(e) => setJurisdiction(e.target.value)}
                  placeholder="Nigeria"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <label className="flex items-center gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={fractional}
                  onChange={(e) => setFractional(e.target.checked)}
                  className="w-4 h-4 accent-primary-500"
                />
                <span className="text-sm text-gray-300">Enable fractional ownership</span>
              </label>

              <button
                onClick={handleCreate}
                disabled={creating || createConfirming || !address || !name || !faceValue}
                className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {creating || createConfirming ? 'Creating Block...' : createSuccess ? 'Block Created!' : 'Create Trade Block'}
              </button>

              {createError && (
                <p className="text-xs text-red-400 bg-red-500/10 border border-red-500/20 rounded-lg p-3">
                  {createError.message}
                </p>
              )}
            </div>
          )}

          {tab === 'my-blocks' && (
            <div className="space-y-4">
              <h3 className="text-lg font-bold text-white">My Trade Blocks</h3>
              {!address ? (
                <p className="text-gray-400 text-sm">Connect wallet to view your blocks.</p>
              ) : !ownedIds || ownedIds.length === 0 ? (
                <div className="text-center py-10 text-gray-400">
                  <p className="text-4xl mb-3">📦</p>
                  <p>No trade blocks yet. Create your first block in the Create tab.</p>
                </div>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  {ownedIds.map((id) => (
                    <div key={id.toString()} className="p-4 bg-white/5 border border-white/10 rounded-lg">
                      <div className="flex items-center justify-between mb-3">
                        <span className="text-white font-bold">Block #{id.toString()}</span>
                        <button
                          onClick={() => { setLookupId(id.toString()); setTab('lookup'); }}
                          className="text-xs text-primary-400 hover:text-primary-300"
                        >
                          View Details →
                        </button>
                      </div>
                      <div className="border-t border-white/10 pt-3 space-y-2">
                        <p className="text-xs text-gray-400 font-medium">List for Sale</p>
                        <div className="grid grid-cols-2 gap-2">
                          <input
                            type="number"
                            placeholder="Price (ETH)"
                            value={offerTokenId === id.toString() ? offerPrice : ''}
                            onChange={(e) => { setOfferTokenId(id.toString()); }}
                            className="bg-white/5 border border-white/10 rounded px-3 py-2 text-sm text-white placeholder-gray-500 focus:outline-none"
                          />
                          <button
                            onClick={() => handleOffer(id.toString())}
                            disabled={offering || offerConfirming}
                            className="py-2 px-3 bg-green-600 hover:bg-green-700 text-white text-xs font-medium rounded disabled:opacity-50"
                          >
                            {offering || offerConfirming ? 'Listing...' : offerSuccess ? 'Listed!' : 'List'}
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {tab === 'lookup' && (
            <div className="space-y-4 max-w-lg">
              <h3 className="text-lg font-bold text-white">Block Lookup</h3>
              <input
                type="number"
                value={lookupId}
                onChange={(e) => setLookupId(e.target.value)}
                placeholder="Token ID"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
              {block && (
                <div className="p-4 bg-white/5 border border-white/10 rounded-lg space-y-3 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-400">Name</span>
                    <span className="text-white font-semibold">{block.name}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Type</span>
                    <span className={TYPE_COLORS[BLOCK_TYPES[block.blockType] ?? ''] ?? 'text-white'}>
                      {BLOCK_TYPES[block.blockType]}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Face Value</span>
                    <span className="text-green-400">{formatEther(block.faceValue ?? 0n)} ETH</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Yield Rate</span>
                    <span className="text-white">{(Number(block.yieldRate ?? 0) / 100).toFixed(2)}%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Jurisdiction</span>
                    <span className="text-blue-400">{block.jurisdiction}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Fractional</span>
                    <span className={block.fractional ? 'text-green-400' : 'text-gray-400'}>
                      {block.fractional ? 'Yes' : 'No'}
                    </span>
                  </div>
                  {block.underlyingAssets && (
                    <div className="pt-2 border-t border-white/10">
                      <p className="text-gray-400 text-xs mb-1">Underlying Assets</p>
                      <p className="text-white text-xs">{block.underlyingAssets}</p>
                    </div>
                  )}
                </div>
              )}
              {lookupId && !block && (
                <p className="text-gray-400 text-sm text-center py-4">Block #{lookupId} not found.</p>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
