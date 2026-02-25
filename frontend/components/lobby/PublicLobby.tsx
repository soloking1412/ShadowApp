"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { formatEther } from "viem";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import {
  useProposalCounter,
  useGetProposal,
  useCastDAOVote,
  usePropose,
  DAO_PROPOSAL_CATEGORIES,
  DAO_VOTE_SUPPORT,
} from "@/hooks/contracts/useSovereignInvestmentDAO";

// Category display mapping
const CATEGORY_LABELS: Record<number, string> = {
  0: 'Treasury', 1: 'Infrastructure', 2: 'Policy',
  3: 'Emergency', 4: 'Upgrade', 5: 'Parameter', 6: 'Ministry',
};
const CATEGORY_COLORS: Record<number, string> = {
  0: 'bg-yellow-500', 1: 'bg-blue-500', 2: 'bg-purple-500',
  3: 'bg-red-500',    4: 'bg-cyan-500', 5: 'bg-orange-500', 6: 'bg-green-500',
};

// Single proposal row — hooks must be called at top level, so we use a sub-component
function ProposalCard({ id }: { id: bigint }) {
  const { data } = useGetProposal(id);
  const { castDAOVote, isPending: voting } = useCastDAOVote();
  const { address } = useAccount();

  if (!data) return (
    <div className="bg-white/5 rounded-xl p-4 animate-pulse h-24" />
  );

  const p = data as {
    proposalId: bigint; category: number; proposer: `0x${string}`;
    description: string; forVotes: bigint; againstVotes: bigint;
    abstainVotes: bigint; executed: boolean; cancelled: boolean;
    startTime: bigint; endTime: bigint;
  };

  const total = Number(p.forVotes + p.againstVotes + p.abstainVotes);
  const forPct = total > 0 ? Math.round((Number(p.forVotes) / total) * 100) : 0;
  const isActive = !p.executed && !p.cancelled && BigInt(Math.floor(Date.now() / 1000)) <= p.endTime;
  const statusLabel = p.executed ? 'Executed' : p.cancelled ? 'Cancelled' : isActive ? 'Active' : 'Closed';
  const statusColor = p.executed ? 'bg-blue-100 text-blue-800' : p.cancelled ? 'bg-red-100 text-red-800'
    : isActive ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600';

  return (
    <Card>
      <CardHeader>
        <div className="flex items-start justify-between gap-4">
          <div className="space-y-2 flex-1 min-w-0">
            <CardTitle className="text-base line-clamp-2">{p.description || `Proposal #${p.proposalId.toString()}`}</CardTitle>
            <div className="flex gap-2 flex-wrap">
              <Badge className={CATEGORY_COLORS[p.category] ?? 'bg-gray-500'}>
                {CATEGORY_LABELS[p.category] ?? 'Unknown'}
              </Badge>
              <Badge className={statusColor}>{statusLabel}</Badge>
            </div>
          </div>
          <div className="text-right shrink-0">
            <div className="text-lg font-bold text-green-400">{Number(p.forVotes).toLocaleString()}</div>
            <div className="text-xs text-gray-400">for votes</div>
          </div>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        {/* Vote bar */}
        <div>
          <div className="flex justify-between text-xs text-gray-400 mb-1">
            <span>For: {forPct}%</span>
            <span>Against: {total > 0 ? Math.round((Number(p.againstVotes) / total) * 100) : 0}%</span>
          </div>
          <div className="h-2 rounded bg-white/10 overflow-hidden">
            <div className="h-full bg-green-500 transition-all" style={{ width: `${forPct}%` }} />
          </div>
        </div>
        <div className="flex items-center justify-between">
          <div className="text-xs text-muted-foreground truncate">
            By {p.proposer.slice(0, 6)}…{p.proposer.slice(-4)}
          </div>
          {address && isActive && (
            <div className="flex gap-2">
              <Button size="sm" className="h-7 text-xs bg-green-600 hover:bg-green-700"
                disabled={voting}
                onClick={() => castDAOVote(p.proposalId, DAO_VOTE_SUPPORT.For)}>
                {voting ? '…' : 'For'}
              </Button>
              <Button size="sm" className="h-7 text-xs bg-red-600 hover:bg-red-700"
                disabled={voting}
                onClick={() => castDAOVote(p.proposalId, DAO_VOTE_SUPPORT.Against)}>
                {voting ? '…' : 'Against'}
              </Button>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}

export default function PublicLobby() {
  const { address } = useAccount();
  const { data: proposalCountRaw } = useProposalCounter();
  const { propose, isPending: proposing, isSuccess: proposeDone } = usePropose();

  const proposalCount = typeof proposalCountRaw === 'bigint' ? Number(proposalCountRaw) : 0;
  const proposalIds = Array.from({ length: proposalCount }, (_, i) => BigInt(i + 1));

  const [newTitle, setNewTitle] = useState('');
  const [newDesc, setNewDesc] = useState('');
  const [category, setCategory] = useState(0);

  const handleSubmit = () => {
    if (!newTitle.trim() || !newDesc.trim()) return;
    const description = `${newTitle.trim()}\n\n${newDesc.trim()}`;
    propose([], [], [], description, category);
    setNewTitle('');
    setNewDesc('');
  };

  return (
    <div className="space-y-6">
      <div className="text-center mb-8">
        <h1 className="text-4xl font-bold mb-2">Public Lobby</h1>
        <p className="text-muted-foreground">
          Propose financial changes and investments · {proposalCount} on-chain proposals
        </p>
      </div>

      {/* Submit New Proposal */}
      <Card>
        <CardHeader>
          <CardTitle>Submit New Proposal</CardTitle>
          <CardDescription>
            {address ? 'Share your ideas for economic reforms — submitted to SovereignInvestmentDAO' : 'Connect wallet to submit proposals'}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <label className="text-sm font-medium">Title</label>
            <Input placeholder="Brief title for your proposal" value={newTitle}
              onChange={e => setNewTitle(e.target.value)} />
          </div>
          <div>
            <label className="text-sm font-medium">Description</label>
            <Textarea placeholder="Detailed description and expected impact" rows={4}
              value={newDesc} onChange={e => setNewDesc(e.target.value)} />
          </div>
          <div>
            <label className="text-sm font-medium">Category</label>
            <select className="w-full p-2 border rounded bg-background text-foreground"
              value={category} onChange={e => setCategory(Number(e.target.value))}>
              {Object.entries(DAO_PROPOSAL_CATEGORIES).map(([label, val]) => (
                <option key={val} value={val}>{label}</option>
              ))}
            </select>
          </div>
          <Button onClick={handleSubmit}
            disabled={!address || proposing || !newTitle.trim() || !newDesc.trim()}
            className="w-full">
            {proposing ? 'Submitting to chain…' : proposeDone ? '✓ Submitted' : 'Submit Proposal'}
          </Button>
          {!address && (
            <p className="text-xs text-center text-muted-foreground">Connect wallet to submit</p>
          )}
        </CardContent>
      </Card>

      {/* On-chain Proposals */}
      <div className="space-y-4">
        <h2 className="text-2xl font-bold">On-Chain Proposals ({proposalCount})</h2>
        {proposalCount === 0 ? (
          <div className="text-center py-12 bg-white/5 rounded-xl">
            <p className="text-4xl mb-3">🏛</p>
            <p className="text-gray-400">No proposals yet — be the first to submit one.</p>
          </div>
        ) : (
          <div className="space-y-4">
            {proposalIds.slice().reverse().map(id => (
              <ProposalCard key={id.toString()} id={id} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
