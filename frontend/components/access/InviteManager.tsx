'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { useIsWhitelisted, useAcceptInvite, useIssueInvite } from '@/hooks/contracts/useInviteManager';
import { CONTRACTS } from '@/lib/contracts';

export default function InviteManagerDashboard() {
  const { address } = useAccount();
  const [inviteCode, setInviteCode] = useState('');
  const [inviteeAddress, setInviteeAddress] = useState('');
  const [newTier, setNewTier] = useState(0);
  const [tab, setTab] = useState<'accept' | 'issue'>('accept');

  const { data: isWhitelisted } = useIsWhitelisted(address);
  const { acceptInvite, isPending: accepting, isSuccess: accepted, error: acceptError } = useAcceptInvite();
  const { issueInvite, isPending: issuing, isSuccess: issued, error: issueError } = useIssueInvite();

  const tiers = ['Basic', 'Institutional', 'Government', 'VIP'];

  const notDeployed = !CONTRACTS.InviteManager;

  return (
    <div className="space-y-6">
      <div className="glass rounded-xl p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="w-10 h-10 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-lg flex items-center justify-center text-xl">🔐</div>
          <div>
            <h2 className="text-2xl font-bold text-white">Invite Manager</h2>
            <p className="text-gray-400 text-sm">Gated access control via invite codes</p>
          </div>
        </div>

        {notDeployed && (
          <div className="p-4 bg-yellow-500/10 border border-yellow-500/30 rounded-lg text-yellow-400 text-sm mb-4">
            Contract not deployed yet. Deploy with docker compose to enable this feature.
          </div>
        )}

        {address && (
          <div className="flex items-center gap-3 p-4 bg-white/5 rounded-lg mb-6">
            <div className={`w-3 h-3 rounded-full ${isWhitelisted ? 'bg-green-400' : 'bg-red-400'}`} />
            <div>
              <p className="text-white font-medium">Your Access Status</p>
              <p className="text-sm text-gray-400">
                {isWhitelisted ? '✓ Whitelisted — Full platform access granted' : '✗ Not whitelisted — Enter invite code to access'}
              </p>
            </div>
          </div>
        )}

        <div className="grid grid-cols-2 gap-4 mb-6">
          {tiers.map((tier, i) => (
            <div key={tier} className="p-4 bg-white/5 rounded-lg border border-white/10">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-lg">{['⭐', '🏢', '🏛️', '💎'][i]}</span>
                <span className="text-white font-medium">{tier}</span>
              </div>
              <p className="text-xs text-gray-400">Tier {i} access level</p>
            </div>
          ))}
        </div>

        <div className="flex gap-2 mb-6">
          {(['accept', 'issue'] as const).map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`px-4 py-2 rounded-lg font-medium capitalize transition-all ${tab === t ? 'bg-indigo-500 text-white' : 'bg-white/5 text-gray-300 hover:bg-white/10'}`}
            >
              {t === 'accept' ? 'Accept Invite' : 'Issue Invite (Admin)'}
            </button>
          ))}
        </div>

        {tab === 'accept' ? (
          <div className="space-y-4">
            <div>
              <label className="block text-sm text-gray-400 mb-2">Invite Code</label>
              <input
                value={inviteCode}
                onChange={(e) => setInviteCode(e.target.value)}
                placeholder="Enter your invite code..."
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-indigo-500"
              />
            </div>
            <button
              onClick={() => acceptInvite(inviteCode)}
              disabled={!inviteCode || accepting || notDeployed}
              className="px-6 py-3 bg-indigo-500 hover:bg-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-medium transition-all"
            >
              {accepting ? 'Submitting...' : accepted ? '✓ Accepted!' : 'Accept Invite'}
            </button>
            {acceptError && <p className="text-red-400 text-sm">{(acceptError as Error).message}</p>}
          </div>
        ) : (
          <div className="space-y-4">
            <div className="p-3 bg-blue-500/10 border border-blue-500/20 rounded-lg text-xs text-blue-300">
              <p className="font-semibold mb-1">How issueInvite works</p>
              <p>Enter the wallet address you want to whitelist. The contract generates an invite code for that address. Share the code with them — they enter it in the Accept Invite tab.</p>
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-2">Invitee Wallet Address</label>
              <input
                value={inviteeAddress}
                onChange={(e) => setInviteeAddress(e.target.value.trim())}
                placeholder="0x... wallet address to whitelist"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-indigo-500 font-mono text-sm"
              />
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-2">Access Tier</label>
              <select
                value={newTier}
                onChange={(e) => setNewTier(parseInt(e.target.value))}
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-indigo-500"
              >
                {tiers.map((t, i) => <option key={t} value={i} className="bg-gray-800">{t}</option>)}
              </select>
            </div>
            <button
              onClick={() => {
                if (/^0x[0-9a-fA-F]{40}$/.test(inviteeAddress))
                  issueInvite(inviteeAddress as `0x${string}`, newTier, []);
              }}
              disabled={!/^0x[0-9a-fA-F]{40}$/.test(inviteeAddress) || issuing || notDeployed}
              className="px-6 py-3 bg-purple-500 hover:bg-purple-600 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-medium transition-all"
            >
              {issuing ? 'Issuing...' : issued ? '✓ Invite Issued!' : 'Issue Invite (Owner Only)'}
            </button>
            {issueError && <p className="text-red-400 text-sm">{(issueError as Error).message}</p>}
          </div>
        )}
      </div>
    </div>
  );
}
