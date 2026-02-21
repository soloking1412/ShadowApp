'use client';
import { useState } from 'react';
import { useAccount } from 'wagmi';
import {
  useOTDTotalSupply, useOTDTotalHolders, useOTDTotalVotes,
  useOTDHolder, useOTDVote,
  useOTDRegisterAsValidator, useOTDRegisterAsShareholder,
  useOTDCreateGovernanceVote, useOTDCastVote, useOTDExecuteVote,
} from '@/hooks/contracts/useOTDToken';

type Tab = 'overview'|'register'|'governance'|'lookup';
const tc = (a:boolean) => a ? 'px-4 py-2 rounded-t text-sm font-medium bg-purple-600 text-white' : 'px-4 py-2 rounded-t text-sm font-medium text-gray-400 hover:text-white';

export default function OTDTokenDashboard() {
  const { address, isConnected } = useAccount();
  const [tab, setTab] = useState<Tab>('overview');
  const { data: totalHolders } = useOTDTotalHolders();
  const { data: totalVotes } = useOTDTotalVotes();
  const { data: holderData } = useOTDHolder(address);
  const [voteTitle,setVoteTitle]=useState(''); const [voteDesc,setVoteDesc]=useState(''); const [voteDays,setVoteDays]=useState('7');
  const [castId,setCastId]=useState(''); const [support,setSupport]=useState(true);
  const [lookupVoteId,setLookupVoteId]=useState('');
  const { data: voteData } = useOTDVote(lookupVoteId ? BigInt(lookupVoteId) : 0n);
  const { registerAsValidator, isPending: regVPending, isSuccess: regVDone } = useOTDRegisterAsValidator();
  const { registerAsShareholder, isPending: regSPending, isSuccess: regSDone } = useOTDRegisterAsShareholder();
  const { createGovernanceVote, isPending: creating } = useOTDCreateGovernanceVote();
  const { castVote, isPending: casting } = useOTDCastVote();
  const { executeVote, isPending: executing } = useOTDExecuteVote();
  const TABS: {id:Tab;label:string}[] = [{id:'overview',label:'Overview'},{id:'register',label:'Register'},{id:'governance',label:'Governance'},{id:'lookup',label:'Lookup'}];

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">OTD Token</h2>
        <p className="text-gray-400 mt-1">Market stock of Obsidian Capital / Orion Infrastructure Corporation. Total supply: 500 Octillion OTD. 1-person-1-vote governance.</p>
      </div>
      <div className="flex gap-2 flex-wrap border-b border-white/10 pb-2">
        {TABS.map(t=><button key={t.id} onClick={()=>setTab(t.id)} className={tc(tab===t.id)}>{t.label}</button>)}
      </div>

      {tab==='overview' && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
            {[
              {label:'Total Supply',value:'500 Octillion'},
              {label:'Total Holders',value:String(totalHolders??0)},
              {label:'Governance Votes',value:String(totalVotes??0)},
            ].map(s=>(
              <div key={s.label} className="bg-white/5 rounded-lg p-4">
                <div className="text-gray-400 text-xs mb-1">{s.label}</div>
                <div className="text-white font-semibold">{s.value}</div>
              </div>
            ))}
          </div>
          <div className="bg-white/5 rounded-lg p-4 text-sm text-gray-300 space-y-1">
            <p><span className="text-purple-400 font-semibold">Validator Track:</span> 5-month lock, 4x compound. Month 1=$2M, Month 5=$512M OICD. 2/3 locked into network pool.</p>
            <p><span className="text-purple-400 font-semibold">Shareholder Track:</span> 8-month lock, 2x compound. Month 1=$2M, Month 8=$256M OICD.</p>
            <p><span className="text-purple-400 font-semibold">Governance:</span> 1 person = 1 vote. No whale voting. +1 G-Score for participation.</p>
            <p><span className="text-purple-400 font-semibold">GIC:</span> Orion Infrastructure Corporation speculative asset. 1B GIC initial supply.</p>
          </div>
        </div>
      )}

      {tab==='register' && (
        <div className="space-y-4 max-w-md">
          <div className="bg-white/5 rounded-lg p-6 space-y-3">
            <h3 className="text-white font-semibold">Register as Validator</h3>
            <p className="text-gray-400 text-sm">5-month lock. 4x compound: $2M → $8M → $32M → $128M → $512M OICD. 2/3 locked into network liquidity pool.</p>
            <button onClick={()=>registerAsValidator()} disabled={!isConnected||regVPending}
              className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
              {regVPending?'Registering…':regVDone?'✓ Registered':'Register as Validator'}
            </button>
          </div>
          <div className="bg-white/5 rounded-lg p-6 space-y-3">
            <h3 className="text-white font-semibold">Register as Shareholder</h3>
            <p className="text-gray-400 text-sm">8-month lock. 2x compound: $2M → $4M → … → $256M OICD. All free (no lock).</p>
            <button onClick={()=>registerAsShareholder()} disabled={!isConnected||regSPending}
              className="w-full bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
              {regSPending?'Registering…':regSDone?'✓ Registered':'Register as Shareholder'}
            </button>
          </div>
        </div>
      )}

      {tab==='governance' && (
        <div className="space-y-6">
          <div className="bg-white/5 rounded-lg p-6 space-y-3 max-w-md">
            <h3 className="text-white font-semibold">Create Governance Vote</h3>
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Title" value={voteTitle} onChange={e=>setVoteTitle(e.target.value)} />
            <textarea className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500 h-20 resize-none" placeholder="Description" value={voteDesc} onChange={e=>setVoteDesc(e.target.value)} />
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Expiry (days)" value={voteDays} onChange={e=>setVoteDays(e.target.value)} />
            <button onClick={()=>createGovernanceVote(voteTitle,voteDesc,BigInt(voteDays||'7'))}
              disabled={!isConnected||creating||!voteTitle}
              className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
              {creating?'Creating…':'Create Vote'}
            </button>
          </div>
          <div className="bg-white/5 rounded-lg p-6 space-y-3 max-w-md">
            <h3 className="text-white font-semibold">Cast Vote</h3>
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Vote ID" value={castId} onChange={e=>setCastId(e.target.value)} />
            <div className="flex gap-3">
              <button onClick={()=>setSupport(true)} className={support?'flex-1 bg-green-600 text-white py-2 rounded text-sm':'flex-1 bg-white/10 text-gray-400 py-2 rounded text-sm'}>For</button>
              <button onClick={()=>setSupport(false)} className={!support?'flex-1 bg-red-600 text-white py-2 rounded text-sm':'flex-1 bg-white/10 text-gray-400 py-2 rounded text-sm'}>Against</button>
            </div>
            <button onClick={()=>castVote(BigInt(castId||'0'),support)}
              disabled={!isConnected||casting||!castId}
              className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
              {casting?'Casting…':'Cast Vote'}
            </button>
          </div>
        </div>
      )}

      {tab==='lookup' && (
        <div className="space-y-4">
          <div className="bg-white/5 rounded-lg p-4">
            <h3 className="text-white font-semibold mb-3">My Holder Profile</h3>
            {holderData ? (
              <div className="text-sm space-y-1">
                {Object.entries(holderData as Record<string,unknown>).map(([k,v])=>(
                  <div key={k} className="flex justify-between py-0.5"><span className="text-gray-400">{k}</span><span className="text-white ml-2">{String(v)}</span></div>
                ))}
              </div>
            ) : <p className="text-gray-500 text-sm">Connect wallet to view profile</p>}
          </div>
          <div className="bg-white/5 rounded-lg p-4 space-y-3 max-w-md">
            <h3 className="text-white font-semibold">Lookup Vote</h3>
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Vote ID" value={lookupVoteId} onChange={e=>setLookupVoteId(e.target.value)} />
            {!!voteData && (
              <div className="text-sm space-y-1">
                {Object.entries(voteData as Record<string,unknown>).map(([k,v])=>(
                  <div key={k} className="flex justify-between py-0.5"><span className="text-gray-400">{k}</span><span className="text-white ml-2">{String(v)}</span></div>
                ))}
              </div>
            )}
            <button onClick={()=>executeVote(BigInt(lookupVoteId||'0'))}
              disabled={!isConnected||executing||!lookupVoteId}
              className="w-full bg-orange-600 hover:bg-orange-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
              {executing?'Executing…':'Execute Vote'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
