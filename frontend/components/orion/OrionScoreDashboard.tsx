'use client';
import { useState } from 'react';
import { useAccount } from 'wagmi';
import {
  useOrionCountryCount, useOrionAllCountries, useOrionApprovedCountries,
  useOrionCountryScore, useOrionWeights,
  useOrionScoreCountry, useOrionUpdateVariable, useOrionRegisterCountry,
} from '@/hooks/contracts/useOrionScore';

const VARIABLES = ['Currency','Inflation','Banking','Dividend','Credit','EPS','Financial','Cashflow','Systemic'];
const WEIGHTS = [5,5,8,8,12,10,12,15,25];
type Tab = 'overview'|'score'|'update'|'lookup'|'register';
const tc = (a:boolean) => a ? 'px-4 py-2 rounded-t text-sm font-medium bg-purple-600 text-white' : 'px-4 py-2 rounded-t text-sm font-medium text-gray-400 hover:text-white';

export default function OrionScoreDashboard() {
  const { isConnected } = useAccount();
  const [tab, setTab] = useState<Tab>('overview');
  const { data: countryCount } = useOrionCountryCount();
  const { data: allCountries } = useOrionAllCountries();
  const { data: approvedCountries } = useOrionApprovedCountries();

  // Score country form
  const [scoreCode,setScoreCode]=useState('');
  const [scores,setScores]=useState<string[]>(Array(9).fill('50'));
  const [rationales,setRationales]=useState<string[]>(Array(9).fill(''));

  // Update variable form
  const [updCode,setUpdCode]=useState(''); const [updVar,setUpdVar]=useState(0);
  const [updScore,setUpdScore]=useState('50'); const [updRationale,setUpdRationale]=useState('');

  // Lookup
  const [lookupCode,setLookupCode]=useState('');
  const { data: countryScore } = useOrionCountryScore(lookupCode);

  // Register
  const [regCode,setRegCode]=useState(''); const [regName,setRegName]=useState('');

  const { scoreCountry, isPending: scoring } = useOrionScoreCountry();
  const { updateVariable, isPending: updating } = useOrionUpdateVariable();
  const { registerCountry, isPending: registering, isSuccess: registered } = useOrionRegisterCountry();

  const TABS: {id:Tab;label:string}[] = [{id:'overview',label:'Overview'},{id:'score',label:'Score Country'},{id:'update',label:'Update Variable'},{id:'lookup',label:'Lookup'},{id:'register',label:'Register'}];

  const handleScore = () => {
    scoreCountry(scoreCode, scores.map(Number), rationales);
  };

  const cs = countryScore as {compositeScore?:bigint;approved?:boolean;allocationTier?:bigint;debtMultiplier?:bigint;scores?:readonly number[];name?:string} | undefined;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Orion Algorithm</h2>
        <p className="text-gray-400 mt-1">9-variable LIFO country investment scoring. Systemic (25%) → Cashflow (15%) → Financial (12%) → Credit (12%) → EPS (10%) → Dividend (8%) → Banking (8%) → Inflation (5%) → Currency (5%).</p>
      </div>
      <div className="flex gap-2 flex-wrap border-b border-white/10 pb-2">
        {TABS.map(t=><button key={t.id} onClick={()=>setTab(t.id)} className={tc(tab===t.id)}>{t.label}</button>)}
      </div>

      {tab==='overview' && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
            {[
              {label:'Registered Countries',value:String(countryCount??0)},
              {label:'Approved for FDI',value:String((approvedCountries as string[]|undefined)?.length??0)},
              {label:'Approval Threshold',value:'Score ≥ 45'},
            ].map(s=>(
              <div key={s.label} className="bg-white/5 rounded-lg p-4">
                <div className="text-gray-400 text-xs mb-1">{s.label}</div>
                <div className="text-white font-semibold">{s.value}</div>
              </div>
            ))}
          </div>
          <div className="bg-white/5 rounded-lg p-4">
            <h3 className="text-white text-sm font-semibold mb-2">Variable Weights (LIFO: Systemic first)</h3>
            <div className="grid grid-cols-3 md:grid-cols-5 gap-2">
              {VARIABLES.map((v,i)=>(
                <div key={v} className="bg-white/5 rounded p-2 text-center">
                  <div className="text-gray-400 text-xs">{v}</div>
                  <div className="text-purple-400 font-bold">{WEIGHTS[i]}%</div>
                </div>
              ))}
            </div>
          </div>
          {!!(approvedCountries as string[]|undefined)?.length && (
            <div className="bg-white/5 rounded-lg p-4">
              <h3 className="text-white text-sm font-semibold mb-2">Approved Countries</h3>
              <div className="flex flex-wrap gap-2">
                {(approvedCountries as string[]).map(c=><span key={c} className="bg-green-500/20 text-green-300 text-xs px-2 py-1 rounded">{c}</span>)}
              </div>
            </div>
          )}
          {!!(allCountries as string[]|undefined)?.length && (
            <div className="bg-white/5 rounded-lg p-4">
              <h3 className="text-white text-sm font-semibold mb-2">All Registered</h3>
              <div className="flex flex-wrap gap-2">
                {(allCountries as string[]).map(c=><span key={c} className="bg-white/10 text-gray-300 text-xs px-2 py-1 rounded">{c}</span>)}
              </div>
            </div>
          )}
        </div>
      )}

      {tab==='score' && (
        <div className="space-y-4 max-w-lg">
          <h3 className="text-white font-semibold">Score Country (Analyst Only)</h3>
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Country Code (e.g. VE)" value={scoreCode} onChange={e=>setScoreCode(e.target.value.toUpperCase())} />
          <div className="space-y-2">
            {VARIABLES.map((v,i)=>(
              <div key={v} className="grid grid-cols-3 gap-2 items-center">
                <span className="text-gray-400 text-sm">{v} ({WEIGHTS[i]}%)</span>
                <input type="number" min="0" max="100" className="bg-white/10 rounded px-2 py-1 text-white text-sm" value={scores[i]} onChange={e=>{const s=[...scores];s[i]=e.target.value;setScores(s);}} />
                <input className="bg-white/10 rounded px-2 py-1 text-white text-xs placeholder-gray-600" placeholder="Rationale" value={rationales[i]} onChange={e=>{const r=[...rationales];r[i]=e.target.value;setRationales(r);}} />
              </div>
            ))}
          </div>
          <button onClick={handleScore} disabled={!isConnected||scoring||!scoreCode}
            className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
            {scoring?'Scoring…':'Submit Scores'}
          </button>
        </div>
      )}

      {tab==='update' && (
        <div className="bg-white/5 rounded-lg p-6 space-y-4 max-w-md">
          <h3 className="text-white font-semibold">Update Single Variable</h3>
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Country Code" value={updCode} onChange={e=>setUpdCode(e.target.value.toUpperCase())} />
          <select className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm" value={updVar} onChange={e=>setUpdVar(+e.target.value)}>
            {VARIABLES.map((v,i)=><option key={i} value={i}>{v} ({WEIGHTS[i]}%)</option>)}
          </select>
          <input type="number" min="0" max="100" className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm" placeholder="Score (0-100)" value={updScore} onChange={e=>setUpdScore(e.target.value)} />
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Rationale" value={updRationale} onChange={e=>setUpdRationale(e.target.value)} />
          <button onClick={()=>updateVariable(updCode,updVar,+updScore,updRationale)} disabled={!isConnected||updating||!updCode}
            className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
            {updating?'Updating…':'Update Variable'}
          </button>
        </div>
      )}

      {tab==='lookup' && (
        <div className="space-y-4">
          <input className="w-full max-w-xs bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Country Code" value={lookupCode} onChange={e=>setLookupCode(e.target.value.toUpperCase())} />
          {cs && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div className="bg-white/5 rounded-lg p-4"><div className="text-gray-400 text-xs mb-1">Composite Score</div><div className="text-white font-bold text-lg">{String(cs.compositeScore??0)}</div></div>
                <div className="bg-white/5 rounded-lg p-4"><div className="text-gray-400 text-xs mb-1">Approved</div><div className={cs.approved?'text-green-400 font-semibold':'text-red-400 font-semibold'}>{cs.approved?'Yes':'No'}</div></div>
                <div className="bg-white/5 rounded-lg p-4"><div className="text-gray-400 text-xs mb-1">Allocation Tier</div><div className="text-white font-semibold">{String(cs.allocationTier??0)}</div></div>
                <div className="bg-white/5 rounded-lg p-4"><div className="text-gray-400 text-xs mb-1">Debt Multiplier</div><div className="text-white font-semibold">{Number(cs.debtMultiplier??0)/100}x</div></div>
              </div>
              {cs.scores && (
                <div className="bg-white/5 rounded-lg p-4">
                  <h3 className="text-white text-sm font-semibold mb-2">Variable Scores</h3>
                  <div className="grid grid-cols-3 md:grid-cols-5 gap-2">
                    {VARIABLES.map((v,i)=>(
                      <div key={v} className="bg-white/5 rounded p-2 text-center">
                        <div className="text-gray-400 text-xs">{v}</div>
                        <div className="text-white font-bold">{cs.scores![i]??'—'}</div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {tab==='register' && (
        <div className="bg-white/5 rounded-lg p-6 space-y-4 max-w-md">
          <h3 className="text-white font-semibold">Register New Country (Owner Only)</h3>
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="ISO-2 Code" value={regCode} onChange={e=>setRegCode(e.target.value.toUpperCase().slice(0,2))} maxLength={2} />
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Country Name" value={regName} onChange={e=>setRegName(e.target.value)} />
          <button onClick={()=>registerCountry(regCode,regName)} disabled={!isConnected||registering||!regCode||!regName}
            className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
            {registering?'Registering…':registered?'✓ Registered':'Register Country'}
          </button>
        </div>
      )}
    </div>
  );
}
