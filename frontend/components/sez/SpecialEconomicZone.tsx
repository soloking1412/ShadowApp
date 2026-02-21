'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatEther, parseEther } from 'viem';
const safeEther = (v: string) => { try { return parseEther(v || '0'); } catch { return 0n; } };
const safeBig   = (v: string) => { try { return v ? BigInt(v) : 0n; } catch { return 0n; } };
import {
  useSEZStats,
  useGetSEZ,
  useGetZoneStats,
  useGetOwnerEnterprises,
  useEstablishSEZ,
  useRegisterEnterprise,
  SEZ_TYPES,
  ZONE_STATUSES,
} from '@/hooks/contracts/useSpecialEconomicZone';

type Tab = 'overview' | 'establish' | 'register' | 'lookup';

const SEZ_ICONS: Record<string, string> = {
  FreeTradeZone: '🏪',
  ExportProcessing: '📦',
  TechPark: '💻',
  FinancialHub: '🏦',
  IndustrialZone: '⚙️',
  MixedUse: '🌆',
};

const STATUS_COLORS: Record<string, string> = {
  Proposed: 'text-gray-400 bg-gray-500/20 border-gray-500/30',
  Approved: 'text-blue-400 bg-blue-500/20 border-blue-500/30',
  UnderConstruction: 'text-amber-400 bg-amber-500/20 border-amber-500/30',
  Operational: 'text-green-400 bg-green-500/20 border-green-500/30',
  Suspended: 'text-orange-400 bg-orange-500/20 border-orange-500/30',
  Closed: 'text-red-400 bg-red-500/20 border-red-500/30',
};

export default function SpecialEconomicZoneDashboard() {
  const { address } = useAccount();
  const [tab, setTab] = useState<Tab>('overview');

  const { zoneCount, enterpriseCount, totalInvestment, totalEmployment } = useSEZStats();
  const { data: myEnterprises } = useGetOwnerEnterprises(address);
  const myEnterpriseIds = myEnterprises as bigint[] | undefined;

  // Establish SEZ form
  const [zoneType, setZoneType] = useState(0);
  const [zoneName, setZoneName] = useState('');
  const [location, setLocation] = useState('');
  const [zoneCountry, setZoneCountry] = useState('');
  const [portCode, setPortCode] = useState('');
  const [area, setArea] = useState('');
  const [allowedActivities, setAllowedActivities] = useState('');

  // Register enterprise form
  const [enterpriseZoneId, setEnterpriseZoneId] = useState('');
  const [companyName, setCompanyName] = useState('');
  const [regNumber, setRegNumber] = useState('');
  const [industry, setIndustry] = useState('');
  const [investment, setInvestment] = useState('');
  const [employees, setEmployees] = useState('');
  const [licenseDuration, setLicenseDuration] = useState('365');

  // Lookup
  const [lookupZoneId, setLookupZoneId] = useState('');
  const parsedZoneId = (() => { try { return lookupZoneId ? BigInt(lookupZoneId) : undefined; } catch { return undefined; } })();
  const { data: zoneData } = useGetSEZ(parsedZoneId);
  const { data: zoneStats } = useGetZoneStats(parsedZoneId);

  const { establishSEZ, isPending: establishing, isConfirming: estConfirming, isSuccess: estSuccess, error: estError } = useEstablishSEZ();
  const { registerEnterprise, isPending: registering, isConfirming: regConfirming, isSuccess: regSuccess, error: regError } = useRegisterEnterprise();

  const handleEstablish = () => {
    if (!zoneName || !location || !zoneCountry) return;
    const activities = allowedActivities
      ? allowedActivities.split(',').map((s) => s.trim()).filter(Boolean)
      : [];
    establishSEZ(zoneType, zoneName, location, zoneCountry, portCode, area ? BigInt(area) : 0n, activities);
  };

  const handleRegister = () => {
    if (!enterpriseZoneId || !companyName || !regNumber || !investment) return;
    registerEnterprise(
      safeBig(enterpriseZoneId),
      companyName,
      regNumber,
      industry,
      safeEther(investment),
      safeBig(employees),
      safeBig(licenseDuration),
    );
  };

  const zone = zoneData as any;
  const stats = zoneStats as any;

  const TABS: { id: Tab; label: string }[] = [
    { id: 'overview', label: 'Overview' },
    { id: 'establish', label: 'Establish Zone' },
    { id: 'register', label: 'Register Enterprise' },
    { id: 'lookup', label: 'Zone Lookup' },
  ];

  return (
    <div className="space-y-6">
      <div className="glass rounded-xl p-6">
        <h2 className="text-2xl font-bold text-white mb-1">Special Economic Zones</h2>
        <p className="text-gray-400">
          On-chain SEZ registry — free trade zones, export processing, tech parks, and financial hubs
        </p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Active Zones</p>
          <p className="text-3xl font-bold text-white">{zoneCount?.toString() ?? '—'}</p>
          <p className="text-xs text-blue-400 mt-1">SEZs registered</p>
        </div>
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Enterprises</p>
          <p className="text-3xl font-bold text-white">{enterpriseCount?.toString() ?? '—'}</p>
          <p className="text-xs text-green-400 mt-1">Licensed companies</p>
        </div>
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Total Investment</p>
          <p className="text-2xl font-bold text-white">
            {totalInvestment ? `${parseFloat(formatEther(totalInvestment as bigint)).toLocaleString()} ETH` : '—'}
          </p>
          <p className="text-xs text-purple-400 mt-1">Capital deployed</p>
        </div>
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Employment</p>
          <p className="text-3xl font-bold text-white">
            {totalEmployment ? Number(totalEmployment).toLocaleString() : '—'}
          </p>
          <p className="text-xs text-amber-400 mt-1">Jobs created</p>
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
              <h3 className="text-lg font-bold text-white">Zone Types</h3>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                {SEZ_TYPES.map((type, i) => (
                  <div
                    key={type}
                    className="p-4 bg-white/5 border border-white/10 rounded-lg hover:bg-white/10 transition-all cursor-pointer text-center"
                    onClick={() => { setZoneType(i); setTab('establish'); }}
                  >
                    <p className="text-3xl mb-2">{SEZ_ICONS[type] ?? '🏗️'}</p>
                    <p className="text-sm text-white font-medium">{type}</p>
                  </div>
                ))}
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                <div className="p-4 bg-green-500/10 border border-green-500/20 rounded-lg">
                  <p className="text-sm font-semibold text-white mb-2">Zone Status Lifecycle</p>
                  <div className="space-y-1">
                    {ZONE_STATUSES.map((status) => (
                      <div key={status} className="flex items-center gap-2">
                        <span className={`px-2 py-0.5 text-xs rounded border ${STATUS_COLORS[status]}`}>
                          {status}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="p-4 bg-blue-500/10 border border-blue-500/20 rounded-lg">
                  <p className="text-sm font-semibold text-white mb-2">SEZ Benefits</p>
                  <ul className="space-y-1 text-xs text-gray-400">
                    <li>• Duty-free import/export of goods</li>
                    <li>• Tax incentives for licensed enterprises</li>
                    <li>• Streamlined customs clearance</li>
                    <li>• Infrastructure cost sharing</li>
                    <li>• On-chain enterprise registry</li>
                    <li>• Employment and investment tracking</li>
                  </ul>
                </div>
              </div>

              {/* My enterprises */}
              {address && myEnterpriseIds && myEnterpriseIds.length > 0 && (
                <div className="p-4 bg-white/5 border border-white/10 rounded-lg">
                  <p className="text-sm font-semibold text-white mb-3">My Enterprise Registrations</p>
                  <div className="flex flex-wrap gap-2">
                    {myEnterpriseIds.map((id) => (
                      <span
                        key={id.toString()}
                        className="px-3 py-1 text-sm bg-primary-500/20 border border-primary-500/30 rounded-lg text-primary-300"
                      >
                        Enterprise #{id.toString()}
                      </span>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}

          {tab === 'establish' && (
            <div className="space-y-4 max-w-lg">
              <h3 className="text-lg font-bold text-white">Establish Special Economic Zone</h3>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Zone Type</label>
                <select
                  value={zoneType}
                  onChange={(e) => setZoneType(Number(e.target.value))}
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
                >
                  {SEZ_TYPES.map((t, i) => (
                    <option key={t} value={i}>{SEZ_ICONS[t]} {t}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Zone Name</label>
                <input
                  value={zoneName}
                  onChange={(e) => setZoneName(e.target.value)}
                  placeholder="e.g. Lekki Free Trade Zone"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Location</label>
                <input
                  value={location}
                  onChange={(e) => setLocation(e.target.value)}
                  placeholder="e.g. Lekki Peninsula, Lagos"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Country</label>
                  <input
                    value={zoneCountry}
                    onChange={(e) => setZoneCountry(e.target.value)}
                    placeholder="Nigeria"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Port Code</label>
                  <input
                    value={portCode}
                    onChange={(e) => setPortCode(e.target.value.toUpperCase())}
                    placeholder="NGAPP"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Area (hectares)</label>
                <input
                  type="number"
                  value={area}
                  onChange={(e) => setArea(e.target.value)}
                  placeholder="3000"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Allowed Activities (comma-separated)</label>
                <input
                  value={allowedActivities}
                  onChange={(e) => setAllowedActivities(e.target.value)}
                  placeholder="Manufacturing, Logistics, Assembly, Warehousing"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <button
                onClick={handleEstablish}
                disabled={establishing || estConfirming || !address || !zoneName || !location || !zoneCountry}
                className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {establishing || estConfirming ? 'Establishing Zone...' : estSuccess ? 'Zone Established!' : 'Establish SEZ'}
              </button>

              {estError && (
                <p className="text-xs text-red-400 bg-red-500/10 border border-red-500/20 rounded-lg p-3">
                  {estError.message}
                </p>
              )}
            </div>
          )}

          {tab === 'register' && (
            <div className="space-y-4 max-w-lg">
              <h3 className="text-lg font-bold text-white">Register Enterprise in SEZ</h3>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Zone ID</label>
                <input
                  type="number"
                  value={enterpriseZoneId}
                  onChange={(e) => setEnterpriseZoneId(e.target.value)}
                  placeholder="Zone ID"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Company Name</label>
                  <input
                    value={companyName}
                    onChange={(e) => setCompanyName(e.target.value)}
                    placeholder="Acme Industries Ltd"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Registration No.</label>
                  <input
                    value={regNumber}
                    onChange={(e) => setRegNumber(e.target.value)}
                    placeholder="RC-123456"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Industry</label>
                <input
                  value={industry}
                  onChange={(e) => setIndustry(e.target.value)}
                  placeholder="e.g. Electronics Manufacturing"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Investment (ETH)</label>
                  <input
                    type="number"
                    value={investment}
                    onChange={(e) => setInvestment(e.target.value)}
                    placeholder="500"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Initial Employees</label>
                  <input
                    type="number"
                    value={employees}
                    onChange={(e) => setEmployees(e.target.value)}
                    placeholder="250"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">License Duration (days)</label>
                <input
                  type="number"
                  value={licenseDuration}
                  onChange={(e) => setLicenseDuration(e.target.value)}
                  placeholder="365"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <button
                onClick={handleRegister}
                disabled={registering || regConfirming || !address || !enterpriseZoneId || !companyName || !investment}
                className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {registering || regConfirming ? 'Registering...' : regSuccess ? 'Enterprise Registered!' : 'Register Enterprise'}
              </button>

              {regError && (
                <p className="text-xs text-red-400 bg-red-500/10 border border-red-500/20 rounded-lg p-3">
                  {regError.message}
                </p>
              )}
            </div>
          )}

          {tab === 'lookup' && (
            <div className="space-y-4 max-w-lg">
              <h3 className="text-lg font-bold text-white">Zone Lookup</h3>
              <input
                type="number"
                value={lookupZoneId}
                onChange={(e) => setLookupZoneId(e.target.value)}
                placeholder="Zone ID"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />

              {zone && (
                <div className="space-y-3">
                  <div className="p-4 bg-white/5 border border-white/10 rounded-lg space-y-2 text-sm">
                    <div className="flex items-center gap-2 mb-2">
                      <span className="text-2xl">{SEZ_ICONS[SEZ_TYPES[zone.zoneType] ?? ''] ?? '🏗️'}</span>
                      <span className="text-white font-bold text-lg">{zone.name}</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-gray-400">Status</span>
                      <span className={`px-2 py-0.5 text-xs rounded border ${STATUS_COLORS[ZONE_STATUSES[zone.status] ?? ''] ?? ''}`}>
                        {ZONE_STATUSES[zone.status]}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-400">Type</span>
                      <span className="text-blue-400">{SEZ_TYPES[zone.zoneType]}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-400">Location</span>
                      <span className="text-white">{zone.location}, {zone.country}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-400">Area</span>
                      <span className="text-green-400">{zone.area?.toString()} ha</span>
                    </div>
                    {zone.portCode && (
                      <div className="flex justify-between">
                        <span className="text-gray-400">Port Code</span>
                        <span className="text-white font-mono">{zone.portCode}</span>
                      </div>
                    )}
                  </div>

                  {stats && (
                    <div className="p-4 bg-white/5 border border-white/10 rounded-lg space-y-2 text-sm">
                      <p className="text-white font-semibold mb-2">Zone Statistics</p>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Enterprises</span>
                        <span className="text-white">{stats.enterpriseCount?.toString()}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Total Investment</span>
                        <span className="text-green-400">{formatEther(stats.totalInvestment ?? 0n)} ETH</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Employment</span>
                        <span className="text-purple-400">{stats.totalEmployment?.toString()} jobs</span>
                      </div>
                    </div>
                  )}
                </div>
              )}
              {lookupZoneId && !zone && (
                <p className="text-gray-400 text-sm text-center py-4">Zone #{lookupZoneId} not found.</p>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
