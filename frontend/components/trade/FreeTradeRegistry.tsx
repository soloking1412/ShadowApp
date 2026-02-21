'use client';
import { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatEther, parseEther } from 'viem';
import {
  useFTRAgreementCounter, useFTRBolCounter, useFTRTotalTradeValue,
  useFTRGetAgreement, useFTRExporterAgreements,
  useFTRCreateAgreement, useFTRSignAgreement, useFTRRaiseDispute, useFTRCompleteAgreement,
} from '@/hooks/contracts/useFreeTradeRegistry';

const INCOTERMS = ['EXW','FCA','CPT','CIP','DAP','DPU','DDP','FAS','FOB','CFR','CIF'];
const PAYMENT_TERMS = ['Prepayment','Net30','Net60','Net90','Escrow','OpenAccount'];
const COMMODITIES = ['Lithium','RareEarth','Grains','Petroleum','NaturalGas','Gold','Copper','Iron','Diamonds','Timber','Coal','Uranium','AI_Tech','GreenEnergy','Blockchain','QuantumComputing','RenewableInfra','Pipelines','SmartGrids','Patents','TradeSecrets','Logistics','Other'];
type Tab = 'overview'|'create'|'sign'|'myagreements'|'lookup';
const tc = (a:boolean) => a ? 'px-4 py-2 rounded-t text-sm font-medium bg-purple-600 text-white' : 'px-4 py-2 rounded-t text-sm font-medium text-gray-400 hover:text-white';

export default function FreeTradeRegistryDashboard() {
  const { address, isConnected } = useAccount();
  const [tab, setTab] = useState<Tab>('overview');
  const { data: agreementCount } = useFTRAgreementCounter();
  const { data: bolCount } = useFTRBolCounter();
  const { data: totalValue } = useFTRTotalTradeValue();
  const { data: myAgreements } = useFTRExporterAgreements(address);

  // Create form
  const [importer,setImporter]=useState(''); const [broker,setBroker]=useState('');
  const [expCty,setExpCty]=useState(''); const [impCty,setImpCty]=useState('');
  const [brokerInst,setBrokerInst]=useState(''); const [totalVal,setTotalVal]=useState('');
  const [incoterms,setIncoterms]=useState(0); const [payTerms,setPayTerms]=useState(0);
  const [effDate,setEffDate]=useState(''); const [expDate,setExpDate]=useState('');
  const [selectedComms,setSelectedComms]=useState<number[]>([]);

  // Sign / actions
  const [signId,setSignId]=useState(''); const [disputeId,setDisputeId]=useState('');
  const [disputeReason,setDisputeReason]=useState(''); const [completeId,setCompleteId]=useState('');

  // Lookup
  const [lookupId,setLookupId]=useState('');
  const { data: agreementData } = useFTRGetAgreement(lookupId ? BigInt(lookupId) : 0n);

  const { createAgreement, isPending: creating } = useFTRCreateAgreement();
  const { signAgreement, isPending: signing } = useFTRSignAgreement();
  const { raiseDispute, isPending: disputing } = useFTRRaiseDispute();
  const { completeAgreement, isPending: completing } = useFTRCompleteAgreement();

  const TABS: {id:Tab;label:string}[] = [{id:'overview',label:'Overview'},{id:'create',label:'Create Agreement'},{id:'sign',label:'Sign / Actions'},{id:'myagreements',label:'My Agreements'},{id:'lookup',label:'Lookup'}];

  const toggleComm = (i:number) => setSelectedComms(s=>s.includes(i)?s.filter(x=>x!==i):[...s,i]);

  const handleCreate = () => {
    const eff = effDate ? BigInt(Math.floor(new Date(effDate).getTime()/1000)) : 0n;
    const exp = expDate ? BigInt(Math.floor(new Date(expDate).getTime()/1000)) : 0n;
    createAgreement(
      importer as `0x${string}`, broker as `0x${string}`,
      expCty, impCty, brokerInst, selectedComms,
      totalVal?parseEther(totalVal):0n, incoterms, payTerms, eff, exp
    );
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Free Trade Registry</h2>
        <p className="text-gray-400 mt-1">OZF Global Trade Agreement Registry. WTO + OZF filing support. Incoterms 2020. All trades priced in $OICD. Samuel Global Market Xchange Inc.</p>
      </div>
      <div className="flex gap-2 flex-wrap border-b border-white/10 pb-2">
        {TABS.map(t=><button key={t.id} onClick={()=>setTab(t.id)} className={tc(tab===t.id)}>{t.label}</button>)}
      </div>

      {tab==='overview' && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
            {[
              {label:'Total Agreements',value:String(agreementCount??0)},
              {label:'Bills of Lading',value:String(bolCount??0)},
              {label:'Total Trade Value (OICD)',value:totalValue?formatEther(totalValue as bigint).split('.')[0]:'0'},
            ].map(s=>(
              <div key={s.label} className="bg-white/5 rounded-lg p-4">
                <div className="text-gray-400 text-xs mb-1">{s.label}</div>
                <div className="text-white font-semibold">{s.value}</div>
              </div>
            ))}
          </div>
          <div className="bg-white/5 rounded-lg p-4 text-sm text-gray-300 space-y-1">
            <p><span className="text-purple-400 font-semibold">Incoterms 2020:</span> EXW, FCA, CPT, CIP, DAP, DPU, DDP (any transport) + FAS, FOB, CFR, CIF (sea)</p>
            <p><span className="text-purple-400 font-semibold">Commodities:</span> Lithium, Rare Earth, Petroleum, Gold, Copper, AI Tech, Green Energy, and more</p>
            <p><span className="text-purple-400 font-semibold">Process:</span> Create → Both parties sign → Issue Bill of Lading → Register with WTO/OZF → Complete</p>
          </div>
        </div>
      )}

      {tab==='create' && (
        <div className="bg-white/5 rounded-lg p-6 space-y-3 max-w-lg">
          <h3 className="text-white font-semibold">Create Trade Agreement</h3>
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Importer Address (0x...)" value={importer} onChange={e=>setImporter(e.target.value)} />
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Broker Address (0x... or zero)" value={broker} onChange={e=>setBroker(e.target.value)} />
          <div className="grid grid-cols-2 gap-2">
            <input className="bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Exporter Country" value={expCty} onChange={e=>setExpCty(e.target.value)} />
            <input className="bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Importer Country" value={impCty} onChange={e=>setImpCty(e.target.value)} />
          </div>
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Broker Institution" value={brokerInst} onChange={e=>setBrokerInst(e.target.value)} />
          <div>
            <div className="text-gray-400 text-xs mb-2">Commodities (select all that apply)</div>
            <div className="flex flex-wrap gap-1">
              {COMMODITIES.map((c,i)=>(
                <button key={i} onClick={()=>toggleComm(i)} className={selectedComms.includes(i)?'px-2 py-0.5 rounded text-xs bg-purple-600 text-white':'px-2 py-0.5 rounded text-xs bg-white/10 text-gray-400'}>{c}</button>
              ))}
            </div>
          </div>
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Total Value (OICD)" value={totalVal} onChange={e=>setTotalVal(e.target.value)} />
          <div className="grid grid-cols-2 gap-2">
            <select className="bg-white/10 rounded px-3 py-2 text-white text-sm" value={incoterms} onChange={e=>setIncoterms(+e.target.value)}>
              {INCOTERMS.map((t,i)=><option key={i} value={i}>{t}</option>)}
            </select>
            <select className="bg-white/10 rounded px-3 py-2 text-white text-sm" value={payTerms} onChange={e=>setPayTerms(+e.target.value)}>
              {PAYMENT_TERMS.map((t,i)=><option key={i} value={i}>{t}</option>)}
            </select>
          </div>
          <div className="grid grid-cols-2 gap-2">
            <div><label className="text-gray-400 text-xs block mb-1">Effective Date</label><input type="date" className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm" value={effDate} onChange={e=>setEffDate(e.target.value)} /></div>
            <div><label className="text-gray-400 text-xs block mb-1">Expiry Date</label><input type="date" className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm" value={expDate} onChange={e=>setExpDate(e.target.value)} /></div>
          </div>
          <button onClick={handleCreate} disabled={!isConnected||creating||!importer||!totalVal}
            className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
            {creating?'Creating…':'Create Agreement'}
          </button>
        </div>
      )}

      {tab==='sign' && (
        <div className="space-y-4 max-w-md">
          <div className="bg-white/5 rounded-lg p-4 space-y-3">
            <h3 className="text-white font-semibold">Sign Agreement</h3>
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Agreement ID" value={signId} onChange={e=>setSignId(e.target.value)} />
            <button onClick={()=>signAgreement(BigInt(signId||'0'))} disabled={!isConnected||signing||!signId}
              className="w-full bg-green-600 hover:bg-green-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
              {signing?'Signing…':'Sign Agreement'}
            </button>
          </div>
          <div className="bg-white/5 rounded-lg p-4 space-y-3">
            <h3 className="text-white font-semibold">Complete Agreement</h3>
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Agreement ID" value={completeId} onChange={e=>setCompleteId(e.target.value)} />
            <button onClick={()=>completeAgreement(BigInt(completeId||'0'))} disabled={!isConnected||completing||!completeId}
              className="w-full bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
              {completing?'Completing…':'Complete Agreement'}
            </button>
          </div>
          <div className="bg-white/5 rounded-lg p-4 space-y-3">
            <h3 className="text-white font-semibold">Raise Dispute</h3>
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Agreement ID" value={disputeId} onChange={e=>setDisputeId(e.target.value)} />
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Reason" value={disputeReason} onChange={e=>setDisputeReason(e.target.value)} />
            <button onClick={()=>raiseDispute(BigInt(disputeId||'0'),disputeReason)} disabled={!isConnected||disputing||!disputeId}
              className="w-full bg-red-600 hover:bg-red-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
              {disputing?'Raising…':'Raise Dispute'}
            </button>
          </div>
        </div>
      )}

      {tab==='myagreements' && (
        <div className="space-y-3">
          <h3 className="text-white font-semibold">My Agreements (as Exporter)</h3>
          {(myAgreements as bigint[]|undefined)?.length ? (
            <div className="flex flex-wrap gap-2">
              {(myAgreements as bigint[]).map(id=>(
                <span key={id.toString()} className="bg-white/10 text-white text-sm px-3 py-1 rounded cursor-pointer hover:bg-white/20" onClick={()=>{setLookupId(id.toString());setTab('lookup');}}>#{id.toString()}</span>
              ))}
            </div>
          ) : <p className="text-gray-500 text-sm">No agreements found as exporter</p>}
        </div>
      )}

      {tab==='lookup' && (
        <div className="space-y-4">
          <input className="w-full max-w-xs bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Agreement ID" value={lookupId} onChange={e=>setLookupId(e.target.value)} />
          {!!agreementData && (
            <div className="bg-white/5 rounded-lg p-4 text-sm space-y-1">
              {Object.entries(agreementData as Record<string,unknown>).map(([k,v])=>(
                <div key={k} className="flex justify-between py-0.5"><span className="text-gray-400">{k}</span><span className="text-white ml-2 truncate">{String(v)}</span></div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
