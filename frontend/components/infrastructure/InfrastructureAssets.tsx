'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatEther } from 'viem';
import {
  useInfraStats,
  useGetAssetByCode,
  useGetCorridor,
  useRegisterAsset,
  useEstablishCorridor,
  ASSET_TYPES,
} from '@/hooks/contracts/useInfrastructureAssets';

type Tab = 'overview' | 'register' | 'corridor' | 'lookup';

const ASSET_ICONS: Record<string, string> = {
  Port: '⚓',
  Airport: '✈️',
  RailTerminal: '🚉',
  RoadHub: '🛣️',
  WarehouseComplex: '🏭',
  PipelineStation: '🔧',
  BorderCrossing: '🛂',
  FreeTradeZone: '🏪',
};

export default function InfrastructureAssetsDashboard() {
  const { address } = useAccount();
  const [tab, setTab] = useState<Tab>('overview');

  const { assetCount, corridorCount, totalFreightValue } = useInfraStats();

  // Register asset form
  const [assetType, setAssetType] = useState(0);
  const [assetName, setAssetName] = useState('');
  const [code, setCode] = useState('');
  const [country, setCountry] = useState('');
  const [city, setCity] = useState('');
  const [coordinates, setCoordinates] = useState('');
  const [capacity, setCapacity] = useState('');
  const [connectedCorridors, setConnectedCorridors] = useState('');
  const [sezEnabled, setSezEnabled] = useState(false);

  // Corridor form
  const [corridorName, setCorridorName] = useState('');
  const [originCode, setOriginCode] = useState('');
  const [destCode, setDestCode] = useState('');
  const [distance, setDistance] = useState('');
  const [transitTime, setTransitTime] = useState('');

  // Lookup
  const [lookupCode, setLookupCode] = useState('');
  const [lookupCorridorId, setLookupCorridorId] = useState('');
  const parsedCorridorId = (() => { try { return lookupCorridorId ? BigInt(lookupCorridorId) : undefined; } catch { return undefined; } })();
  const { data: assetData } = useGetAssetByCode(lookupCode || undefined);
  const { data: corridorData } = useGetCorridor(parsedCorridorId);

  const { registerAsset, isPending: registering, isConfirming: registerConfirming, isSuccess: registerSuccess, error: registerError } = useRegisterAsset();
  const { establishCorridor, isPending: establishing, isConfirming: estConfirming, isSuccess: estSuccess, error: estError } = useEstablishCorridor();

  const handleRegister = () => {
    if (!assetName || !code || !country) return;
    const corridorList = connectedCorridors
      ? connectedCorridors.split(',').map((s) => s.trim()).filter(Boolean)
      : [];
    registerAsset(
      assetType, assetName, code, country, city, coordinates,
      capacity ? BigInt(capacity) : 0n,
      corridorList, sezEnabled,
    );
  };

  const handleEstablishCorridor = () => {
    if (!corridorName || !originCode || !destCode) return;
    establishCorridor(
      corridorName, originCode, destCode,
      [], // transitAssets — simplified
      [0, 1, 2], // supportedTypes — default all
      distance ? BigInt(distance) : 0n,
      transitTime ? BigInt(transitTime) : 0n,
    );
  };

  const asset = assetData as any;
  const corridor = corridorData as any;

  const TABS: { id: Tab; label: string }[] = [
    { id: 'overview', label: 'Overview' },
    { id: 'register', label: 'Register Asset' },
    { id: 'corridor', label: 'Establish Corridor' },
    { id: 'lookup', label: 'Lookup' },
  ];

  return (
    <div className="space-y-6">
      <div className="glass rounded-xl p-6">
        <h2 className="text-2xl font-bold text-white mb-1">Infrastructure Assets Registry</h2>
        <p className="text-gray-400">
          Global logistics network — ports, airports, rail terminals, warehouses and trade corridors
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Registered Assets</p>
          <p className="text-3xl font-bold text-white">{assetCount?.toString() ?? '—'}</p>
          <p className="text-xs text-blue-400 mt-1">Global infrastructure nodes</p>
        </div>
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Active Corridors</p>
          <p className="text-3xl font-bold text-white">{corridorCount?.toString() ?? '—'}</p>
          <p className="text-xs text-green-400 mt-1">Trade route connections</p>
        </div>
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Total Freight Value</p>
          <p className="text-3xl font-bold text-white">
            {totalFreightValue ? `${parseFloat(formatEther(totalFreightValue as bigint)).toLocaleString()} ETH` : '—'}
          </p>
          <p className="text-xs text-purple-400 mt-1">Goods in transit</p>
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
              <h3 className="text-lg font-bold text-white">Asset Categories</h3>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                {ASSET_TYPES.map((type, i) => (
                  <div
                    key={type}
                    className="p-4 bg-white/5 border border-white/10 rounded-lg hover:bg-white/10 transition-all cursor-pointer text-center"
                    onClick={() => { setAssetType(i); setTab('register'); }}
                  >
                    <p className="text-2xl mb-2">{ASSET_ICONS[type] ?? '🏗️'}</p>
                    <p className="text-xs text-white font-medium">{type}</p>
                  </div>
                ))}
              </div>

              <div className="p-4 bg-blue-500/10 border border-blue-500/20 rounded-lg mt-4">
                <p className="text-sm font-semibold text-white mb-2">Logistics Network Features</p>
                <ul className="space-y-1 text-xs text-gray-400">
                  <li>• IATA/IATA airport codes and port LOCODE</li>
                  <li>• GPS coordinates for routing optimization</li>
                  <li>• Capacity tracking in TEU/ton equivalent</li>
                  <li>• Multi-modal corridor routing</li>
                  <li>• SEZ zone integration for duty-free handling</li>
                </ul>
              </div>
            </div>
          )}

          {tab === 'register' && (
            <div className="space-y-4 max-w-lg">
              <h3 className="text-lg font-bold text-white">Register Infrastructure Asset</h3>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Asset Type</label>
                <select
                  value={assetType}
                  onChange={(e) => setAssetType(Number(e.target.value))}
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
                >
                  {ASSET_TYPES.map((t, i) => (
                    <option key={t} value={i}>{ASSET_ICONS[t]} {t}</option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Asset Name</label>
                  <input
                    value={assetName}
                    onChange={(e) => setAssetName(e.target.value)}
                    placeholder="Lagos Apapa Port"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Code (LOCODE/IATA)</label>
                  <input
                    value={code}
                    onChange={(e) => setCode(e.target.value.toUpperCase())}
                    placeholder="NGAPP"
                    maxLength={8}
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Country</label>
                  <input
                    value={country}
                    onChange={(e) => setCountry(e.target.value)}
                    placeholder="Nigeria"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">City</label>
                  <input
                    value={city}
                    onChange={(e) => setCity(e.target.value)}
                    placeholder="Lagos"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Coordinates</label>
                  <input
                    value={coordinates}
                    onChange={(e) => setCoordinates(e.target.value)}
                    placeholder="6.4531,3.3958"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono text-xs"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Capacity (TEU/ton)</label>
                  <input
                    type="number"
                    value={capacity}
                    onChange={(e) => setCapacity(e.target.value)}
                    placeholder="2000000"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Connected Corridors (comma-separated codes)</label>
                <input
                  value={connectedCorridors}
                  onChange={(e) => setConnectedCorridors(e.target.value)}
                  placeholder="NGAPP, GHTEM, ZACRG"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <label className="flex items-center gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={sezEnabled}
                  onChange={(e) => setSezEnabled(e.target.checked)}
                  className="w-4 h-4 accent-primary-500"
                />
                <span className="text-sm text-gray-300">Enable SEZ capabilities</span>
              </label>

              <button
                onClick={handleRegister}
                disabled={registering || registerConfirming || !address || !assetName || !code || !country}
                className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {registering || registerConfirming ? 'Registering...' : registerSuccess ? 'Asset Registered!' : 'Register Asset'}
              </button>

              {registerError && (
                <p className="text-xs text-red-400 bg-red-500/10 border border-red-500/20 rounded-lg p-3">
                  {registerError.message}
                </p>
              )}
            </div>
          )}

          {tab === 'corridor' && (
            <div className="space-y-4 max-w-lg">
              <h3 className="text-lg font-bold text-white">Establish Trade Corridor</h3>
              <p className="text-sm text-gray-400">Connect two asset nodes into an active trade lane.</p>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Corridor Name</label>
                <input
                  value={corridorName}
                  onChange={(e) => setCorridorName(e.target.value)}
                  placeholder="West Africa Atlantic Corridor"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Origin Code</label>
                  <input
                    value={originCode}
                    onChange={(e) => setOriginCode(e.target.value.toUpperCase())}
                    placeholder="NGAPP"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Destination Code</label>
                  <input
                    value={destCode}
                    onChange={(e) => setDestCode(e.target.value.toUpperCase())}
                    placeholder="GHTEM"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Distance (km)</label>
                  <input
                    type="number"
                    value={distance}
                    onChange={(e) => setDistance(e.target.value)}
                    placeholder="850"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Avg Transit (hours)</label>
                  <input
                    type="number"
                    value={transitTime}
                    onChange={(e) => setTransitTime(e.target.value)}
                    placeholder="72"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
              </div>

              <button
                onClick={handleEstablishCorridor}
                disabled={establishing || estConfirming || !address || !corridorName || !originCode || !destCode}
                className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {establishing || estConfirming ? 'Establishing...' : estSuccess ? 'Corridor Established!' : 'Establish Corridor'}
              </button>

              {estError && (
                <p className="text-xs text-red-400 bg-red-500/10 border border-red-500/20 rounded-lg p-3">
                  {estError.message}
                </p>
              )}
            </div>
          )}

          {tab === 'lookup' && (
            <div className="space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-3">
                  <h3 className="text-lg font-bold text-white">Asset Lookup</h3>
                  <input
                    value={lookupCode}
                    onChange={(e) => setLookupCode(e.target.value.toUpperCase())}
                    placeholder="LOCODE / IATA code"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono"
                  />
                  {asset && (
                    <div className="p-4 bg-white/5 border border-white/10 rounded-lg space-y-2 text-sm">
                      <div className="flex items-center gap-2 mb-2">
                        <span className="text-2xl">{ASSET_ICONS[ASSET_TYPES[asset.assetType] ?? ''] ?? '🏗️'}</span>
                        <span className="text-white font-bold text-lg">{asset.name}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Type</span>
                        <span className="text-blue-400">{ASSET_TYPES[asset.assetType]}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Location</span>
                        <span className="text-white">{asset.city}, {asset.country}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Capacity</span>
                        <span className="text-green-400">{asset.capacity?.toString()}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">SEZ Enabled</span>
                        <span className={asset.sezEnabled ? 'text-green-400' : 'text-gray-400'}>
                          {asset.sezEnabled ? 'Yes' : 'No'}
                        </span>
                      </div>
                    </div>
                  )}
                  {lookupCode && !asset && (
                    <p className="text-gray-400 text-sm">Asset {lookupCode} not found.</p>
                  )}
                </div>

                <div className="space-y-3">
                  <h3 className="text-lg font-bold text-white">Corridor Lookup</h3>
                  <input
                    type="number"
                    value={lookupCorridorId}
                    onChange={(e) => setLookupCorridorId(e.target.value)}
                    placeholder="Corridor ID"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                  {corridor && (
                    <div className="p-4 bg-white/5 border border-white/10 rounded-lg space-y-2 text-sm">
                      <div className="text-white font-bold">{corridor.name}</div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Route</span>
                        <span className="text-white font-mono">{corridor.originCode} → {corridor.destinationCode}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Distance</span>
                        <span className="text-blue-400">{corridor.distance?.toString()} km</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Transit Time</span>
                        <span className="text-purple-400">{corridor.averageTransitTime?.toString()} hrs</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Active</span>
                        <span className={corridor.active ? 'text-green-400' : 'text-red-400'}>
                          {corridor.active ? 'Yes' : 'No'}
                        </span>
                      </div>
                    </div>
                  )}
                  {lookupCorridorId && !corridor && (
                    <p className="text-gray-400 text-sm">Corridor #{lookupCorridorId} not found.</p>
                  )}
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
