'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatEther, parseEther } from 'viem';
const safeEther = (v: string) => { try { return parseEther(v || '0'); } catch { return 0n; } };
import {
  useArmsStats,
  useGetLicense,
  useGetExporterLicenses,
  useApplyForLicense,
  usePerformSanctionsCheck,
  COMMODITY_TYPES,
} from '@/hooks/contracts/useArmsTradeCompliance';

type Tab = 'overview' | 'apply' | 'sanctions' | 'lookup';

const RISK_COLOR: Record<number, string> = {
  0: 'text-amber-400',   // SmallArms
  1: 'text-orange-400',  // Artillery
  2: 'text-red-400',     // AircraftSystems
  3: 'text-red-400',     // NavalSystems
  4: 'text-blue-400',    // Electronics
  5: 'text-amber-400',   // Ammunition
  6: 'text-red-500',     // MissileSystems
  7: 'text-gray-400',    // Other
};

export default function ArmsComplianceDashboard() {
  const { address } = useAccount();
  const [tab, setTab] = useState<Tab>('overview');

  const { licenseCount, totalTradeValue } = useArmsStats();
  const { data: myLicenses } = useGetExporterLicenses(address);
  const myLicenseIds = myLicenses as bigint[] | undefined;

  // Apply form
  const [importer, setImporter] = useState('');
  const [exporterCountry, setExporterCountry] = useState('');
  const [importerCountry, setImporterCountry] = useState('');
  const [commodityType, setCommodityType] = useState(0);
  const [commodityDesc, setCommodityDesc] = useState('');
  const [hsCode, setHsCode] = useState('');
  const [quantity, setQuantity] = useState('');
  const [value, setValue] = useState('');
  const [docHash, setDocHash] = useState('');

  // Sanctions
  const [sanctionEntity, setSanctionEntity] = useState('');
  const [sanctionName, setSanctionName] = useState('');
  const [sanctionCountry, setSanctionCountry] = useState('');

  // Lookup
  const [lookupLicenseId, setLookupLicenseId] = useState('');
  const parsedLicenseId = (() => { try { return lookupLicenseId ? BigInt(lookupLicenseId) : undefined; } catch { return undefined; } })();
  const { data: licenseData } = useGetLicense(parsedLicenseId);

  const { applyForLicense, isPending: applying, isConfirming: applyConfirming, isSuccess: applySuccess, error: applyError } = useApplyForLicense();
  const { performSanctionsCheck, isPending: checking, isConfirming: checkConfirming, isSuccess: checkSuccess } = usePerformSanctionsCheck();

  const handleApply = () => {
    if (!importer || !exporterCountry || !importerCountry || !quantity || !value) return;
    applyForLicense(
      importer as `0x${string}`,
      exporterCountry,
      importerCountry,
      commodityType,
      commodityDesc,
      hsCode,
      safeEther(quantity),
      safeEther(value),
      docHash,
    );
  };

  const handleSanctionsCheck = () => {
    if (!sanctionEntity) return;
    performSanctionsCheck(sanctionEntity as `0x${string}`, sanctionName, sanctionCountry);
  };

  const license = licenseData as any;

  const TABS: { id: Tab; label: string }[] = [
    { id: 'overview', label: 'Overview' },
    { id: 'apply', label: 'Apply for License' },
    { id: 'sanctions', label: 'Sanctions Check' },
    { id: 'lookup', label: 'License Lookup' },
  ];

  const STATUS_BADGE: Record<number, string> = {
    0: 'bg-amber-500/20 text-amber-400 border-amber-500/30',
    1: 'bg-green-500/20 text-green-400 border-green-500/30',
    2: 'bg-red-500/20 text-red-400 border-red-500/30',
    3: 'bg-gray-500/20 text-gray-400 border-gray-500/30',
  };

  const STATUS_LABELS = ['Pending', 'Approved', 'Rejected', 'Expired'];

  return (
    <div className="space-y-6">
      <div className="glass rounded-xl p-6">
        <h2 className="text-2xl font-bold text-white mb-1">Arms Trade Compliance</h2>
        <p className="text-gray-400">
          UN-compliant arms export/import licensing, sanctions screening, and dual-use goods management
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Total Licenses</p>
          <p className="text-3xl font-bold text-white">{licenseCount?.toString() ?? '—'}</p>
          <p className="text-xs text-blue-400 mt-1">All applications</p>
        </div>
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Total Trade Value</p>
          <p className="text-3xl font-bold text-white">
            {totalTradeValue ? `${parseFloat(formatEther(totalTradeValue as bigint)).toLocaleString()} ETH` : '—'}
          </p>
          <p className="text-xs text-green-400 mt-1">Verified trades</p>
        </div>
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">My Licenses</p>
          <p className="text-3xl font-bold text-white">{myLicenseIds?.length ?? '—'}</p>
          <p className="text-xs text-purple-400 mt-1">As exporter</p>
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
              <h3 className="text-lg font-bold text-white">Controlled Commodity Categories</h3>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                {COMMODITY_TYPES.map((type, i) => (
                  <div
                    key={type}
                    className="p-3 bg-white/5 border border-white/10 rounded-lg hover:bg-white/10 transition-all cursor-pointer"
                    onClick={() => { setCommodityType(i); setTab('apply'); }}
                  >
                    <p className="text-xs text-gray-400 mb-1">CCR-{i.toString().padStart(3, '0')}</p>
                    <p className={`text-sm font-semibold ${RISK_COLOR[i] ?? 'text-white'}`}>{type}</p>
                  </div>
                ))}
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                <div className="p-4 bg-red-500/10 border border-red-500/20 rounded-lg">
                  <p className="text-sm font-semibold text-white mb-2">Compliance Framework</p>
                  <ul className="space-y-1 text-xs text-gray-400">
                    <li>• Wassenaar Arrangement alignment</li>
                    <li>• UN Arms Trade Treaty (ATT) compliance</li>
                    <li>• End-user certificate verification</li>
                    <li>• Real-time sanctions screening</li>
                    <li>• HS code classification</li>
                  </ul>
                </div>
                <div className="p-4 bg-amber-500/10 border border-amber-500/20 rounded-lg">
                  <p className="text-sm font-semibold text-white mb-2">License Lifecycle</p>
                  <div className="space-y-2">
                    {STATUS_LABELS.map((label, i) => (
                      <div key={label} className="flex items-center gap-2">
                        <span className={`px-2 py-0.5 text-xs rounded border ${STATUS_BADGE[i]}`}>{label}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          )}

          {tab === 'apply' && (
            <div className="space-y-4 max-w-lg">
              <h3 className="text-lg font-bold text-white">Apply for Export License</h3>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Commodity Category</label>
                <select
                  value={commodityType}
                  onChange={(e) => setCommodityType(Number(e.target.value))}
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
                >
                  {COMMODITY_TYPES.map((t, i) => (
                    <option key={t} value={i}>{t}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Importer Address</label>
                <input
                  value={importer}
                  onChange={(e) => setImporter(e.target.value)}
                  placeholder="0x..."
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono text-sm"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Exporter Country</label>
                  <input
                    value={exporterCountry}
                    onChange={(e) => setExporterCountry(e.target.value)}
                    placeholder="e.g. USA"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Importer Country</label>
                  <input
                    value={importerCountry}
                    onChange={(e) => setImporterCountry(e.target.value)}
                    placeholder="e.g. UAE"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Commodity Description</label>
                <input
                  value={commodityDesc}
                  onChange={(e) => setCommodityDesc(e.target.value)}
                  placeholder="e.g. 5.56mm assault rifles, 500 units"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">HS Code</label>
                  <input
                    value={hsCode}
                    onChange={(e) => setHsCode(e.target.value)}
                    placeholder="9301.20"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Quantity (ETH units)</label>
                  <input
                    type="number"
                    value={quantity}
                    onChange={(e) => setQuantity(e.target.value)}
                    placeholder="500"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Value (ETH)</label>
                <input
                  type="number"
                  value={value}
                  onChange={(e) => setValue(e.target.value)}
                  placeholder="1000"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Document Hash (IPFS / SHA-256)</label>
                <input
                  value={docHash}
                  onChange={(e) => setDocHash(e.target.value)}
                  placeholder="Qm... or 0x..."
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono text-xs"
                />
              </div>

              <button
                onClick={handleApply}
                disabled={applying || applyConfirming || !address || !importer || !exporterCountry || !quantity || !value}
                className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {applying || applyConfirming ? 'Submitting Application...' : applySuccess ? 'Application Submitted!' : 'Submit License Application'}
              </button>

              {applyError && (
                <p className="text-xs text-red-400 bg-red-500/10 border border-red-500/20 rounded-lg p-3">
                  {applyError.message}
                </p>
              )}
            </div>
          )}

          {tab === 'sanctions' && (
            <div className="space-y-4 max-w-md">
              <h3 className="text-lg font-bold text-white">Sanctions Screening</h3>
              <p className="text-sm text-gray-400">
                Screen entities against OFAC, EU, UN and other international sanctions lists.
              </p>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Entity Address</label>
                <input
                  value={sanctionEntity}
                  onChange={(e) => setSanctionEntity(e.target.value)}
                  placeholder="0x..."
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono text-sm"
                />
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Entity Name</label>
                <input
                  value={sanctionName}
                  onChange={(e) => setSanctionName(e.target.value)}
                  placeholder="Legal entity name"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Country</label>
                <input
                  value={sanctionCountry}
                  onChange={(e) => setSanctionCountry(e.target.value)}
                  placeholder="e.g. Iran, Russia, North Korea"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <button
                onClick={handleSanctionsCheck}
                disabled={checking || checkConfirming || !sanctionEntity || !address}
                className="w-full py-4 bg-red-600 hover:bg-red-700 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {checking || checkConfirming ? 'Screening...' : checkSuccess ? 'Check Complete' : 'Run Sanctions Check'}
              </button>

              {checkSuccess && (
                <div className="flex items-center gap-2 text-green-400 text-sm p-3 bg-green-500/10 border border-green-500/20 rounded-lg">
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  Sanctions check recorded on-chain.
                </div>
              )}
            </div>
          )}

          {tab === 'lookup' && (
            <div className="space-y-4 max-w-lg">
              <h3 className="text-lg font-bold text-white">License Lookup</h3>
              <input
                type="number"
                value={lookupLicenseId}
                onChange={(e) => setLookupLicenseId(e.target.value)}
                placeholder="License ID"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />

              {license && (
                <div className="p-4 bg-white/5 border border-white/10 rounded-lg space-y-3 text-sm">
                  <div className="flex justify-between items-center">
                    <span className="text-gray-400">Status</span>
                    <span className={`px-2 py-0.5 text-xs rounded border ${STATUS_BADGE[license.status ?? 0]}`}>
                      {STATUS_LABELS[license.status ?? 0]}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Commodity</span>
                    <span className={RISK_COLOR[license.commodityType ?? 7] ?? 'text-white'}>
                      {COMMODITY_TYPES[license.commodityType]}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Exporter → Importer</span>
                    <span className="text-white">{license.exporterCountry} → {license.importerCountry}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Value</span>
                    <span className="text-green-400">{formatEther(license.value ?? 0n)} ETH</span>
                  </div>
                  {license.hsCode && (
                    <div className="flex justify-between">
                      <span className="text-gray-400">HS Code</span>
                      <span className="text-white font-mono">{license.hsCode}</span>
                    </div>
                  )}
                </div>
              )}
              {lookupLicenseId && !license && (
                <p className="text-gray-400 text-sm text-center py-4">License #{lookupLicenseId} not found.</p>
              )}

              {/* My licenses */}
              {address && myLicenseIds && myLicenseIds.length > 0 && (
                <div className="mt-6">
                  <h4 className="text-sm font-semibold text-white mb-3">My Licenses</h4>
                  <div className="flex flex-wrap gap-2">
                    {myLicenseIds.map((id) => (
                      <button
                        key={id.toString()}
                        onClick={() => setLookupLicenseId(id.toString())}
                        className="px-3 py-1 text-sm bg-white/5 border border-white/10 rounded-lg text-gray-300 hover:bg-white/10 hover:text-white transition-all"
                      >
                        #{id.toString()}
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );

  // Helper referenced in lookup tab - needs to be in scope
  // function STATUS_BADGE(status: number): string {
  //   const m: Record<number, string> = {
  //     0: 'bg-amber-500/20 text-amber-400 border-amber-500/30',
  //     1: 'bg-green-500/20 text-green-400 border-green-500/30',
  //     2: 'bg-red-500/20 text-red-400 border-red-500/30',
  //     3: 'bg-gray-500/20 text-gray-400 border-gray-500/30',
  //   };
  //   return m[status] ?? m[3];
  // }
}
