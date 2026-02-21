'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { parseEther, formatEther } from 'viem';
import {
  useCompanyCount,
  useTradeCount,
  useGetAllCenters,
  useGetCenterListings,
  useListCompany,
} from '@/hooks/contracts/useDigitalTradeExchange';

// Center metadata matching the contract enum (Alpha=0..Echo=4)
const CENTER_META = [
  { id: 0, code: 'Alpha',   flag: '🇵🇷', location: 'San Juan',  country: 'Puerto Rico', region: 'Americas'     },
  { id: 1, code: 'Bravo',   flag: '🇨🇴', location: 'Bogotá',    country: 'Colombia',    region: 'Americas'     },
  { id: 2, code: 'Charlie', flag: '🇬🇭', location: 'Accra',     country: 'Ghana',       region: 'Africa'       },
  { id: 3, code: 'Delta',   flag: '🇱🇰', location: 'Colombo',   country: 'Sri Lanka',   region: 'Asia Pacific' },
  { id: 4, code: 'Echo',    flag: '🇮🇩', location: 'Jakarta',   country: 'Indonesia',   region: 'Asia Pacific' },
];

const SECTORS = [
  'Technology', 'Agriculture', 'Energy', 'Finance', 'Infrastructure',
  'Manufacturing', 'Healthcare', 'Mining', 'Trade', 'Real Estate',
];

export default function DTXDashboard() {
  const { address } = useAccount();
  const [activeCenter, setActiveCenter] = useState(0);
  const [showListForm, setShowListForm] = useState(false);
  const [form, setForm] = useState({
    name: '', ticker: '', sector: 'Technology', center: 0,
    shares: '1000000', price: '10',
  });
  const [listStatus, setListStatus] = useState('');

  const { data: companyCount } = useCompanyCount();
  const { data: tradeCount }   = useTradeCount();
  const { data: centers }      = useGetAllCenters();
  const { data: centerListings } = useGetCenterListings(BigInt(activeCenter));

  const { listCompany, isPending, isConfirming, isSuccess, error } = useListCompany();

  const handleList = async (e: React.FormEvent) => {
    e.preventDefault();
    setListStatus('');
    try {
      await listCompany(
        form.name,
        form.ticker.toUpperCase(),
        form.sector,
        Number(form.center),
        parseEther(form.shares),
        parseEther(form.price),
      );
      setListStatus('submitted');
    } catch (err: unknown) {
      setListStatus('error:' + (err instanceof Error ? err.message : String(err)));
    }
  };

  const activeMeta = CENTER_META[activeCenter];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-gradient-to-r from-emerald-900/40 to-teal-900/40 border border-emerald-700/50 rounded-xl p-6">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-2xl font-bold text-emerald-300">Digital Trade Exchange (DTX)</h2>
            <p className="text-emerald-400/70 text-sm mt-1">
              Global 5-Center Bourse — Company listings on the OICD network
            </p>
          </div>
          <div className="text-right">
            <div className="text-3xl font-bold text-emerald-300">
              {companyCount != null ? companyCount.toString() : '—'}
            </div>
            <div className="text-xs text-emerald-400/60">Listed Companies</div>
          </div>
        </div>

        {/* Stats row */}
        <div className="grid grid-cols-3 gap-4 mt-4">
          <div className="bg-black/30 rounded-lg p-3 text-center">
            <div className="text-lg font-bold text-white">{companyCount?.toString() ?? '0'}</div>
            <div className="text-xs text-gray-400">Total Listings</div>
          </div>
          <div className="bg-black/30 rounded-lg p-3 text-center">
            <div className="text-lg font-bold text-white">{tradeCount?.toString() ?? '0'}</div>
            <div className="text-xs text-gray-400">Trades Executed</div>
          </div>
          <div className="bg-black/30 rounded-lg p-3 text-center">
            <div className="text-lg font-bold text-white">5</div>
            <div className="text-xs text-gray-400">Exchange Centers</div>
          </div>
        </div>
      </div>

      {/* Exchange Centers */}
      <div>
        <h3 className="text-sm font-semibold text-gray-400 uppercase mb-3">Exchange Centers</h3>
        <div className="grid grid-cols-5 gap-2">
          {CENTER_META.map((c) => {
            const centerData = centers ? (centers as unknown[])[c.id] : undefined;
            const isActive = !!(centerData as {active?: boolean} | undefined)?.active;
            const listings = !!(centerData as {totalListings?: bigint} | undefined)?.totalListings
              ? (centerData as {totalListings: bigint}).totalListings.toString()
              : '0';

            return (
              <button
                key={c.id}
                onClick={() => setActiveCenter(c.id)}
                className={`p-3 rounded-lg border text-center transition-all ${
                  activeCenter === c.id
                    ? 'border-emerald-500 bg-emerald-900/30'
                    : 'border-gray-700 bg-gray-800/50 hover:border-gray-600'
                }`}
              >
                <div className="text-2xl">{c.flag}</div>
                <div className="text-xs font-bold text-white mt-1">{c.code}</div>
                <div className="text-xs text-gray-400">{c.country}</div>
                <div className={`text-xs mt-1 font-medium ${isActive ? 'text-green-400' : 'text-red-400'}`}>
                  {listings} listed
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* Active Center Detail */}
      <div className="bg-gray-800/50 border border-gray-700 rounded-xl p-5">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-3">
            <span className="text-3xl">{activeMeta.flag}</span>
            <div>
              <h3 className="text-lg font-bold text-white">
                {activeMeta.code} Exchange — {activeMeta.location}
              </h3>
              <p className="text-xs text-gray-400">{activeMeta.country} · {activeMeta.region}</p>
            </div>
          </div>
          <span className="px-3 py-1 bg-green-900/30 text-green-400 rounded-full text-xs font-medium border border-green-700/50">
            Active
          </span>
        </div>

        {/* Listings for this center */}
        <div>
          <h4 className="text-xs font-semibold text-gray-400 uppercase mb-2">
            Companies Listed ({centerListings ? (centerListings as bigint[]).length : 0})
          </h4>
          {(!centerListings || (centerListings as bigint[]).length === 0) ? (
            <p className="text-gray-500 text-sm italic py-4 text-center">
              No companies listed on this exchange yet.
            </p>
          ) : (
            <div className="space-y-2">
              {(centerListings as bigint[]).map((id) => (
                <div key={id.toString()} className="flex items-center justify-between bg-black/30 rounded-lg px-4 py-2">
                  <span className="text-gray-300 text-sm">Company #{id.toString()}</span>
                  <span className="text-emerald-400 text-xs">Listed</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* List Company Form */}
      {address && (
        <div className="bg-gray-800/50 border border-gray-700 rounded-xl p-5">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-base font-semibold text-white">List a Company</h3>
            <button
              onClick={() => setShowListForm(!showListForm)}
              className="text-xs text-emerald-400 hover:text-emerald-300"
            >
              {showListForm ? 'Hide' : 'Show Form'}
            </button>
          </div>

          {showListForm && (
            <form onSubmit={handleList} className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-xs text-gray-400 block mb-1">Company Name</label>
                  <input
                    className="w-full bg-black/40 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm"
                    value={form.name}
                    onChange={(e) => setForm({ ...form, name: e.target.value })}
                    placeholder="Acme Global Corp"
                    required
                  />
                </div>
                <div>
                  <label className="text-xs text-gray-400 block mb-1">Ticker (2–5 chars)</label>
                  <input
                    className="w-full bg-black/40 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm uppercase"
                    value={form.ticker}
                    onChange={(e) => setForm({ ...form, ticker: e.target.value.toUpperCase() })}
                    placeholder="ACME"
                    maxLength={5}
                    minLength={2}
                    required
                  />
                </div>
                <div>
                  <label className="text-xs text-gray-400 block mb-1">Sector</label>
                  <select
                    className="w-full bg-black/40 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm"
                    value={form.sector}
                    onChange={(e) => setForm({ ...form, sector: e.target.value })}
                  >
                    {SECTORS.map((s) => <option key={s}>{s}</option>)}
                  </select>
                </div>
                <div>
                  <label className="text-xs text-gray-400 block mb-1">Exchange Center</label>
                  <select
                    className="w-full bg-black/40 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm"
                    value={form.center}
                    onChange={(e) => setForm({ ...form, center: Number(e.target.value) })}
                  >
                    {CENTER_META.map((c) => (
                      <option key={c.id} value={c.id}>{c.code} — {c.country}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="text-xs text-gray-400 block mb-1">Total Shares</label>
                  <input
                    className="w-full bg-black/40 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm"
                    value={form.shares}
                    onChange={(e) => setForm({ ...form, shares: e.target.value })}
                    type="number"
                    min="1"
                    required
                  />
                </div>
                <div>
                  <label className="text-xs text-gray-400 block mb-1">Initial Price (OICD)</label>
                  <input
                    className="w-full bg-black/40 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm"
                    value={form.price}
                    onChange={(e) => setForm({ ...form, price: e.target.value })}
                    type="number"
                    min="0"
                    step="0.01"
                    required
                  />
                </div>
              </div>

              <button
                type="submit"
                disabled={isPending || isConfirming}
                className="w-full py-2 bg-emerald-600 hover:bg-emerald-700 disabled:bg-gray-700 text-white font-medium rounded-lg text-sm transition-colors"
              >
                {isPending ? 'Confirm in wallet…' : isConfirming ? 'Listing…' : 'List Company on DTX'}
              </button>

              {isSuccess && (
                <p className="text-green-400 text-xs text-center">Company listed successfully!</p>
              )}
              {!!error && (
                <p className="text-red-400 text-xs text-center">
                  {error instanceof Error ? error.message : String(error)}
                </p>
              )}
              {listStatus.startsWith('error:') && (
                <p className="text-red-400 text-xs text-center">{listStatus.slice(6)}</p>
              )}
            </form>
          )}
        </div>
      )}

      {/* About DTX */}
      <div className="bg-gray-800/30 border border-gray-700/50 rounded-xl p-5">
        <h3 className="text-sm font-semibold text-gray-300 mb-3">About DTX</h3>
        <div className="grid grid-cols-2 gap-6 text-sm text-gray-400">
          <div>
            <p className="mb-2">
              The <strong className="text-white">Digital Trade Exchange (DTX)</strong> is a global bourse
              operating across 5 strategic exchange centers. Companies can list their shares and trade in
              OICD, the sovereign digital currency.
            </p>
            <p>
              Each center serves a distinct regional market, enabling 24/7 global coverage across the
              Americas, Africa, and Asia Pacific.
            </p>
          </div>
          <div className="space-y-2">
            {CENTER_META.map((c) => (
              <div key={c.id} className="flex items-center gap-3">
                <span className="text-lg">{c.flag}</span>
                <div>
                  <span className="text-white font-medium">{c.code}</span>
                  <span className="text-gray-500 mx-1">·</span>
                  <span>{c.location}, {c.country}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
