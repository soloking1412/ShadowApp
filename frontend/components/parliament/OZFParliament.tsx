'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatEther, parseEther } from 'viem';
const safeEther = (v: string) => { try { return parseEther(v || '0'); } catch { return 0n; } };
const safeBig   = (v: string) => { try { return v ? BigInt(v) : 0n; } catch { return 0n; } };
import {
  useParliamentStats,
  useGetSeat,
  useChairman,
  useCreateParliamentProposal,
  useVoteOnParliamentProposal,
  useAssignSeat,
  PROPOSAL_TYPES,
} from '@/hooks/contracts/useOZFParliament';

type Tab = 'chamber' | 'propose' | 'vote' | 'seats';

export default function OZFParliamentDashboard() {
  const { address } = useAccount();
  const [tab, setTab] = useState<Tab>('chamber');

  const { activeSeats, proposalCount } = useParliamentStats();
  const { data: chairman } = useChairman();

  // Seat lookup
  const [seatNum, setSeatNum] = useState('');
  const parsedSeat = (() => { try { return seatNum ? BigInt(seatNum) : undefined; } catch { return undefined; } })();
  const { data: seatData } = useGetSeat(parsedSeat);

  // Propose form
  const [propType, setPropType] = useState(0);
  const [propTitle, setPropTitle] = useState('');
  const [propDesc, setPropDesc] = useState('');
  const [tradeBlock, setTradeBlock] = useState('');
  const [fundingAmount, setFundingAmount] = useState('');

  // Vote
  const [voteProposalId, setVoteProposalId] = useState('');
  const [voteSupport, setVoteSupport] = useState<boolean>(true);

  // Assign seat
  const [assignSeatNum, setAssignSeatNum] = useState('');
  const [assignHolder, setAssignHolder] = useState('');
  const [delegationName, setDelegationName] = useState('');
  const [tradeBlockName, setTradeBlockName] = useState('');
  const [assignJurisdiction, setAssignJurisdiction] = useState('');

  const { createProposal, isPending: proposing, isConfirming: propConfirming, isSuccess: propSuccess, error: propError } = useCreateParliamentProposal();
  const { voteOnProposal, isPending: voting, isConfirming: voteConfirming, isSuccess: voteSuccess } = useVoteOnParliamentProposal();
  const { assignSeat, isPending: assigning, isConfirming: assignConfirming, isSuccess: assignSuccess } = useAssignSeat();

  const handlePropose = () => {
    if (!propTitle) return;
    createProposal(
      propType,
      propTitle,
      propDesc,
      tradeBlock,
      safeEther(fundingAmount),
      '0x' as `0x${string}`,
    );
  };

  const handleVote = () => {
    if (!voteProposalId) return;
    voteOnProposal(safeBig(voteProposalId), voteSupport);
  };

  const handleAssign = () => {
    if (!assignSeatNum || !assignHolder) return;
    assignSeat(safeBig(assignSeatNum), assignHolder as `0x${string}`, delegationName, tradeBlockName, assignJurisdiction);
  };

  const seat = seatData as any;
  const chairAddr = chairman as string | undefined;

  const TABS: { id: Tab; label: string }[] = [
    { id: 'chamber', label: 'Chamber' },
    { id: 'propose', label: 'Propose' },
    { id: 'vote', label: 'Vote' },
    { id: 'seats', label: 'Seats' },
  ];

  const TYPE_BADGE: Record<string, string> = {
    Legislative: 'bg-blue-500/20 text-blue-400',
    Budget: 'bg-green-500/20 text-green-400',
    Treaty: 'bg-purple-500/20 text-purple-400',
    Emergency: 'bg-red-500/20 text-red-400',
    Constitutional: 'bg-amber-500/20 text-amber-400',
    Trade: 'bg-cyan-500/20 text-cyan-400',
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="glass rounded-xl p-6">
        <div className="flex items-start justify-between">
          <div>
            <h2 className="text-2xl font-bold text-white mb-1">OZF Parliament</h2>
            <p className="text-gray-400">Sovereign governance chamber — legislative proposals, trade treaties, and budget allocations</p>
          </div>
          {chairAddr && (
            <div className="text-right">
              <p className="text-xs text-gray-400">Chairman</p>
              <p className="text-sm font-mono text-primary-400">
                {chairAddr.slice(0, 6)}…{chairAddr.slice(-4)}
              </p>
            </div>
          )}
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Active Seats</p>
          <p className="text-3xl font-bold text-white">{activeSeats?.toString() ?? '—'}</p>
          <p className="text-xs text-blue-400 mt-1">Parliament members</p>
        </div>
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Total Proposals</p>
          <p className="text-3xl font-bold text-white">{proposalCount?.toString() ?? '—'}</p>
          <p className="text-xs text-green-400 mt-1">Across all types</p>
        </div>
        <div className="glass rounded-xl p-5">
          <p className="text-sm text-gray-400 mb-1">Proposal Types</p>
          <p className="text-3xl font-bold text-white">{PROPOSAL_TYPES.length}</p>
          <p className="text-xs text-purple-400 mt-1">Legislative categories</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="glass rounded-xl overflow-hidden">
        <div className="flex border-b border-white/10">
          {TABS.map((t) => (
            <button
              key={t.id}
              onClick={() => setTab(t.id)}
              className={`px-6 py-4 text-sm font-medium transition-colors ${
                tab === t.id
                  ? 'border-b-2 border-primary-500 text-white bg-white/5'
                  : 'text-gray-400 hover:text-white'
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>

        <div className="p-6">
          {/* Chamber Overview */}
          {tab === 'chamber' && (
            <div className="space-y-4">
              <h3 className="text-lg font-bold text-white">Legislative Categories</h3>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                {PROPOSAL_TYPES.map((type, i) => (
                  <div
                    key={type}
                    className="p-4 bg-white/5 border border-white/10 rounded-lg hover:bg-white/10 transition-all cursor-pointer"
                    onClick={() => { setPropType(i); setTab('propose'); }}
                  >
                    <p className="text-xs text-gray-400 mb-1">Type {i}</p>
                    <span className={`px-2 py-1 text-xs rounded font-medium ${TYPE_BADGE[type] ?? 'bg-white/10 text-white'}`}>
                      {type}
                    </span>
                  </div>
                ))}
              </div>

              <div className="p-4 bg-blue-500/10 border border-blue-500/20 rounded-lg mt-4">
                <p className="text-sm font-semibold text-white mb-2">Parliamentary Procedure</p>
                <ul className="space-y-1 text-xs text-gray-400">
                  <li>• Seat holders submit proposals via on-chain transaction</li>
                  <li>• Voting period determined by proposal type</li>
                  <li>• Simple majority for legislative, supermajority for constitutional</li>
                  <li>• Chairman can fast-track emergency proposals</li>
                  <li>• Funding allocations executed automatically on passage</li>
                </ul>
              </div>
            </div>
          )}

          {/* Propose */}
          {tab === 'propose' && (
            <div className="space-y-4 max-w-lg">
              <h3 className="text-lg font-bold text-white">Submit Proposal</h3>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Proposal Type</label>
                <select
                  value={propType}
                  onChange={(e) => setPropType(Number(e.target.value))}
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
                >
                  {PROPOSAL_TYPES.map((t, i) => (
                    <option key={t} value={i}>{t}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Title</label>
                <input
                  value={propTitle}
                  onChange={(e) => setPropTitle(e.target.value)}
                  placeholder="e.g. Amendment to Trade Corridor Act 2025"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Description</label>
                <textarea
                  value={propDesc}
                  onChange={(e) => setPropDesc(e.target.value)}
                  placeholder="Detailed description of the proposal..."
                  rows={3}
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 resize-none"
                />
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Trade Block Reference (optional)</label>
                <input
                  value={tradeBlock}
                  onChange={(e) => setTradeBlock(e.target.value)}
                  placeholder="e.g. Lagos Port Infrastructure Bond"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Funding Amount (ETH, optional)</label>
                <input
                  type="number"
                  value={fundingAmount}
                  onChange={(e) => setFundingAmount(e.target.value)}
                  placeholder="0.0"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <button
                onClick={handlePropose}
                disabled={proposing || propConfirming || !address || !propTitle}
                className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {proposing || propConfirming ? 'Submitting...' : propSuccess ? 'Proposal Submitted!' : 'Submit Proposal'}
              </button>

              {propError && (
                <p className="text-xs text-red-400 bg-red-500/10 border border-red-500/20 rounded-lg p-3">
                  {propError.message}
                </p>
              )}
            </div>
          )}

          {/* Vote */}
          {tab === 'vote' && (
            <div className="space-y-4 max-w-md">
              <h3 className="text-lg font-bold text-white">Vote on Proposal</h3>
              <p className="text-sm text-gray-400">Cast your parliamentary vote. Only seat holders may vote.</p>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Proposal ID</label>
                <input
                  type="number"
                  value={voteProposalId}
                  onChange={(e) => setVoteProposalId(e.target.value)}
                  placeholder="Proposal ID"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-2">Vote</label>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    onClick={() => setVoteSupport(true)}
                    className={`py-3 rounded-lg font-medium text-sm border transition-all ${
                      voteSupport
                        ? 'bg-green-600 border-green-500 text-white'
                        : 'bg-white/5 border-white/10 text-gray-400 hover:bg-green-600/20 hover:border-green-500/40'
                    }`}
                  >
                    Aye (Support)
                  </button>
                  <button
                    onClick={() => setVoteSupport(false)}
                    className={`py-3 rounded-lg font-medium text-sm border transition-all ${
                      !voteSupport
                        ? 'bg-red-600 border-red-500 text-white'
                        : 'bg-white/5 border-white/10 text-gray-400 hover:bg-red-600/20 hover:border-red-500/40'
                    }`}
                  >
                    Nay (Oppose)
                  </button>
                </div>
              </div>

              <button
                onClick={handleVote}
                disabled={voting || voteConfirming || !voteProposalId || !address}
                className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {voting || voteConfirming ? 'Casting Vote...' : voteSuccess ? 'Vote Cast!' : 'Cast Vote'}
              </button>

              {voteSuccess && (
                <div className="flex items-center gap-2 text-green-400 text-sm p-3 bg-green-500/10 border border-green-500/20 rounded-lg">
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  Vote recorded on-chain.
                </div>
              )}
            </div>
          )}

          {/* Seats */}
          {tab === 'seats' && (
            <div className="space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Lookup */}
                <div className="space-y-3">
                  <h3 className="text-lg font-bold text-white">Seat Lookup</h3>
                  <input
                    type="number"
                    value={seatNum}
                    onChange={(e) => setSeatNum(e.target.value)}
                    placeholder="Seat number"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                  />
                  {seat && (
                    <div className="p-4 bg-white/5 border border-white/10 rounded-lg space-y-2 text-sm">
                      <div className="flex justify-between">
                        <span className="text-gray-400">Delegation</span>
                        <span className="text-white font-semibold">{seat.delegationName}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Trade Block</span>
                        <span className="text-blue-400">{seat.tradeBlockName}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Jurisdiction</span>
                        <span className="text-purple-400">{seat.jurisdiction}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Holder</span>
                        <span className="text-white font-mono text-xs">
                          {seat.holder?.slice(0, 6)}…{seat.holder?.slice(-4)}
                        </span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Active</span>
                        <span className={seat.active ? 'text-green-400' : 'text-red-400'}>
                          {seat.active ? 'Yes' : 'No'}
                        </span>
                      </div>
                    </div>
                  )}
                </div>

                {/* Assign */}
                <div className="space-y-3">
                  <h3 className="text-lg font-bold text-white">Assign Seat</h3>
                  <p className="text-xs text-gray-400">Chairman only — assigns a parliamentary seat to a delegation.</p>
                  <input
                    type="number"
                    value={assignSeatNum}
                    onChange={(e) => setAssignSeatNum(e.target.value)}
                    placeholder="Seat number"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 text-sm"
                  />
                  <input
                    value={assignHolder}
                    onChange={(e) => setAssignHolder(e.target.value)}
                    placeholder="Holder address (0x...)"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 text-sm"
                  />
                  <input
                    value={delegationName}
                    onChange={(e) => setDelegationName(e.target.value)}
                    placeholder="Delegation name"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 text-sm"
                  />
                  <input
                    value={tradeBlockName}
                    onChange={(e) => setTradeBlockName(e.target.value)}
                    placeholder="Trade block name"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 text-sm"
                  />
                  <input
                    value={assignJurisdiction}
                    onChange={(e) => setAssignJurisdiction(e.target.value)}
                    placeholder="Jurisdiction"
                    className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 text-sm"
                  />
                  <button
                    onClick={handleAssign}
                    disabled={assigning || assignConfirming || !assignSeatNum || !assignHolder || !address}
                    className="w-full py-3 bg-primary-500 hover:bg-primary-600 text-white font-medium text-sm rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {assigning || assignConfirming ? 'Assigning...' : assignSuccess ? 'Seat Assigned!' : 'Assign Seat'}
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
