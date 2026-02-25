'use client';
import { useState, useEffect } from 'react';
import { useAccount } from 'wagmi';
import { formatEther, parseEther } from 'viem';
import {
  useAVSTotalAssets, useAVSTotalCountries, useAVSTotalVolumeOICD,
  useAVSCountryProfile, useAVSAsset,
  useAVSRegisterCountry, useAVSListAsset, useAVSPurchaseAsset,
} from '@/hooks/contracts/useAVSPlatform';

const safeEther = (v: string) => { try { return parseEther(v || '0'); } catch { return 0n; } };
const safeBig  = (v: string) => { try { return v ? BigInt(v) : 0n; } catch { return 0n; } };

const ASSET_TYPES = ['NaturalResource','Energy','PreciousMetals','Agriculture','Timber','Mining','Infrastructure','RealEstate','Technology','Manufacturing'];
const INSTRUMENT_TYPES = ['Spot','Futures','Derivatives','Options','Bond','REIT','DigitalStock'];
type Tab = 'overview'|'register'|'list'|'purchase'|'lookup';
const tc = (a:boolean) => a ? 'px-4 py-2 rounded-t text-sm font-medium bg-purple-600 text-white' : 'px-4 py-2 rounded-t text-sm font-medium text-gray-400 hover:text-white';

export default function AVSPlatformDashboard() {
  const { isConnected } = useAccount();
  const [tab, setTab] = useState<Tab>('overview');
  const { data: totalAssets } = useAVSTotalAssets();
  const { data: totalCountries } = useAVSTotalCountries();
  const { data: totalVolume } = useAVSTotalVolumeOICD();
  const [regCode,setRegCode]=useState(''); const [regName,setRegName]=useState(''); const [regDebt,setRegDebt]=useState('');
  const [laCountry,setLaCountry]=useState(''); const [laType,setLaType]=useState(0); const [laName,setLaName]=useState('');
  const [laUnits,setLaUnits]=useState(''); const [laPrice,setLaPrice]=useState(''); const [laInstrument,setLaInstrument]=useState(0);
  const [laDesc,setLaDesc]=useState(''); const [laIpfs,setLaIpfs]=useState('');
  const [purId,setPurId]=useState(''); const [purUnits,setPurUnits]=useState('');
  const [lookupType,setLookupType]=useState<'asset'|'country'>('country');
  const [lookupCode,setLookupCode]=useState(''); const [lookupAssetId,setLookupAssetId]=useState('');
  const { data: lookupCountry } = useAVSCountryProfile(lookupCode);
  const { data: lookupAsset } = useAVSAsset(safeBig(lookupAssetId));
  const { registerCountry, isPending: registering, isSuccess: registered, error: regErr } = useAVSRegisterCountry();
  const { listAsset, isPending: listing, isSuccess: listed, error: listErr } = useAVSListAsset();
  const { purchaseAsset, isPending: purchasing, isSuccess: purchased, error: purchaseErr } = useAVSPurchaseAsset();

  const [txError, setTxError] = useState<string | null>(null);
  const [txSuccess, setTxSuccess] = useState<string | null>(null);
  useEffect(() => {
    const err = regErr ?? listErr ?? purchaseErr;
    if (!err) return;
    const msg = (err as {shortMessage?:string})?.shortMessage ?? (err as {message?:string})?.message ?? 'Transaction failed';
    setTxError(msg.length > 120 ? msg.slice(0, 120) + '…' : msg);
    const t = setTimeout(() => setTxError(null), 7000);
    return () => clearTimeout(t);
  }, [regErr, listErr, purchaseErr]);
  useEffect(() => {
    if (registered) { setTxSuccess('Country registered on AVS Platform'); }
    else if (listed) { setTxSuccess('Asset listed for international sale'); }
    else if (purchased) { setTxSuccess('Asset purchased successfully'); }
    else return;
    const t = setTimeout(() => setTxSuccess(null), 5000);
    return () => clearTimeout(t);
  }, [registered, listed, purchased]);

  const TABS: {id:Tab;label:string}[] = [
    {id:'overview',label:'Overview'},{id:'register',label:'Register Country'},
    {id:'list',label:'List Asset'},{id:'purchase',label:'Purchase'},{id:'lookup',label:'Lookup'},
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
      <div className="bg-gradient-to-r from-blue-900/40 to-indigo-900/40 border border-blue-700/50 rounded-xl p-6 space-y-4">
        <div>
          <h2 className="text-2xl font-bold text-white">AVS Platform</h2>
          <p className="text-gray-400 mt-1 text-sm">Asset Value Securitization. Digitize & securitize real-world assets from emerging markets for international sale. Investment multiplier: 1.5–4.5× country debt. Instruments: Futures, Derivatives, Options, Bonds, REITs, Digital Stock. Revenue: 60% country / 40% Obsidian.</p>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {[
            { label: 'Listed Assets', value: String(totalAssets??0) },
            { label: 'Countries', value: String(totalCountries??0) },
            { label: 'Volume (OICD)', value: totalVolume?formatEther(totalVolume as bigint).split('.')[0]:'0' },
            { label: 'Debt Multiplier', value: '1.5–4.5×' },
          ].map(s=>(
            <div key={s.label} className="bg-white/5 border border-white/10 rounded-lg p-3 text-center">
              <div className="text-white font-bold text-lg">{s.value}</div>
              <div className="text-gray-400 text-xs mt-0.5">{s.label}</div>
            </div>
          ))}
        </div>
      </div>
      <div className="flex gap-2 flex-wrap border-b border-white/10 pb-2">
        {TABS.map(t=><button key={t.id} onClick={()=>setTab(t.id)} className={tc(tab===t.id)}>{t.label}</button>)}
      </div>

      {tab==='overview' && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
            {[
              {label:'Total Assets',value:String(totalAssets??0)},
              {label:'Countries',value:String(totalCountries??0)},
              {label:'Volume (OICD)',value:totalVolume?formatEther(totalVolume as bigint).split('.')[0]:'0'},
            ].map(s=>(
              <div key={s.label} className="bg-white/5 rounded-lg p-4">
                <div className="text-gray-400 text-xs mb-1">{s.label}</div>
                <div className="text-white font-semibold">{s.value}</div>
              </div>
            ))}
          </div>
          <div className="bg-white/5 rounded-lg p-4 text-sm text-gray-300 space-y-1">
            <p><span className="text-purple-400 font-semibold">Asset Types:</span> Natural Resources, Energy, Precious Metals, Agriculture, Timber, Mining, Infrastructure, Real Estate, Technology, Manufacturing</p>
            <p><span className="text-purple-400 font-semibold">Instruments:</span> Spot, Futures, Derivatives, Options, Bonds, REITs, Digital Stock</p>
            <p><span className="text-purple-400 font-semibold">Revenue Split:</span> 60% country / 40% Obsidian Capital</p>
          </div>
        </div>
      )}

      {tab==='register' && (
        <div className="bg-white/5 rounded-lg p-6 space-y-4 max-w-md">
          <h3 className="text-white font-semibold">Register Country (Owner Only)</h3>
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="ISO-2 Code (VE)" value={regCode} onChange={e=>setRegCode(e.target.value.toUpperCase().slice(0,2))} maxLength={2} />
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Country Name" value={regName} onChange={e=>setRegName(e.target.value)} />
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Debt Capacity (OICD)" value={regDebt} onChange={e=>setRegDebt(e.target.value)} />
          <button onClick={()=>registerCountry(regCode,regName,safeEther(regDebt))}
            disabled={!isConnected||registering||!regCode||!regName}
            className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
            {registering?'Registering…':registered?'✓ Registered':'Register Country'}
          </button>
        </div>
      )}

      {tab==='list' && (
        <div className="bg-white/5 rounded-lg p-6 space-y-3 max-w-md">
          <h3 className="text-white font-semibold">List Asset (Owner Only)</h3>
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Country Code" value={laCountry} onChange={e=>setLaCountry(e.target.value)} />
          <select className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm" value={laType} onChange={e=>setLaType(+e.target.value)}>
            {ASSET_TYPES.map((t,i)=><option key={i} value={i}>{t}</option>)}
          </select>
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Asset Name" value={laName} onChange={e=>setLaName(e.target.value)} />
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Total Units" value={laUnits} onChange={e=>setLaUnits(e.target.value)} />
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Price Per Unit (OICD)" value={laPrice} onChange={e=>setLaPrice(e.target.value)} />
          <select className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm" value={laInstrument} onChange={e=>setLaInstrument(+e.target.value)}>
            {INSTRUMENT_TYPES.map((t,i)=><option key={i} value={i}>{t}</option>)}
          </select>
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Description" value={laDesc} onChange={e=>setLaDesc(e.target.value)} />
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="IPFS CID (optional)" value={laIpfs} onChange={e=>setLaIpfs(e.target.value)} />
          <button onClick={()=>listAsset(laCountry,laType,laName,safeBig(laUnits),safeEther(laPrice),laInstrument,laDesc,laIpfs)}
            disabled={!isConnected||listing||!laCountry||!laName}
            className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
            {listing?'Listing…':listed?'✓ Listed':'List Asset'}
          </button>
        </div>
      )}

      {tab==='purchase' && (
        <div className="bg-white/5 rounded-lg p-6 space-y-4 max-w-md">
          <h3 className="text-white font-semibold">Purchase Asset Units</h3>
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Asset ID" value={purId} onChange={e=>setPurId(e.target.value)} />
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Units to Buy" value={purUnits} onChange={e=>setPurUnits(e.target.value)} />
          <button onClick={()=>purchaseAsset(safeBig(purId),safeBig(purUnits))}
            disabled={!isConnected||purchasing||!purId||!purUnits}
            className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
            {purchasing?'Processing…':purchased?'✓ Purchased':'Purchase Asset'}
          </button>
        </div>
      )}

      {tab==='lookup' && (
        <div className="space-y-4">
          <div className="flex gap-2">
            <button onClick={()=>setLookupType('country')} className={lookupType==='country'?'px-3 py-1 rounded text-sm bg-purple-600 text-white':'px-3 py-1 rounded text-sm bg-white/10 text-gray-400'}>Country</button>
            <button onClick={()=>setLookupType('asset')} className={lookupType==='asset'?'px-3 py-1 rounded text-sm bg-purple-600 text-white':'px-3 py-1 rounded text-sm bg-white/10 text-gray-400'}>Asset ID</button>
          </div>
          {lookupType==='country' ? (
            <div className="space-y-2">
              <input className="w-full max-w-xs bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Country Code" value={lookupCode} onChange={e=>setLookupCode(e.target.value.toUpperCase())} />
              {!!lookupCountry && (
                <div className="bg-white/5 rounded-lg p-4 text-sm">
                  {Object.entries(lookupCountry as Record<string,unknown>).map(([k,v])=>(
                    <div key={k} className="flex justify-between py-0.5"><span className="text-gray-400">{k}</span><span className="text-white ml-2">{String(v)}</span></div>
                  ))}
                </div>
              )}
            </div>
          ) : (
            <div className="space-y-2">
              <input className="w-full max-w-xs bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Asset ID" value={lookupAssetId} onChange={e=>setLookupAssetId(e.target.value)} />
              {!!lookupAsset && (
                <div className="bg-white/5 rounded-lg p-4 text-sm">
                  {Object.entries(lookupAsset as Record<string,unknown>).map(([k,v])=>(
                    <div key={k} className="flex justify-between py-0.5"><span className="text-gray-400">{k}</span><span className="text-white ml-2">{String(v)}</span></div>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
