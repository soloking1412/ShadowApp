'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Badge } from '@/components/ui/badge';
import {
  useBlacklistAddressCount,
  useBlacklistCompanyCount,
  useBlacklistCountryCount,
  useAddToBlacklist,
} from '@/hooks/contracts/useOGRBlacklist';
import { CONTRACTS } from '@/lib/contracts';

// Entity types matching the OGRBlacklist contract enum
const ENTITY_TYPES = { company: 0, country: 1, organization: 2 } as const;

interface BlacklistEntry {
  id: string;
  name: string;
  type: 'country' | 'company' | 'organization';
  reason: string;
  addedBy: string;
  dateAdded: number;
  status: 'blacklisted' | 'under_appeal' | 'review_pending';
  appealDetails?: string;
  votes: { maintain: number; remove: number };
}

export default function BlacklistRegistry() {
  const { address } = useAccount();

  // Live contract reads
  const { data: addressCount } = useBlacklistAddressCount();
  const { data: companyCount } = useBlacklistCompanyCount();
  const { data: countryCount } = useBlacklistCountryCount();
  const { addToBlacklist, isPending, isConfirming, isSuccess, error } = useAddToBlacklist();

  const notDeployed = !CONTRACTS.OGRBlacklist;

  // Local session entries (added during this session)
  const [entries, setEntries] = useState<BlacklistEntry[]>([]);

  const [newEntry, setNewEntry] = useState({
    name: '',
    type: 'company' as 'company' | 'country' | 'organization',
    reason: '',
  });

  const [appealForm, setAppealForm] = useState({ entryId: '', details: '' });
  const [filter, setFilter] = useState<string>('all');

  const handleSubmit = () => {
    if (!newEntry.name || !newEntry.reason) return;

    // Call contract
    addToBlacklist(ENTITY_TYPES[newEntry.type], newEntry.name, newEntry.reason);

    // Add to local session state optimistically
    setEntries([
      {
        id: Date.now().toString(),
        name: newEntry.name,
        type: newEntry.type,
        reason: newEntry.reason,
        addedBy: address ? `${address.slice(0, 6)}…${address.slice(-4)}` : 'Community Member',
        dateAdded: Date.now(),
        status: 'review_pending',
        votes: { maintain: 0, remove: 0 },
      },
      ...entries,
    ]);
    setNewEntry({ name: '', type: 'company', reason: '' });
  };

  const handleAppeal = (entryId: string) => {
    setEntries(entries.map((e) =>
      e.id === entryId ? { ...e, status: 'under_appeal' as const, appealDetails: appealForm.details } : e,
    ));
    setAppealForm({ entryId: '', details: '' });
  };

  const handleVote = (entryId: string, voteType: 'maintain' | 'remove') => {
    setEntries(entries.map((e) =>
      e.id === entryId ? { ...e, votes: { ...e.votes, [voteType]: e.votes[voteType] + 1 } } : e,
    ));
  };

  const getTypeColor = (type: string) => {
    const colors = { country: 'bg-red-500', company: 'bg-orange-500', organization: 'bg-yellow-500' };
    return colors[type as keyof typeof colors] ?? 'bg-gray-500';
  };

  const getStatusColor = (status: string) => {
    const colors = {
      blacklisted: 'bg-red-100 text-red-800',
      under_appeal: 'bg-yellow-100 text-yellow-800',
      review_pending: 'bg-blue-100 text-blue-800',
    };
    return colors[status as keyof typeof colors] ?? '';
  };

  const filteredEntries = filter === 'all' ? entries : entries.filter((e) => e.type === filter);

  return (
    <div className="space-y-6">
      <div className="text-center mb-8">
        <h1 className="text-4xl font-bold mb-2">OZF Blacklist Registry</h1>
        <p className="text-lg text-purple-600 font-semibold mb-2">OZHUMANILL ZAYED FEDERATION</p>
        <p className="text-muted-foreground">Countries, companies, and organizations under review or sanctions</p>
      </div>

      {notDeployed && (
        <div className="p-4 bg-yellow-500/10 border border-yellow-500/30 rounded-lg text-yellow-400 text-sm">
          OGRBlacklist contract not deployed. Deploy via docker compose to enable live contract calls.
        </div>
      )}

      {/* Live On-Chain Stats */}
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: 'Blacklisted Addresses', value: addressCount !== undefined ? String(addressCount) : '—', color: 'text-red-400' },
          { label: 'Blacklisted Companies', value: companyCount !== undefined ? String(companyCount) : '—', color: 'text-orange-400' },
          { label: 'Blacklisted Countries', value: countryCount !== undefined ? String(countryCount) : '—', color: 'text-yellow-400' },
        ].map(({ label, value, color }) => (
          <div key={label} className="glass rounded-lg p-4 text-center">
            <p className={`text-2xl font-bold ${color}`}>{value}</p>
            <p className="text-xs text-gray-400 mt-1">{label}</p>
            <p className="text-xs text-gray-600">On-chain</p>
          </div>
        ))}
      </div>

      {/* Filter Tabs */}
      <div className="flex gap-2 border-b border-white/10">
        {['all', 'country', 'company', 'organization'].map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-4 py-2 text-sm capitalize ${filter === f ? 'border-b-2 border-primary font-medium text-white' : 'text-gray-400'}`}
          >
            {f === 'all' ? `All (${entries.length})` : `${f.charAt(0).toUpperCase() + f.slice(1)}s (${entries.filter((e) => e.type === f).length})`}
          </button>
        ))}
      </div>

      {/* Submit New Entry */}
      <Card>
        <CardHeader>
          <CardTitle>Submit Blacklist Nomination</CardTitle>
          <CardDescription>Nominate an entity for on-chain syndicate review (requires community approval)</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <label className="text-sm font-medium">Entity Name</label>
            <Input
              placeholder="Name of country, company, or organization"
              value={newEntry.name}
              onChange={(e) => setNewEntry({ ...newEntry, name: e.target.value })}
            />
          </div>
          <div>
            <label className="text-sm font-medium">Type</label>
            <select
              className="w-full p-2 border border-white/10 rounded bg-white/5 text-white"
              value={newEntry.type}
              onChange={(e) => setNewEntry({ ...newEntry, type: e.target.value as typeof newEntry.type })}
            >
              <option value="company">Company</option>
              <option value="country">Country</option>
              <option value="organization">Organization</option>
            </select>
          </div>
          <div>
            <label className="text-sm font-medium">Reason for Blacklisting</label>
            <Textarea
              placeholder="Detailed explanation with evidence and justification"
              rows={4}
              value={newEntry.reason}
              onChange={(e) => setNewEntry({ ...newEntry, reason: e.target.value })}
            />
          </div>

          {error && <p className="text-red-400 text-sm">{(error as Error).message.slice(0, 150)}</p>}
          {isSuccess && <p className="text-green-400 text-sm">✓ Nomination submitted on-chain!</p>}

          <Button
            onClick={handleSubmit}
            className="w-full"
            disabled={!newEntry.name || !newEntry.reason || isPending || isConfirming || notDeployed || !address}
          >
            {isPending ? 'Confirm in wallet…' : isConfirming ? 'Submitting on-chain…' : 'Submit for Review'}
          </Button>
          {!address && <p className="text-xs text-gray-500 text-center">Connect wallet to submit nominations</p>}
        </CardContent>
      </Card>

      {/* Registry Entries (session-local) */}
      <div className="space-y-4">
        <h2 className="text-2xl font-bold">
          Session Entries
          <span className="text-sm text-gray-400 font-normal ml-3">(entries submitted this session)</span>
        </h2>
        {filteredEntries.length === 0 ? (
          <div className="glass rounded-xl p-8 text-center text-gray-400">
            <p className="text-4xl mb-2">📋</p>
            <p className="font-medium">No nominations this session</p>
            <p className="text-sm mt-1">Submit a blacklist nomination above to see it here</p>
          </div>
        ) : (
          filteredEntries.map((entry) => (
            <Card key={entry.id}>
              <CardHeader>
                <div className="flex items-start justify-between">
                  <div className="space-y-2">
                    <CardTitle className="flex items-center gap-2">
                      {entry.name}
                      <Badge className={getTypeColor(entry.type)}>{entry.type}</Badge>
                    </CardTitle>
                    <Badge className={getStatusColor(entry.status)}>{entry.status.replace(/_/g, ' ')}</Badge>
                  </div>
                  <div className="text-right">
                    <div className="text-sm font-medium">Community Vote</div>
                    <div className="text-xs text-muted-foreground">
                      Maintain: {entry.votes.maintain} | Remove: {entry.votes.remove}
                    </div>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                <div>
                  <h3 className="font-semibold text-sm mb-1">Reason:</h3>
                  <p className="text-sm text-muted-foreground">{entry.reason}</p>
                </div>
                {entry.appealDetails && (
                  <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-3">
                    <h3 className="font-semibold text-sm mb-1">Appeal Details:</h3>
                    <p className="text-sm text-muted-foreground">{entry.appealDetails}</p>
                  </div>
                )}
                <div className="flex items-center justify-between text-sm text-muted-foreground">
                  <div>Added by {entry.addedBy} · {new Date(entry.dateAdded).toLocaleDateString()}</div>
                  <div className="flex gap-2">
                    <Button size="sm" variant="outline" onClick={() => handleVote(entry.id, 'maintain')}>Vote to Maintain</Button>
                    <Button size="sm" variant="outline" onClick={() => handleVote(entry.id, 'remove')}>Vote to Remove</Button>
                  </div>
                </div>
                {entry.status === 'blacklisted' && !entry.appealDetails && (
                  <div className="border-t border-white/10 pt-4">
                    <h3 className="font-semibold text-sm mb-2">File an Appeal</h3>
                    <div className="flex gap-2">
                      <Textarea
                        placeholder="Enter appeal details and evidence for syndicate review..."
                        rows={2}
                        value={appealForm.entryId === entry.id ? appealForm.details : ''}
                        onChange={(e) => setAppealForm({ entryId: entry.id, details: e.target.value })}
                      />
                      <Button
                        onClick={() => handleAppeal(entry.id)}
                        disabled={appealForm.entryId !== entry.id || !appealForm.details}
                      >
                        Submit Appeal
                      </Button>
                    </div>
                  </div>
                )}
              </CardContent>
            </Card>
          ))
        )}
      </div>

      {/* Appeals Process Info */}
      <Card className="border-blue-500/30">
        <CardHeader>
          <CardTitle>Appeals Process</CardTitle>
          <CardDescription>How blacklisted entities can request review</CardDescription>
        </CardHeader>
        <CardContent>
          <ol className="list-decimal list-inside space-y-2 text-sm">
            <li>Entity submits formal appeal with evidence of compliance/reform</li>
            <li>Appeal is reviewed by the Syndicate Review Board</li>
            <li>Community members vote on whether to maintain or remove blacklist status</li>
            <li>Super-majority (66%) vote required to remove from blacklist</li>
            <li>Appeals can be re-submitted after 90 days if rejected</li>
          </ol>
          <div className="mt-4 p-3 bg-blue-500/10 border border-blue-500/20 rounded-lg text-sm">
            <strong>Note:</strong> The OZF (OZHUMANILL ZAYED FEDERATION) will not support blacklisted entities unless they successfully complete the appellate proceeding.
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
