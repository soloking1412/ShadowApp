'use client';
import { useState } from 'react';
import { useAccount } from 'wagmi';
import { parseEther } from 'viem';
import {
  useICFLoanCounter, useICFTotalLoansIssued, useICFActiveLoans, useICFPlatformStats,
  useICFGScore, useICFBorrowerLoans, useICFGetLoan,
  useICFApplyICFLoan, useICFApplyFirst90, useICFProveRevenue,
  useICFApplyFFE, useICFConfirmEmployment, useICFRepayLoan,
} from '@/hooks/contracts/useICFLending';

const TIERS = ['Micro ($1M–$10M)','Small ($10M–$20M)','Medium ($20M–$80M)','Large ($80M–$200M)','Institutional ($200M–$1B)'];
const TERMS = ['5 Years','10 Years','15 Years','20 Years','30 Years','100 Years'];
type Tab = 'overview'|'icf'|'first90'|'ffe'|'repay'|'myloans';
const tc = (a:boolean) => a ? 'px-4 py-2 rounded-t text-sm font-medium bg-purple-600 text-white' : 'px-4 py-2 rounded-t text-sm font-medium text-gray-400 hover:text-white';

export default function ICFLendingDashboard() {
  const { address, isConnected } = useAccount();
  const [tab, setTab] = useState<Tab>('overview');
  const { data: loanCount } = useICFLoanCounter();
  const { data: totalIssued } = useICFTotalLoansIssued();
  const { data: active } = useICFActiveLoans();
  const { data: gScore } = useICFGScore(address);
  const { data: myLoans } = useICFBorrowerLoans(address);

  // ICF form
  const [icfTier,setIcfTier]=useState(0); const [icfPrincipal,setIcfPrincipal]=useState('');
  const [icfTerm,setIcfTerm]=useState(0); const [icfPurpose,setIcfPurpose]=useState('');

  // First90 form
  const [f90Principal,setF90Principal]=useState(''); const [f90Purpose,setF90Purpose]=useState('');
  const [proveId,setProveId]=useState('');

  // FFE form
  const [ffeCost,setFfeCost]=useState(''); const [ffeInst,setFfeInst]=useState('');
  const [empId,setEmpId]=useState('');

  // Repay form
  const [repayId,setRepayId]=useState(''); const [repayAmt,setRepayAmt]=useState('');

  // Lookup
  const [lookupLoanId,setLookupLoanId]=useState('');
  const { data: loanData } = useICFGetLoan(lookupLoanId ? BigInt(lookupLoanId) : 0n);

  const { applyICFLoan, isPending: applyingICF } = useICFApplyICFLoan();
  const { applyFirst90, isPending: applyingF90 } = useICFApplyFirst90();
  const { proveRevenue, isPending: proving } = useICFProveRevenue();
  const { applyFFE, isPending: applyingFFE } = useICFApplyFFE();
  const { confirmEmployment, isPending: confirming } = useICFConfirmEmployment();
  const { repayLoan, isPending: repaying } = useICFRepayLoan();

  const TABS: {id:Tab;label:string}[] = [
    {id:'overview',label:'Overview'},{id:'icf',label:'ICF Loan'},
    {id:'first90',label:'First90'},{id:'ffe',label:'FFE'},{id:'repay',label:'Repay'},{id:'myloans',label:'My Loans'},
  ];

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">ICF Lending</h2>
        <p className="text-gray-400 mt-1">Independent Capital Financing Platform. G-Score tiered loans, interest-free First90, Finance Forward Education (3.5% ISA), and sovereign debt restructuring.</p>
      </div>
      <div className="flex gap-2 flex-wrap border-b border-white/10 pb-2">
        {TABS.map(t=><button key={t.id} onClick={()=>setTab(t.id)} className={tc(tab===t.id)}>{t.label}</button>)}
      </div>

      {tab==='overview' && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              {label:'Total Loans',value:String(loanCount??0)},
              {label:'Loans Issued',value:String(totalIssued??0)},
              {label:'Active Loans',value:String(active??0)},
              {label:'My G-Score',value:address?String(gScore??0):'—'},
            ].map(s=>(
              <div key={s.label} className="bg-white/5 rounded-lg p-4">
                <div className="text-gray-400 text-xs mb-1">{s.label}</div>
                <div className="text-white font-semibold">{s.value}</div>
              </div>
            ))}
          </div>
          <div className="bg-white/5 rounded-lg p-4 text-sm text-gray-300 space-y-2">
            <p><span className="text-purple-400 font-semibold">ICF Standard:</span> G-Score gated. Micro=$1M-10M (8.5%), Small=$10M-20M (7%), Medium=$20M-80M (5.5%), Large=$80M-200M (4%), Institutional=$200M-1B (2.5%).</p>
            <p><span className="text-purple-400 font-semibold">First90:</span> Interest-free $5M-$10M business launch loan. Prove revenue within 90 days. +10 G-Score on success.</p>
            <p><span className="text-purple-400 font-semibold">FFE:</span> Finance Forward Education. 3.5% income share agreement. Repayment begins on employment (max 10 years).</p>
            <p><span className="text-purple-400 font-semibold">Debt Restructuring:</span> Sovereign debt at 1.5x-2x face value. 2.5%-10% interest. Owner-only origination.</p>
          </div>
        </div>
      )}

      {tab==='icf' && (
        <div className="bg-white/5 rounded-lg p-6 space-y-4 max-w-md">
          <h3 className="text-white font-semibold">Apply for ICF Standard Loan</h3>
          <p className="text-gray-400 text-xs">G-Score required: Micro=10, Small=20, Medium=35, Large=50, Institutional=70. Current G-Score: {String(gScore??0)}</p>
          <select className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm" value={icfTier} onChange={e=>setIcfTier(+e.target.value)}>
            {TIERS.map((t,i)=><option key={i} value={i}>{t}</option>)}
          </select>
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Principal (OICD, e.g. 5000000)" value={icfPrincipal} onChange={e=>setIcfPrincipal(e.target.value)} />
          <select className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm" value={icfTerm} onChange={e=>setIcfTerm(+e.target.value)}>
            {TERMS.map((t,i)=><option key={i} value={i}>{t}</option>)}
          </select>
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Purpose" value={icfPurpose} onChange={e=>setIcfPurpose(e.target.value)} />
          <button onClick={()=>applyICFLoan(icfTier,icfPrincipal?parseEther(icfPrincipal):0n,icfTerm,icfPurpose)}
            disabled={!isConnected||applyingICF||!icfPrincipal}
            className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
            {applyingICF?'Applying…':'Apply for ICF Loan'}
          </button>
        </div>
      )}

      {tab==='first90' && (
        <div className="space-y-4 max-w-md">
          <div className="bg-white/5 rounded-lg p-6 space-y-3">
            <h3 className="text-white font-semibold">First90 — Interest-Free Business Launch Loan</h3>
            <p className="text-gray-400 text-sm">$5M–$10M OICD. Zero interest. Prove revenue within 90 days to keep the loan. One active First90 per address.</p>
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Principal (OICD, 5M-10M)" value={f90Principal} onChange={e=>setF90Principal(e.target.value)} />
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Business Purpose" value={f90Purpose} onChange={e=>setF90Purpose(e.target.value)} />
            <button onClick={()=>applyFirst90(f90Principal?parseEther(f90Principal):0n,f90Purpose)}
              disabled={!isConnected||applyingF90||!f90Principal}
              className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
              {applyingF90?'Applying…':'Apply for First90'}
            </button>
          </div>
          <div className="bg-white/5 rounded-lg p-4 space-y-3">
            <h3 className="text-white font-semibold">Prove Revenue</h3>
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Loan ID" value={proveId} onChange={e=>setProveId(e.target.value)} />
            <button onClick={()=>proveRevenue(BigInt(proveId||'0'))} disabled={!isConnected||proving||!proveId}
              className="w-full bg-green-600 hover:bg-green-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
              {proving?'Submitting…':'Prove Revenue (+10 G-Score)'}
            </button>
          </div>
        </div>
      )}

      {tab==='ffe' && (
        <div className="space-y-4 max-w-md">
          <div className="bg-white/5 rounded-lg p-6 space-y-3">
            <h3 className="text-white font-semibold">Finance Forward Education (FFE)</h3>
            <p className="text-gray-400 text-sm">3.5% income share agreement. No repayment until employed. Max 10 years from employment date.</p>
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Education Cost (OICD)" value={ffeCost} onChange={e=>setFfeCost(e.target.value)} />
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Institution Name" value={ffeInst} onChange={e=>setFfeInst(e.target.value)} />
            <button onClick={()=>applyFFE(ffeCost?parseEther(ffeCost):0n,ffeInst)} disabled={!isConnected||applyingFFE||!ffeCost||!ffeInst}
              className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
              {applyingFFE?'Applying…':'Apply for FFE'}
            </button>
          </div>
          <div className="bg-white/5 rounded-lg p-4 space-y-3">
            <h3 className="text-white font-semibold">Confirm Employment (triggers repayment)</h3>
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Loan ID" value={empId} onChange={e=>setEmpId(e.target.value)} />
            <button onClick={()=>confirmEmployment(BigInt(empId||'0'))} disabled={!isConnected||confirming||!empId}
              className="w-full bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
              {confirming?'Confirming…':'Confirm Employment'}
            </button>
          </div>
        </div>
      )}

      {tab==='repay' && (
        <div className="space-y-4 max-w-md">
          <div className="bg-white/5 rounded-lg p-6 space-y-3">
            <h3 className="text-white font-semibold">Repay Loan</h3>
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Loan ID" value={repayId} onChange={e=>setRepayId(e.target.value)} />
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Amount (OICD)" value={repayAmt} onChange={e=>setRepayAmt(e.target.value)} />
            <button onClick={()=>repayLoan(BigInt(repayId||'0'),repayAmt?parseEther(repayAmt):0n)}
              disabled={!isConnected||repaying||!repayId||!repayAmt}
              className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
              {repaying?'Repaying…':'Repay Loan'}
            </button>
          </div>
          <div className="bg-white/5 rounded-lg p-4 space-y-3">
            <h3 className="text-white font-semibold">Lookup Loan</h3>
            <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Loan ID" value={lookupLoanId} onChange={e=>setLookupLoanId(e.target.value)} />
            {!!loanData && (
              <div className="text-sm space-y-1">
                {Object.entries(loanData as Record<string,unknown>).map(([k,v])=>(
                  <div key={k} className="flex justify-between py-0.5"><span className="text-gray-400">{k}</span><span className="text-white ml-2">{String(v)}</span></div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {tab==='myloans' && (
        <div className="space-y-3">
          <h3 className="text-white font-semibold">My Loans</h3>
          {(myLoans as bigint[]|undefined)?.length ? (
            <div className="flex flex-wrap gap-2">
              {(myLoans as bigint[]).map(id=>(
                <span key={id.toString()} className="bg-white/10 text-white text-sm px-3 py-1 rounded cursor-pointer hover:bg-white/20" onClick={()=>{setLookupLoanId(id.toString());setTab('repay');}}>Loan #{id.toString()}</span>
              ))}
            </div>
          ) : <p className="text-gray-500 text-sm">No loans found</p>}
        </div>
      )}
    </div>
  );
}
