'use client';
import { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatEther, parseEther } from 'viem';
import {
  useJobsBoardJobCounter, useJobsBoardTotalPosted, useJobsBoardTotalCompleted, useJobsBoardStats,
  useJobsBoardGetJob, useJobsBoardWorkerProfile, useJobsBoardPosterJobs,
  useJobsBoardPostJob, useJobsBoardApplyForJob, useJobsBoardHireWorker,
  useJobsBoardMarkComplete, useJobsBoardCancelJob,
} from '@/hooks/contracts/useJobsBoard';

const JOB_LEVELS = ['Small (1-15K)','Medium (15K-35K)','Large (35K-70K)','Alpha (100K-1M)','Bravo (10M+)','Charlie (stock)','Delta (stock)','Echo (stock+%)'];
const JOB_CATEGORIES = ['Finance','Marketing','Technology','Creative','Videography','DataAnalysis','Infrastructure','Research','Legal','Operations'];
const CLEARANCES = ['None','Alpha','Bravo','Charlie','Delta','Echo'];
const STATUSES = ['Open','Filled','InProgress','Completed','Cancelled','Disputed'];
const STATUS_COLORS: Record<number,string> = {0:'text-green-400',1:'text-yellow-400',2:'text-blue-400',3:'text-purple-400',4:'text-gray-400',5:'text-red-400'};

type Tab = 'overview'|'post'|'apply'|'myjobs'|'profile'|'lookup';
const tc = (a:boolean) => a ? 'px-4 py-2 rounded-t text-sm font-medium bg-purple-600 text-white' : 'px-4 py-2 rounded-t text-sm font-medium text-gray-400 hover:text-white';

export default function JobsBoardDashboard() {
  const { address, isConnected } = useAccount();
  const [tab, setTab] = useState<Tab>('overview');
  const { data: jobCount } = useJobsBoardJobCounter();
  const { data: totalPosted } = useJobsBoardTotalPosted();
  const { data: totalCompleted } = useJobsBoardTotalCompleted();
  const { data: boardStats } = useJobsBoardStats();
  const { data: myPostedJobs } = useJobsBoardPosterJobs(address);
  const { data: workerProfile } = useJobsBoardWorkerProfile(address);

  // Post job form
  const [pLevel,setPLevel]=useState(0); const [pCat,setPCat]=useState(0);
  const [pTitle,setPTitle]=useState(''); const [pDesc,setPDesc]=useState('');
  const [pPay,setPPay]=useState(''); const [pStock,setPStock]=useState('0');
  const [pBreak,setPBreak]=useState('0'); const [pClear,setPClear]=useState(0);
  const [pDays,setPDays]=useState('30'); const [pIpfs,setPIpfs]=useState('');

  // Apply form
  const [applyJobId,setApplyJobId]=useState(''); const [coverNote,setCoverNote]=useState('');

  // Hire / Complete / Cancel
  const [hireJobId,setHireJobId]=useState(''); const [hireWorker,setHireWorker]=useState('');
  const [completeJobId,setCompleteJobId]=useState(''); const [cancelJobId,setCancelJobId]=useState('');

  // Lookup
  const [lookupId,setLookupId]=useState('');
  const { data: jobData } = useJobsBoardGetJob(lookupId ? BigInt(lookupId) : 0n);

  const { postJob, isPending: posting, isSuccess: posted } = useJobsBoardPostJob();
  const { applyForJob, isPending: applying } = useJobsBoardApplyForJob();
  const { hireWorker: hireWorkerFn, isPending: hiring } = useJobsBoardHireWorker();
  const { markJobComplete, isPending: completing } = useJobsBoardMarkComplete();
  const { cancelJob, isPending: cancelling } = useJobsBoardCancelJob();

  const stats = boardStats as readonly [bigint,bigint,bigint,bigint] | undefined;
  const wp = workerProfile as {reputationScore?:number;jobsCompleted?:number;clearance?:number;totalEarnedOICD?:bigint;exists?:boolean} | undefined;

  const TABS: {id:Tab;label:string}[] = [{id:'overview',label:'Overview'},{id:'post',label:'Post Job'},{id:'apply',label:'Apply'},{id:'myjobs',label:'My Jobs'},{id:'profile',label:'Worker Profile'},{id:'lookup',label:'Lookup'}];

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Jobs Board</h2>
        <p className="text-gray-400 mt-1">OICD Employment Marketplace. 8 job levels from Small (1K OICD) to Echo (stock + recurring revenue %). 5 clearance levels for special contracts.</p>
      </div>
      <div className="flex gap-2 flex-wrap border-b border-white/10 pb-2">
        {TABS.map(t=><button key={t.id} onClick={()=>setTab(t.id)} className={tc(tab===t.id)}>{t.label}</button>)}
      </div>

      {tab==='overview' && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              {label:'Total Jobs',value:String(jobCount??0)},
              {label:'Jobs Completed',value:String(totalCompleted??0)},
              {label:'OICD Distributed',value:stats?formatEther(stats[2]).split('.')[0]+'…':'0'},
              {label:'Stock Distributed',value:stats?String(stats[3]):'0'},
            ].map(s=>(
              <div key={s.label} className="bg-white/5 rounded-lg p-4">
                <div className="text-gray-400 text-xs mb-1">{s.label}</div>
                <div className="text-white font-semibold">{s.value}</div>
              </div>
            ))}
          </div>
          <div className="bg-white/5 rounded-lg p-4 text-sm text-gray-300 space-y-1">
            <p><span className="text-purple-400 font-semibold">Standard:</span> Small (1–15K OICD) · Medium (15K–35K) · Large (35K–70K)</p>
            <p><span className="text-purple-400 font-semibold">Special Contracts:</span> Alpha (100K–1M) · Bravo (10M+ + management clearance) · Charlie (30K–70K OTD stock) · Delta (1M–10M OTD stock) · Echo (stock + break % recurring)</p>
            <p><span className="text-purple-400 font-semibold">Categories:</span> Finance, Marketing, Technology, Creative, Videography, Data Analysis, Infrastructure, Research, Legal, Operations</p>
          </div>
        </div>
      )}

      {tab==='post' && (
        <div className="bg-white/5 rounded-lg p-6 space-y-3 max-w-lg">
          <h3 className="text-white font-semibold">Post a Job (Authorized Posters Only)</h3>
          <div className="grid grid-cols-2 gap-2">
            <select className="bg-white/10 rounded px-3 py-2 text-white text-sm" value={pLevel} onChange={e=>setPLevel(+e.target.value)}>
              {JOB_LEVELS.map((l,i)=><option key={i} value={i}>{l}</option>)}
            </select>
            <select className="bg-white/10 rounded px-3 py-2 text-white text-sm" value={pCat} onChange={e=>setPCat(+e.target.value)}>
              {JOB_CATEGORIES.map((c,i)=><option key={i} value={i}>{c}</option>)}
            </select>
          </div>
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Job Title" value={pTitle} onChange={e=>setPTitle(e.target.value)} />
          <textarea className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500 h-20 resize-none" placeholder="Description" value={pDesc} onChange={e=>setPDesc(e.target.value)} />
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Pay (OICD, e.g. 10000)" value={pPay} onChange={e=>setPPay(e.target.value)} />
          <div className="grid grid-cols-3 gap-2">
            <input className="bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Stock Units" value={pStock} onChange={e=>setPStock(e.target.value)} />
            <input className="bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Break% (bps)" value={pBreak} onChange={e=>setPBreak(e.target.value)} />
            <input className="bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Days" value={pDays} onChange={e=>setPDays(e.target.value)} />
          </div>
          <div className="grid grid-cols-2 gap-2">
            <select className="bg-white/10 rounded px-3 py-2 text-white text-sm" value={pClear} onChange={e=>setPClear(+e.target.value)}>
              {CLEARANCES.map((c,i)=><option key={i} value={i}>Clearance: {c}</option>)}
            </select>
            <input className="bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="IPFS Details (optional)" value={pIpfs} onChange={e=>setPIpfs(e.target.value)} />
          </div>
          <button onClick={()=>postJob(pLevel,pCat,pTitle,pDesc,pPay?parseEther(pPay):0n,BigInt(pStock||'0'),BigInt(pBreak||'0'),pClear,BigInt(pDays||'30'),pIpfs)}
            disabled={!isConnected||posting||!pTitle||!pPay}
            className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
            {posting?'Posting…':posted?'✓ Posted':'Post Job'}
          </button>
        </div>
      )}

      {tab==='apply' && (
        <div className="bg-white/5 rounded-lg p-6 space-y-4 max-w-md">
          <h3 className="text-white font-semibold">Apply for a Job</h3>
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Job ID" value={applyJobId} onChange={e=>setApplyJobId(e.target.value)} />
          <textarea className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500 h-24 resize-none" placeholder="Cover Note" value={coverNote} onChange={e=>setCoverNote(e.target.value)} />
          <button onClick={()=>applyForJob(BigInt(applyJobId||'0'),coverNote)}
            disabled={!isConnected||applying||!applyJobId||!coverNote}
            className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
            {applying?'Applying…':'Apply for Job'}
          </button>
        </div>
      )}

      {tab==='myjobs' && (
        <div className="space-y-4">
          <h3 className="text-white font-semibold">My Posted Jobs</h3>
          {(myPostedJobs as bigint[]|undefined)?.length ? (
            <div className="space-y-2">
              {(myPostedJobs as bigint[]).map(id=>(
                <div key={id.toString()} className="bg-white/5 rounded-lg p-3 flex items-center justify-between">
                  <span className="text-white text-sm">Job #{id.toString()}</span>
                  <div className="flex gap-2">
                    <input className="bg-white/10 rounded px-2 py-1 text-white text-xs w-32 placeholder-gray-600" placeholder="Worker (0x...)" value={hireJobId===id.toString()?hireWorker:''} onChange={e=>{setHireJobId(id.toString());setHireWorker(e.target.value);}} />
                    <button onClick={()=>hireWorkerFn(id,hireWorker as `0x${string}`)} disabled={hiring||!hireWorker} className="bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white px-2 py-1 rounded text-xs">{hiring?'…':'Hire'}</button>
                    <button onClick={()=>markJobComplete(id)} disabled={completing} className="bg-green-600 hover:bg-green-700 disabled:opacity-50 text-white px-2 py-1 rounded text-xs">{completing?'…':'Complete'}</button>
                    <button onClick={()=>cancelJob(id)} disabled={cancelling} className="bg-red-600/70 hover:bg-red-700 disabled:opacity-50 text-white px-2 py-1 rounded text-xs">{cancelling?'…':'Cancel'}</button>
                  </div>
                </div>
              ))}
            </div>
          ) : <p className="text-gray-500 text-sm">No posted jobs</p>}
        </div>
      )}

      {tab==='profile' && (
        <div className="space-y-4 max-w-md">
          <h3 className="text-white font-semibold">My Worker Profile</h3>
          {wp?.exists ? (
            <div className="bg-white/5 rounded-lg p-4 grid grid-cols-2 gap-4 text-sm">
              <div><span className="text-gray-400 block">Jobs Completed</span><span className="text-white font-semibold">{wp.jobsCompleted??0}</span></div>
              <div><span className="text-gray-400 block">Reputation</span><span className="text-white font-semibold">{wp.reputationScore??0}/100</span></div>
              <div><span className="text-gray-400 block">Clearance</span><span className="text-white font-semibold">{CLEARANCES[wp.clearance??0]}</span></div>
              <div><span className="text-gray-400 block">Total OICD Earned</span><span className="text-white font-semibold">{wp.totalEarnedOICD?formatEther(wp.totalEarnedOICD).split('.')[0]:'0'}</span></div>
            </div>
          ) : <p className="text-gray-500 text-sm">No worker profile. Apply for a job to create one.</p>}
        </div>
      )}

      {tab==='lookup' && (
        <div className="space-y-4">
          <input className="w-full max-w-xs bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Job ID" value={lookupId} onChange={e=>setLookupId(e.target.value)} />
          {!!jobData && (() => {
            const j = jobData as {jobId?:bigint;poster?:string;level?:number;category?:number;status?:number;title?:string;payOICD?:bigint;stockUnits?:bigint;assignedWorker?:string};
            return (
              <div className="bg-white/5 rounded-lg p-4 space-y-2 text-sm">
                <div className="flex justify-between"><span className="text-gray-400">Title</span><span className="text-white">{j.title}</span></div>
                <div className="flex justify-between"><span className="text-gray-400">Level</span><span className="text-white">{JOB_LEVELS[j.level??0]}</span></div>
                <div className="flex justify-between"><span className="text-gray-400">Category</span><span className="text-white">{JOB_CATEGORIES[j.category??0]}</span></div>
                <div className="flex justify-between"><span className="text-gray-400">Status</span><span className={STATUS_COLORS[j.status??0]}>{STATUSES[j.status??0]}</span></div>
                <div className="flex justify-between"><span className="text-gray-400">Pay (OICD)</span><span className="text-white">{j.payOICD?formatEther(j.payOICD).split('.')[0]:'0'}</span></div>
                <div className="flex justify-between"><span className="text-gray-400">Stock Units</span><span className="text-white">{String(j.stockUnits??0)}</span></div>
                <div className="flex justify-between"><span className="text-gray-400">Assigned Worker</span><span className="text-white truncate ml-2">{j.assignedWorker}</span></div>
                <div className="flex justify-between"><span className="text-gray-400">Poster</span><span className="text-white truncate ml-2">{j.poster}</span></div>
              </div>
            );
          })()}
        </div>
      )}
    </div>
  );
}
