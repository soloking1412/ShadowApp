'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS, PROPOSAL_CATEGORIES, MINISTRY_TYPES } from '@/lib/contracts';
import { parseEther } from 'viem';

export default function GovernanceDashboard() {
  const { address } = useAccount();
  const [activeTab, setActiveTab] = useState<'proposals' | 'create' | 'ministries'>('proposals');

  const [category, setCategory] = useState(0);
  const [budgetImpact, setBudgetImpact] = useState('');
  const [description, setDescription] = useState('');
  const [proposalId, setProposalId] = useState('');
  const [voteSupport, setVoteSupport] = useState<0 | 1 | 2>(1);

  const { writeContract, data: hash } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const handleCreateProposal = async () => {
    if (!description || !budgetImpact) return;

    try {
      writeContract({
        address: CONTRACTS.SovereignInvestmentDAO,
        abi: DAO_ABI,
        functionName: 'propose',
        args: [
          category,
          parseEther(budgetImpact),
          ('0x' + '0'.repeat(64)) as `0x${string}`,
          description,
        ],
      });
    } catch (error) {
      console.error('Error creating proposal:', error);
    }
  };

  const handleVote = async () => {
    if (!proposalId) return;

    try {
      writeContract({
        address: CONTRACTS.SovereignInvestmentDAO,
        abi: DAO_ABI,
        functionName: 'castVote',
        args: [BigInt(proposalId), voteSupport],
      });
    } catch (error) {
      console.error('Error voting:', error);
    }
  };

  const handleMinistryVote = async (propId: string, support: boolean) => {
    try {
      writeContract({
        address: CONTRACTS.SovereignInvestmentDAO,
        abi: DAO_ABI,
        functionName: 'castMinistryVote',
        args: [BigInt(propId), support],
      });
    } catch (error) {
      console.error('Error casting ministry vote:', error);
    }
  };

  const mockProposals = [
    {
      id: '1',
      category: 'Infrastructure',
      proposer: '0x' + '1'.repeat(40),
      description: 'Allocate $50B for high-speed rail network expansion across 15 countries',
      budgetImpact: '$50,000,000,000',
      forVotes: '487',
      againstVotes: '123',
      abstainVotes: '45',
      endTime: new Date(Date.now() + 172800000).toLocaleDateString(),
      state: 'Active',
      ministryApprovals: '68%',
      requiresMinistryApproval: true,
    },
    {
      id: '2',
      category: 'Treasury',
      proposer: '0x' + '2'.repeat(40),
      description: 'Increase reserve ratio for OICD from 20% to 25% to strengthen stability',
      budgetImpact: '$0',
      forVotes: '892',
      againstVotes: '234',
      abstainVotes: '78',
      endTime: new Date(Date.now() + 86400000).toLocaleDateString(),
      state: 'Active',
      ministryApprovals: '82%',
      requiresMinistryApproval: true,
    },
    {
      id: '3',
      category: 'Policy',
      proposer: '0x' + '3'.repeat(40),
      description: 'Implement new KYC requirements for dark pool traders exceeding $10M volume',
      budgetImpact: '$2,500,000',
      forVotes: '1245',
      againstVotes: '89',
      abstainVotes: '34',
      endTime: new Date(Date.now() + 259200000).toLocaleDateString(),
      state: 'Active',
      ministryApprovals: 'N/A',
      requiresMinistryApproval: false,
    },
  ];

  const mockMinistries = [
    { name: 'Treasury', type: MINISTRY_TYPES.Treasury, address: '0x' + 'A'.repeat(40), weight: 20, proposalsVoted: 48 },
    { name: 'Finance', type: MINISTRY_TYPES.Finance, address: '0x' + 'B'.repeat(40), weight: 18, proposalsVoted: 52 },
    { name: 'Infrastructure', type: MINISTRY_TYPES.Infrastructure, address: '0x' + 'C'.repeat(40), weight: 15, proposalsVoted: 44 },
    { name: 'Trade', type: MINISTRY_TYPES.Trade, address: '0x' + 'D'.repeat(40), weight: 13, proposalsVoted: 39 },
    { name: 'Defense', type: MINISTRY_TYPES.Defense, address: '0x' + 'E'.repeat(40), weight: 12, proposalsVoted: 28 },
    { name: 'Energy', type: MINISTRY_TYPES.Energy, address: '0x' + 'F'.repeat(40), weight: 12, proposalsVoted: 35 },
    { name: 'Technology', type: MINISTRY_TYPES.Technology, address: '0x' + '1'.repeat(41), weight: 10, proposalsVoted: 41 },
  ];

  return (
    <div className="space-y-6">
      <div className="glass rounded-xl p-6">
        <h2 className="text-2xl font-bold text-white mb-2">Sovereign Investment DAO</h2>
        <p className="text-gray-400 mb-6">Decentralized governance with ministry voting system</p>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="p-4 bg-gradient-to-br from-blue-500/20 to-blue-600/20 border border-blue-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Total Proposals</p>
            <p className="text-3xl font-bold text-white">487</p>
            <p className="text-xs text-blue-400 mt-1">All time</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-green-500/20 to-green-600/20 border border-green-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Active Proposals</p>
            <p className="text-3xl font-bold text-white">12</p>
            <p className="text-xs text-green-400 mt-1">Voting now</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-purple-500/20 to-purple-600/20 border border-purple-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Ministries</p>
            <p className="text-3xl font-bold text-white">7</p>
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
                activeTab === tab
                  ? 'bg-primary-500 text-white'
                  : 'bg-white/5 text-gray-400 hover:bg-white/10'
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
                      <span className="px-3 py-1 bg-blue-500/20 text-blue-400 text-xs font-semibold rounded">
                        {proposal.category}
                      </span>
                      <span className="px-3 py-1 bg-green-500/20 text-green-400 text-xs font-semibold rounded">
                        {proposal.state}
                      </span>
                      {proposal.requiresMinistryApproval && (
                        <span className="px-3 py-1 bg-purple-500/20 text-purple-400 text-xs font-semibold rounded">
                          Ministry Vote
                        </span>
                      )}
                    </div>
                    <h4 className="text-lg font-bold text-white mb-2">Proposal #{proposal.id}</h4>
                    <p className="text-sm text-gray-300 mb-3">{proposal.description}</p>
                    <div className="flex items-center gap-4 text-xs text-gray-400">
                      <span>Budget Impact: <span className="text-amber-400 font-semibold">{proposal.budgetImpact}</span></span>
                      <span>Ends: <span className="text-white">{proposal.endTime}</span></span>
                      {proposal.requiresMinistryApproval && (
                        <span>Ministry Approval: <span className="text-purple-400 font-semibold">{proposal.ministryApprovals}</span></span>
                      )}
                    </div>
                  </div>
                </div>

                <div className="space-y-2 mb-4">
                  <div className="flex items-center gap-2">
                    <div className="flex-1 bg-white/10 rounded-full h-2 overflow-hidden">
                      <div className="h-full bg-green-500" style={{ width: '78%' }} />
                    </div>
                    <span className="text-xs text-green-400 font-semibold w-16 text-right">{proposal.forVotes} For</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="flex-1 bg-white/10 rounded-full h-2 overflow-hidden">
                      <div className="h-full bg-red-500" style={{ width: '20%' }} />
                    </div>
                    <span className="text-xs text-red-400 font-semibold w-16 text-right">{proposal.againstVotes} Against</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="flex-1 bg-white/10 rounded-full h-2 overflow-hidden">
                      <div className="h-full bg-gray-500" style={{ width: '7%' }} />
                    </div>
                    <span className="text-xs text-gray-400 font-semibold w-16 text-right">{proposal.abstainVotes} Abstain</span>
                  </div>
                </div>

                <div className="flex gap-2">
                  <button
                    onClick={() => {
                      setProposalId(proposal.id);
                      setVoteSupport(1);
                      handleVote();
                    }}
                    className="flex-1 py-2 bg-green-500/20 hover:bg-green-500/30 text-green-400 font-semibold rounded-lg transition-all"
                  >
                    Vote For
                  </button>
                  <button
                    onClick={() => {
                      setProposalId(proposal.id);
                      setVoteSupport(0);
                      handleVote();
                    }}
                    className="flex-1 py-2 bg-red-500/20 hover:bg-red-500/30 text-red-400 font-semibold rounded-lg transition-all"
                  >
                    Vote Against
                  </button>
                  <button
                    onClick={() => {
                      setProposalId(proposal.id);
                      setVoteSupport(2);
                      handleVote();
                    }}
                    className="flex-1 py-2 bg-gray-500/20 hover:bg-gray-500/30 text-gray-400 font-semibold rounded-lg transition-all"
                  >
                    Abstain
                  </button>
                </div>

                {proposal.requiresMinistryApproval && address && (
                  <div className="mt-3 pt-3 border-t border-white/10 flex gap-2">
                    <button
                      onClick={() => handleMinistryVote(proposal.id, true)}
                      className="flex-1 py-2 bg-purple-500/20 hover:bg-purple-500/30 text-purple-400 font-semibold rounded-lg transition-all text-sm"
                    >
                      Ministry Approve
                    </button>
                    <button
                      onClick={() => handleMinistryVote(proposal.id, false)}
                      className="flex-1 py-2 bg-red-500/20 hover:bg-red-500/30 text-red-400 font-semibold rounded-lg transition-all text-sm"
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

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Budget Impact (ETH)</label>
              <input
                type="number"
                value={budgetImpact}
                onChange={(e) => setBudgetImpact(e.target.value)}
                placeholder="0.00"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
            </div>

            <div className="p-4 bg-blue-500/10 border border-blue-500/20 rounded-lg">
              <p className="text-sm font-medium text-white mb-2">Governance Requirements</p>
              <ul className="space-y-1 text-xs text-gray-400">
                <li>• Treasury, Infrastructure & Emergency proposals require ministry approval</li>
                <li>• Ministry quorum: 55% for standard, 60% for emergency</li>
                <li>• Voting period: Configurable (default 7 days)</li>
                <li>• Execution delay: Time-locked for security</li>
              </ul>
            </div>

            <button
              onClick={handleCreateProposal}
              disabled={isConfirming || !address}
              className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isConfirming ? 'Creating Proposal...' : 'Create Proposal'}
            </button>
          </div>
        )}

        {activeTab === 'ministries' && (
          <div className="space-y-4">
            {mockMinistries.map((ministry, index) => (
              <div key={index} className="p-5 bg-white/5 hover:bg-white/10 border border-white/10 rounded-lg transition-all">
                <div className="flex items-center justify-between mb-3">
                  <div>
                    <h4 className="text-lg font-bold text-white mb-1">{ministry.name} Ministry</h4>
                    <p className="text-xs text-gray-400 font-mono">{ministry.address}</p>
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

        {isSuccess && (
          <div className="mt-4 p-4 bg-green-500/10 border border-green-500/20 rounded-lg">
            <p className="text-sm text-green-400">Action completed successfully!</p>
          </div>
        )}
      </div>
    </div>
  );
}

const DAO_ABI = [
  {
    inputs: [
      { name: 'category', type: 'uint8' },
      { name: 'budgetImpact', type: 'uint256' },
      { name: 'documentHash', type: 'bytes32' },
      { name: 'description', type: 'string' },
    ],
    name: 'propose',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'proposalId', type: 'uint256' },
      { name: 'support', type: 'uint8' },
    ],
    name: 'castVote',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'proposalId', type: 'uint256' },
      { name: 'support', type: 'bool' },
    ],
    name: 'castMinistryVote',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const;
