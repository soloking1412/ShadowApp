'use client';

import { useState, useEffect } from 'react';
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

  const [txError, setTxError] = useState<string|null>(null);
  const [txSuccess, setTxSuccess] = useState<string|null>(null);
  useEffect(() => {
    const err = registerError ?? estError;
    if (!err) return;
    const msg = (err as {shortMessage?:string})?.shortMessage ?? (err as {message?:string})?.message ?? 'Transaction failed';
    setTxError(msg.length > 120 ? msg.slice(0, 120) + '…' : msg);
    const t = setTimeout(() => setTxError(null), 7000);
    return () => clearTimeout(t);
  }, [registerError, estError]);
  useEffect(() => {
    if (registerSuccess) { setTxSuccess('Infrastructure asset registered — logistics node added to network'); }
    else if (estSuccess) { setTxSuccess('Trade corridor established — route active on global network'); }
    else return;
    const t = setTimeout(() => setTxSuccess(null), 5000);
    return () => clearTimeout(t);
  }, [registerSuccess, estSuccess]);

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

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const asset = assetData as any;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const corridor = corridorData as any;

  const TABS: { id: Tab; label: string }[] = [
    { id: 'overview', label: 'Overview' },
    { id: 'register', label: 'Register Asset' },
    { id: 'corridor', label: 'Establish Corridor' },
    { id: 'lookup', label: 'Lookup' },
  ];

  return (
    <div className="space-y-6">
      {txError && (
        <div className="flex items-start gap-3 px-4 py-3 bg-red-900/40 border border-red-500/40 rounded-xl text-sm">
          <span className="text-red-400 shrink-0 mt-0.5">✕</span>
          <div className="flex-1"><p className="font-semibold text-red-300">Transaction failed</p><p className="text-red-400/80 text-xs mt-0.5">{txError}</p></div>
          <button onClick={() => setTxError(null)} className="text-red-500 hover:text-red-300 text-xs shrink-0">dismiss</button>
        </div>
      )}
      {txSuccess && (
        <div className="flex items-center gap-2 px-4 py-3 bg-green-900/30 border border-green-500/30 rounded-xl text-sm">
          <span className="text-green-400">✓</span><p className="text-green-300 font-semibold">{txSuccess}</p>
        </div>
      )}
      <div className="bg-gradient-to-r from-slate-900/60 to-zinc-900/60 border border-slate-700/50 rounded-xl p-6 space-y-4">
        <div>
          <h2 className="text-2xl font-bold text-white">Infrastructure Assets Registry</h2>
          <p className="text-gray-400 mt-1 text-sm">Global logistics network — ports, airports, rail terminals, warehouses and trade corridors · IATA/LOCODE codes · GPS routing · SEZ integration</p>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {[
            { label: 'Registered Assets', value: assetCount?.toString() ?? '0' },
            { label: 'Active Corridors', value: corridorCount?.toString() ?? '0' },
            { label: 'Freight Value (ETH)', value: totalFreightValue ? parseFloat(formatEther(totalFreightValue as bigint)).toLocaleString() : '0' },
            { label: 'Asset Types', value: String(ASSET_TYPES.length) },
          ].map(s => (
            <div key={s.label} className="bg-white/5 border border-white/10 rounded-lg p-3 text-center">
              <div className="text-white font-bold text-lg">{s.value}</div>
              <div className="text-gray-400 text-xs mt-0.5">{s.label}</div>
            </div>
          ))}
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
