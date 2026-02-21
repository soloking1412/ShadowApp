'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { CONTRACTS, PROPOSAL_CATEGORIES, MINISTRY_TYPES } from '@/lib/contracts';
import {
  useProposalCounter,
  useGetAllMinistries,
  usePropose,
  useCastDAOVote,
  useCastMinistryVote,
} from '@/hooks/contracts/useSovereignInvestmentDAO';

const safeBig = (v: string) => { try { return v ? BigInt(v) : 0n; } catch { return 0n; } };

export default function GovernanceDashboard() {
  const { address } = useAccount();
  const [activeTab, setActiveTab] = useState<'proposals' | 'create' | 'ministries'>('proposals');

  const [category, setCategory] = useState(0);
  const [description, setDescription] = useState('');

  // Live contract reads
  const { data: proposalCounter } = useProposalCounter();
  const { data: allMinistries } = useGetAllMinistries();

  // Write hooks using the new DAO hook
  const { propose, isPending: proposing, isConfirming: confirmingProposal, isSuccess: proposalSuccess, error: proposeError } = usePropose();
  const { castDAOVote, isPending: voting } = useCastDAOVote();
  const { castMinistryVote, isPending: mVoting } = useCastMinistryVote();

  const notDeployed = !CONTRACTS.SovereignInvestmentDAO;

  const handleCreateProposal = () => {
    if (!description) return;
    // propose(targets[], values[], calldatas[], description, category)
    propose([], [], [], description, category);
  };

  // Mock proposals for display — fresh Anvil deploy has no proposals
  const mockProposals = [
    {
      id: '1',
      category: 'Infrastructure',
      description: 'Allocate $50B for high-speed rail network expansion across 15 countries',
      budgetImpact: '$50,000,000,000',
      forVotes: '487', againstVotes: '123', abstainVotes: '45',
      endTime: new Date(Date.now() + 172800000).toLocaleDateString(),
      state: 'Active', ministryApprovals: '68%', requiresMinistryApproval: true,
    },
    {
      id: '2',
      category: 'Treasury',
      description: 'Increase reserve ratio for OICD from 20% to 25% to strengthen stability',
      budgetImpact: '$0',
      forVotes: '892', againstVotes: '234', abstainVotes: '78',
      endTime: new Date(Date.now() + 86400000).toLocaleDateString(),
      state: 'Active', ministryApprovals: '82%', requiresMinistryApproval: true,
    },
    {
      id: '3',
      category: 'Policy',
      description: 'Implement new KYC requirements for dark pool traders exceeding $10M volume',
      budgetImpact: '$2,500,000',
      forVotes: '1245', againstVotes: '89', abstainVotes: '34',
      endTime: new Date(Date.now() + 259200000).toLocaleDateString(),
      state: 'Active', ministryApprovals: 'N/A', requiresMinistryApproval: false,
    },
  ];

  // Ministries: use on-chain data if available, else fallback mock
  const mockMinistries = [
    { name: 'Treasury',        type: MINISTRY_TYPES.Treasury,        weight: 20, proposalsVoted: 48 },
    { name: 'Finance',         type: MINISTRY_TYPES.Finance,         weight: 18, proposalsVoted: 52 },
    { name: 'Infrastructure',  type: MINISTRY_TYPES.Infrastructure,  weight: 15, proposalsVoted: 44 },
    { name: 'Trade',           type: MINISTRY_TYPES.Trade,           weight: 13, proposalsVoted: 39 },
    { name: 'Defense',         type: MINISTRY_TYPES.Defense,         weight: 12, proposalsVoted: 28 },
    { name: 'Energy',          type: MINISTRY_TYPES.Energy,          weight: 12, proposalsVoted: 35 },
    { name: 'Technology',      type: MINISTRY_TYPES.Technology,      weight: 10, proposalsVoted: 41 },
  ];

  const ministriesData = (allMinistries as unknown[])?.length
    ? (allMinistries as { name: string; weight: bigint }[]).map((m) => ({
        name: m.name,
        weight: Number(m.weight),
        proposalsVoted: 0,
      }))
    : mockMinistries;

  return (
    <div className="space-y-6">
      <div className="glass rounded-xl p-6">
        <h2 className="text-2xl font-bold text-white mb-2">Sovereign Investment DAO</h2>
        <p className="text-gray-400 mb-6">Decentralized governance with ministry voting system</p>

        {notDeployed && (
          <div className="mb-4 p-3 bg-yellow-500/10 border border-yellow-500/30 rounded-lg text-yellow-400 text-sm">
            Contract not deployed — deploy via docker compose to enable governance transactions.
          </div>
        )}

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="p-4 bg-gradient-to-br from-blue-500/20 to-blue-600/20 border border-blue-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Total Proposals</p>
            <p className="text-3xl font-bold text-white">
              {proposalCounter !== undefined ? String(proposalCounter) : '—'}
            </p>
            <p className="text-xs text-blue-400 mt-1">On-chain</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-green-500/20 to-green-600/20 border border-green-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Active Proposals</p>
            <p className="text-3xl font-bold text-white">{mockProposals.length}</p>
            <p className="text-xs text-green-400 mt-1">Demo</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-purple-500/20 to-purple-600/20 border border-purple-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Ministries</p>
            <p className="text-3xl font-bold text-white">{ministriesData.length}</p>
            <p className="text-xs text-purple-400 mt-1">Active members</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-amber-500/20 to-amber-600/20 border border-amber-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Quorum</p>
            <p className="text-3xl font-bold text-white">55%</p>
            <p className="text-xs text-amber-400 mt-1">Ministry approval</p>
          </div>
        </div>
      </div>

      <div className="glass rounded-xl p-6">
        <div className="flex gap-2 mb-6">
          {(['proposals', 'create', 'ministries'] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`px-6 py-3 rounded-lg font-semibold transition-all ${
                activeTab === tab ? 'bg-primary-500 text-white' : 'bg-white/5 text-gray-400 hover:bg-white/10'
              }`}
            >
              {tab === 'proposals' ? 'Active Proposals' : tab === 'create' ? 'Create Proposal' : 'Ministries'}
            </button>
          ))}
        </div>

        {activeTab === 'proposals' && (
          <div className="space-y-4">
            {mockProposals.map((proposal) => (
              <div key={proposal.id} className="p-5 bg-white/5 hover:bg-white/10 border border-white/10 rounded-lg transition-all">
                <div className="flex items-start justify-between mb-3">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-2">
                      <span className="px-3 py-1 bg-blue-500/20 text-blue-400 text-xs font-semibold rounded">{proposal.category}</span>
                      <span className="px-3 py-1 bg-green-500/20 text-green-400 text-xs font-semibold rounded">{proposal.state}</span>
                      {proposal.requiresMinistryApproval && (
                        <span className="px-3 py-1 bg-purple-500/20 text-purple-400 text-xs font-semibold rounded">Ministry Vote</span>
                      )}
                    </div>
                    <h4 className="text-lg font-bold text-white mb-2">Proposal #{proposal.id}</h4>
                    <p className="text-sm text-gray-300 mb-3">{proposal.description}</p>
                    <div className="flex items-center gap-4 text-xs text-gray-400">
                      <span>Budget: <span className="text-amber-400 font-semibold">{proposal.budgetImpact}</span></span>
                      <span>Ends: <span className="text-white">{proposal.endTime}</span></span>
                      {proposal.requiresMinistryApproval && (
                        <span>Ministry: <span className="text-purple-400 font-semibold">{proposal.ministryApprovals}</span></span>
                      )}
                    </div>
                  </div>
                </div>

                <div className="space-y-2 mb-4">
                  {[
                    { label: `${proposal.forVotes} For`, pct: 78, color: 'bg-green-500', textColor: 'text-green-400' },
                    { label: `${proposal.againstVotes} Against`, pct: 20, color: 'bg-red-500', textColor: 'text-red-400' },
                    { label: `${proposal.abstainVotes} Abstain`, pct: 7, color: 'bg-gray-500', textColor: 'text-gray-400' },
                  ].map(({ label, pct, color, textColor }) => (
                    <div key={label} className="flex items-center gap-2">
                      <div className="flex-1 bg-white/10 rounded-full h-2 overflow-hidden">
                        <div className={`h-full ${color}`} style={{ width: `${pct}%` }} />
                      </div>
                      <span className={`text-xs ${textColor} font-semibold w-24 text-right`}>{label}</span>
                    </div>
                  ))}
                </div>

                <div className="flex gap-2">
                  {([
                    { label: 'Vote For', support: 1 as const, cls: 'bg-green-500/20 hover:bg-green-500/30 text-green-400' },
                    { label: 'Vote Against', support: 0 as const, cls: 'bg-red-500/20 hover:bg-red-500/30 text-red-400' },
                    { label: 'Abstain', support: 2 as const, cls: 'bg-gray-500/20 hover:bg-gray-500/30 text-gray-400' },
                  ] as const).map(({ label, support, cls }) => (
                    <button
                      key={label}
                      onClick={() => castDAOVote(safeBig(proposal.id), support)}
                      disabled={voting || notDeployed || !address}
                      className={`flex-1 py-2 font-semibold rounded-lg transition-all disabled:opacity-50 ${cls}`}
                    >
                      {label}
                    </button>
                  ))}
                </div>

                {proposal.requiresMinistryApproval && address && (
                  <div className="mt-3 pt-3 border-t border-white/10 flex gap-2">
                    <button
                      onClick={() => castMinistryVote(safeBig(proposal.id), 0n, 1)}
                      disabled={mVoting || notDeployed}
                      className="flex-1 py-2 bg-purple-500/20 hover:bg-purple-500/30 text-purple-400 font-semibold rounded-lg transition-all text-sm disabled:opacity-50"
                    >
                      Ministry Approve
                    </button>
                    <button
                      onClick={() => castMinistryVote(safeBig(proposal.id), 0n, 0)}
                      disabled={mVoting || notDeployed}
                      className="flex-1 py-2 bg-red-500/20 hover:bg-red-500/30 text-red-400 font-semibold rounded-lg transition-all text-sm disabled:opacity-50"
                    >
                      Ministry Reject
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}

        {activeTab === 'create' && (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Proposal Category</label>
              <select
                value={category}
                onChange={(e) => setCategory(Number(e.target.value))}
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
              >
                <option value={PROPOSAL_CATEGORIES.Treasury}>Treasury</option>
                <option value={PROPOSAL_CATEGORIES.Infrastructure}>Infrastructure</option>
                <option value={PROPOSAL_CATEGORIES.Policy}>Policy</option>
                <option value={PROPOSAL_CATEGORIES.Emergency}>Emergency</option>
                <option value={PROPOSAL_CATEGORIES.Upgrade}>Upgrade</option>
                <option value={PROPOSAL_CATEGORIES.Parameter}>Parameter</option>
                <option value={PROPOSAL_CATEGORIES.Ministry}>Ministry</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Description</label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Detailed proposal description..."
                rows={6}
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 resize-none"
              />
            </div>

            <div className="p-4 bg-blue-500/10 border border-blue-500/20 rounded-lg">
              <p className="text-sm font-medium text-white mb-2">Governance Requirements</p>
              <ul className="space-y-1 text-xs text-gray-400">
                <li>• Treasury, Infrastructure &amp; Emergency proposals require ministry approval</li>
                <li>• Ministry quorum: 55% for standard, 60% for emergency</li>
                <li>• Voting period: Configurable (default 7 days)</li>
                <li>• Execution delay: Time-locked for security</li>
              </ul>
            </div>

            {proposeError && (
              <p className="text-red-400 text-sm">{(proposeError as Error).message.slice(0, 150)}</p>
            )}

            <button
              onClick={handleCreateProposal}
              disabled={proposing || confirmingProposal || !address || !description || notDeployed}
              className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {proposing ? 'Confirm in wallet...' : confirmingProposal ? 'Creating Proposal...' : 'Create Proposal'}
            </button>

            {proposalSuccess && (
              <div className="p-4 bg-green-500/10 border border-green-500/20 rounded-lg">
                <p className="text-sm text-green-400">✓ Proposal created successfully!</p>
              </div>
            )}
          </div>
        )}

        {activeTab === 'ministries' && (
          <div className="space-y-4">
            {ministriesData.map((ministry, index) => (
              <div key={index} className="p-5 bg-white/5 hover:bg-white/10 border border-white/10 rounded-lg transition-all">
                <div className="flex items-center justify-between mb-3">
                  <div>
                    <h4 className="text-lg font-bold text-white mb-1">{ministry.name} Ministry</h4>
                    <p className="text-xs text-gray-500">
                      {(allMinistries as unknown[])?.length ? 'On-chain' : 'Demo data'}
                    </p>
                  </div>
                  <div className="text-right">
                    <p className="text-2xl font-bold text-primary-400">{ministry.weight}%</p>
                    <p className="text-xs text-gray-400">Voting weight</p>
                  </div>
                </div>
                <div className="flex items-center gap-6 text-sm">
                  <div>
                    <span className="text-gray-400">Proposals Voted: </span>
                    <span className="text-white font-semibold">{ministry.proposalsVoted}</span>
                  </div>
                  <div>
                    <span className="text-gray-400">Status: </span>
                    <span className="text-green-400 font-semibold">Active</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
