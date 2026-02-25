'use client';
import { useState, useEffect } from 'react';
import { useAccount } from 'wagmi';
import { formatEther } from 'viem';
import {
  usePreAllocTotalValidators, usePreAllocTotalShareholders, usePreAllocNetworkStats,
  usePreAllocMember, usePreAllocNextClaimAmount,
  usePreAllocValidatorSchedule, usePreAllocShareholderSchedule,
  usePreAllocRegisterAsValidator, usePreAllocRegisterAsShareholder,
  usePreAllocClaimSignupBonus, usePreAllocClaimMonthly, usePreAllocExitEarly,
} from '@/hooks/contracts/usePreAllocation';

type Tab = 'overview'|'register'|'myaccount'|'schedules';
const tc = (a:boolean) => a ? 'px-4 py-2 rounded-t text-sm font-medium bg-purple-600 text-white' : 'px-4 py-2 rounded-t text-sm font-medium text-gray-400 hover:text-white';

const VALIDATOR_SCHEDULE = ['$2M','$8M','$32M','$128M','$512M'];
const SHAREHOLDER_SCHEDULE = ['$2M','$4M','$8M','$16M','$32M','$64M','$128M','$256M'];

export default function PreAllocationDashboard() {
  const { address, isConnected } = useAccount();
  const [tab, setTab] = useState<Tab>('overview');
  const { data: totalValidators } = usePreAllocTotalValidators();
  const { data: totalShareholders } = usePreAllocTotalShareholders();
  const { data: networkStats } = usePreAllocNetworkStats();
  const { data: memberData } = usePreAllocMember(address);
  const { data: nextClaim } = usePreAllocNextClaimAmount(address);
  const { data: valSchedule } = usePreAllocValidatorSchedule();
  const { data: shrSchedule } = usePreAllocShareholderSchedule();
  const [country, setCountry] = useState('');
  const { registerAsValidator, isPending: regVPending, isSuccess: regVDone, error: regVErr } = usePreAllocRegisterAsValidator();
  const { registerAsShareholder, isPending: regSPending, isSuccess: regSDone, error: regSErr } = usePreAllocRegisterAsShareholder();
  const { claimSignupBonus, isPending: claimingBonus, isSuccess: bonusClaimed, error: bonusErr } = usePreAllocClaimSignupBonus();
  const { claimMonthlyAllocation, isPending: claimingMonthly, isSuccess: monthlyClaimed, error: monthlyErr } = usePreAllocClaimMonthly();
  const { exitEarly, isPending: exiting, isSuccess: exitDone, error: exitErr } = usePreAllocExitEarly();

  const [txError, setTxError] = useState<string | null>(null);
  const [txSuccess, setTxSuccess] = useState<string | null>(null);
  useEffect(() => {
    const err = regVErr ?? regSErr ?? bonusErr ?? monthlyErr ?? exitErr;
    if (!err) return;
    const msg = (err as {shortMessage?:string})?.shortMessage ?? (err as {message?:string})?.message ?? 'Transaction failed';
    setTxError(msg.length > 120 ? msg.slice(0, 120) + '…' : msg);
    const t = setTimeout(() => setTxError(null), 7000);
    return () => clearTimeout(t);
  }, [regVErr, regSErr, bonusErr, monthlyErr, exitErr]);
  useEffect(() => {
    if (regVDone) { setTxSuccess('Registered as Validator — 5-month compound schedule begins'); }
    else if (regSDone) { setTxSuccess('Registered as Shareholder — 8-month compound schedule begins'); }
    else if (bonusClaimed) { setTxSuccess('Signup bonus claimed — $150,000 OICD credited to your account'); }
    else if (monthlyClaimed) { setTxSuccess('Monthly allocation claimed successfully'); }
    else if (exitDone) { setTxSuccess('Exited early — locked OICD forfeited, free balance retained'); }
    else return;
    const t = setTimeout(() => setTxSuccess(null), 5000);
    return () => clearTimeout(t);
  }, [regVDone, regSDone, bonusClaimed, monthlyClaimed, exitDone]);

  const stats = networkStats as readonly [bigint,bigint,bigint,bigint,bigint,bigint,bigint] | undefined;
  const member = memberData as {addr?:string;memberType?:number;status?:number;monthsClaimed?:number;freeOICD?:bigint;lockedOICD?:bigint;totalAllocated?:bigint;signupBonusClaimed?:boolean;exited?:boolean;country?:string} | undefined;
  const next = nextClaim as readonly [bigint,bigint] | undefined;
  const progressPct = stats ? Math.min(Number(stats[6]),100) : 0;
  const TABS: {id:Tab;label:string}[] = [{id:'overview',label:'Overview'},{id:'register',label:'Register'},{id:'myaccount',label:'My Account'},{id:'schedules',label:'Schedules'}];
  const MEMBER_TYPES = ['—','Validator','Shareholder'];
  const STATUSES = ['Registered','Active','Completed','Exited'];

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
      <div className="bg-gradient-to-r from-purple-900/40 to-violet-900/40 border border-purple-700/50 rounded-xl p-6 space-y-4">
        <div>
          <h2 className="text-2xl font-bold text-white">Pre-Allocation System</h2>
          <p className="text-gray-400 mt-1 text-sm">Obsidian Capital compound allocation program. Validator: 5-month 4× schedule ($2M→$512M). Shareholder: 8-month 2× schedule ($2M→$256M). Signup bonus: $150K OICD.</p>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {[
            { label: 'Validators', value: String(totalValidators??0) },
            { label: 'Shareholders', value: String(totalShareholders??0) },
            { label: 'Network Pool (OICD)', value: stats?formatEther(stats[3]).split('.')[0]:'0' },
            { label: 'Progress', value: progressPct+'%' },
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
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              {label:'Validators',value:String(totalValidators??0)},
              {label:'Shareholders',value:String(totalShareholders??0)},
              {label:'Network Pool (OICD)',value:stats?formatEther(stats[3]).split('.')[0]:'0'},
              {label:'Progress',value:progressPct+'%'},
            ].map(s=>(
              <div key={s.label} className="bg-white/5 rounded-lg p-4">
                <div className="text-gray-400 text-xs mb-1">{s.label}</div>
                <div className="text-white font-semibold">{s.value}</div>
              </div>
            ))}
          </div>
          <div className="bg-white/5 rounded-lg p-4">
            <div className="flex justify-between text-sm mb-1">
              <span className="text-gray-400">Progress to 250,000 Validators</span>
              <span className="text-white">{progressPct}%</span>
            </div>
            <div className="w-full bg-white/10 rounded-full h-3">
              <div className="bg-purple-600 h-3 rounded-full transition-all" style={{width:`${progressPct}%`}} />
            </div>
            <p className="text-gray-500 text-xs mt-1">250,000 validators = $343 Trillion locked OICD in network pool</p>
          </div>
          <div className="bg-white/5 rounded-lg p-4 text-sm text-gray-300 space-y-1">
            <p><span className="text-purple-400 font-semibold">Signup Bonus:</span> $150,000 OICD immediately upon profile completion</p>
            <p><span className="text-purple-400 font-semibold">Validator:</span> 5-month 4x compound. 2/3 locked into network pool, 1/3 free.</p>
            <p><span className="text-purple-400 font-semibold">Shareholder:</span> 8-month 2x compound. All OICD free (no lock).</p>
          </div>
        </div>
      )}

      {tab==='register' && (
        <div className="space-y-4 max-w-md">
          <input className="w-full bg-white/10 rounded px-3 py-2 text-white text-sm placeholder-gray-500" placeholder="Country / Region" value={country} onChange={e=>setCountry(e.target.value)} />
          <div className="bg-white/5 rounded-lg p-6 space-y-3">
            <h3 className="text-white font-semibold">Register as Validator</h3>
            <p className="text-gray-400 text-sm">5 months. 4x compound: $2M → $8M → $32M → $128M → $512M OICD total $2.048B. 2/3 locked into network liquidity pool.</p>
            <button onClick={()=>registerAsValidator(country)} disabled={!isConnected||regVPending||!country}
              className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
              {regVPending?'Registering…':regVDone?'✓ Registered':'Register as Validator'}
            </button>
          </div>
          <div className="bg-white/5 rounded-lg p-6 space-y-3">
            <h3 className="text-white font-semibold">Register as Shareholder</h3>
            <p className="text-gray-400 text-sm">8 months. 2x compound: $2M → $4M → $8M → $16M → $32M → $64M → $128M → $256M OICD. All free.</p>
            <button onClick={()=>registerAsShareholder(country)} disabled={!isConnected||regSPending||!country}
              className="w-full bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
              {regSPending?'Registering…':regSDone?'✓ Registered':'Register as Shareholder'}
            </button>
          </div>
        </div>
      )}

      {tab==='myaccount' && (
        <div className="space-y-4 max-w-md">
          {member?.memberType ? (
            <>
              <div className="bg-white/5 rounded-lg p-4 grid grid-cols-2 gap-3 text-sm">
                <div><span className="text-gray-400">Type</span><div className="text-white font-semibold">{MEMBER_TYPES[member.memberType??0]}</div></div>
                <div><span className="text-gray-400">Status</span><div className="text-white font-semibold">{STATUSES[member.status??0]}</div></div>
                <div><span className="text-gray-400">Months Claimed</span><div className="text-white font-semibold">{member.monthsClaimed??0}</div></div>
                <div><span className="text-gray-400">Country</span><div className="text-white font-semibold">{member.country||'—'}</div></div>
                <div><span className="text-gray-400">Free OICD</span><div className="text-white font-semibold">{member.freeOICD?formatEther(member.freeOICD).split('.')[0]:'0'}</div></div>
                <div><span className="text-gray-400">Locked OICD</span><div className="text-white font-semibold">{member.lockedOICD?formatEther(member.lockedOICD).split('.')[0]:'0'}</div></div>
                <div className="col-span-2"><span className="text-gray-400">Total Allocated</span><div className="text-white font-semibold">{member.totalAllocated?formatEther(member.totalAllocated).split('.')[0]:'0'} OICD</div></div>
              </div>
              {next && next[0] > 0n && (
                <div className="bg-purple-600/10 border border-purple-600/30 rounded-lg p-3 text-sm">
                  <span className="text-gray-400">Next Claim: </span>
                  <span className="text-purple-400 font-semibold">{formatEther(next[0]).split('.')[0]} OICD</span>
                  <span className="text-gray-400"> ({String(next[1])} months remaining)</span>
                </div>
              )}
              <div className="space-y-2">
                {!member.signupBonusClaimed && (
                  <button onClick={()=>claimSignupBonus()} disabled={!isConnected||claimingBonus}
                    className="w-full bg-green-600 hover:bg-green-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
                    {claimingBonus?'Claiming…':bonusClaimed?'✓ Claimed':'Claim Signup Bonus ($150K OICD)'}
                  </button>
                )}
                <button onClick={()=>claimMonthlyAllocation()} disabled={!isConnected||claimingMonthly||member.exited}
                  className="w-full bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
                  {claimingMonthly?'Claiming…':monthlyClaimed?'✓ Claimed':'Claim Monthly Allocation'}
                </button>
                {!member.exited && (
                  <button onClick={()=>exitEarly()} disabled={!isConnected||exiting}
                    className="w-full bg-red-600/80 hover:bg-red-700 disabled:opacity-50 text-white py-2 rounded text-sm font-medium">
                    {exiting?'Exiting…':'Exit Early (forfeit locked OICD)'}
                  </button>
                )}
              </div>
            </>
          ) : <p className="text-gray-500 text-sm">Not registered. Go to Register tab to join.</p>}
        </div>
      )}

      {tab==='schedules' && (
        <div className="grid md:grid-cols-2 gap-6">
          <div className="bg-white/5 rounded-lg p-4">
            <h3 className="text-white font-semibold mb-3">Validator Schedule (4x Compound)</h3>
            <table className="w-full text-sm">
              <thead><tr><th className="text-gray-400 text-left pb-2">Month</th><th className="text-gray-400 text-right pb-2">OICD</th><th className="text-gray-400 text-right pb-2">Locked (2/3)</th></tr></thead>
              <tbody>
                {VALIDATOR_SCHEDULE.map((amt,i)=>(
                  <tr key={i} className="border-t border-white/5">
                    <td className="py-2 text-white">{i+1}</td>
                    <td className="py-2 text-right text-purple-400 font-semibold">{amt}</td>
                    <td className="py-2 text-right text-gray-400">{['$1.33M','$5.33M','$21.33M','$85.33M','$341.33M'][i]}</td>
                  </tr>
                ))}
                <tr className="border-t border-white/10"><td className="py-2 text-gray-400 font-semibold">Total</td><td className="py-2 text-right text-white font-bold">$2.048B</td><td className="py-2 text-right text-gray-400">$1.372B</td></tr>
              </tbody>
            </table>
          </div>
          <div className="bg-white/5 rounded-lg p-4">
            <h3 className="text-white font-semibold mb-3">Shareholder Schedule (2x Compound)</h3>
            <table className="w-full text-sm">
              <thead><tr><th className="text-gray-400 text-left pb-2">Month</th><th className="text-gray-400 text-right pb-2">OICD (all free)</th></tr></thead>
              <tbody>
                {SHAREHOLDER_SCHEDULE.map((amt,i)=>(
                  <tr key={i} className="border-t border-white/5">
                    <td className="py-2 text-white">{i+1}</td>
                    <td className="py-2 text-right text-indigo-400 font-semibold">{amt}</td>
                  </tr>
                ))}
                <tr className="border-t border-white/10"><td className="py-2 text-gray-400 font-semibold">Total</td><td className="py-2 text-right text-white font-bold">$510M</td></tr>
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
