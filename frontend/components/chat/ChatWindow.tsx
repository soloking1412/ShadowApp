'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import { useAccount } from 'wagmi';

interface Message {
  id: string;
  sender: string;
  senderName: string;
  content: string;
  timestamp: number;
  type: 'text' | 'system';
}

interface Channel {
  id: string;
  name: string;
  description: string;
  memberCount: number;
}

const CHANNELS: Channel[] = [
  { id: 'general',       name: 'General',       description: 'General discussion',              memberCount: 487 },
  { id: 'trading',       name: 'Trading',        description: 'Trading strategies and signals',  memberCount: 342 },
  { id: 'governance',    name: 'Governance',     description: 'DAO proposals and voting',        memberCount: 156 },
  { id: 'bonds',         name: 'Bonds',          description: '2DI Bonds and infrastructure',    memberCount: 89  },
  { id: 'forex',         name: 'Forex',          description: 'Currency reserves and forex',     memberCount: 234 },
  { id: 'announcements', name: 'Announcements',  description: 'Official announcements',          memberCount: 892 },
];

const SEED_MESSAGES: Record<string, Omit<Message, 'id'>[]> = {
  general: [
    { sender: 'system', senderName: 'OZF System', content: 'Welcome to the OZF General channel. This is a decentralized community space.', timestamp: Date.now() - 3_600_000, type: 'system' },
    { sender: '0xSGM...HQ01', senderName: '0xSGM…HQ01', content: 'OICD liquidity pools are live on all 5 DTX centers. Alpha (Puerto Rico) has the highest volume today.', timestamp: Date.now() - 2_400_000, type: 'text' },
    { sender: '0xObs...1A2B', senderName: '0xObs…1A2B', content: 'Obsidian Capital AVS split confirmed: 60% to host country, 40% back to the fund. Multiplier locked at 2.5x this quarter.', timestamp: Date.now() - 1_200_000, type: 'text' },
  ],
  trading: [
    { sender: 'system', senderName: 'OZF System', content: 'Trading channel — discuss strategies, signals, and market analysis.', timestamp: Date.now() - 7_200_000, type: 'system' },
    { sender: '0xTrd...9F3E', senderName: '0xTrd…9F3E', content: 'HFT Engine GLTE formula running smooth on Sovereign DEX. 0.09% fee tier capturing solid arb.', timestamp: Date.now() - 900_000, type: 'text' },
  ],
  governance: [
    { sender: 'system', senderName: 'OZF System', content: 'Governance channel — OZF Parliament proposals, DAO voting, and policy discussions.', timestamp: Date.now() - 86_400_000, type: 'system' },
    { sender: '0xPar...7D2C', senderName: '0xPar…7D2C', content: 'New proposal: expand SEZ coverage to Delta (Sri Lanka) and Echo (Indonesia) corridors. Vote opens tomorrow.', timestamp: Date.now() - 3_600_000, type: 'text' },
  ],
  bonds: [
    { sender: 'system', senderName: 'OZF System', content: '2DI Bonds and infrastructure financing discussions.', timestamp: Date.now() - 172_800_000, type: 'system' },
    { sender: '0xBnd...4F1A', senderName: '0xBnd…4F1A', content: 'Bond auction for InfrastructureAssets tranche closed. 23 bids, final price 98.4 OICD per bond.', timestamp: Date.now() - 1_800_000, type: 'text' },
  ],
  forex: [
    { sender: 'system', senderName: 'OZF System', content: 'Forex reserves and currency corridor analysis.', timestamp: Date.now() - 259_200_000, type: 'system' },
    { sender: '0xFx0...C8B2', senderName: '0xFx0…C8B2', content: 'Orion Score updated: top corridors this week are USD/MXN, EUR/CHF, GBP/HKD. Macro score favoring Ireland, France.', timestamp: Date.now() - 600_000, type: 'text' },
  ],
  announcements: [
    { sender: 'system', senderName: 'OZF System', content: 'Official OZF announcements. Read-only for non-moderators.', timestamp: Date.now() - 604_800_000, type: 'system' },
    { sender: '0xOZF...0001', senderName: '0xOZF…0001', content: '📢 ShadowDapp v4.0 live — 33 contracts deployed across Version 1.0, 2.0, and Phase 2C/3/4. DTX Bourse and DCM Market Charter now active.', timestamp: Date.now() - 3_600_000, type: 'text' },
  ],
};

const STORAGE_KEY = 'shadowapp_chat_messages';

function loadMessages(channel: string): Message[] {
  try {
    const stored = localStorage.getItem(`${STORAGE_KEY}_${channel}`);
    if (stored) return JSON.parse(stored) as Message[];
  } catch { /* ignore */ }
  // Seed with default messages
  return (SEED_MESSAGES[channel] ?? []).map((m, i) => ({ ...m, id: `seed_${channel}_${i}` }));
}

function saveMessages(channel: string, messages: Message[]) {
  try {
    // Keep last 200 messages per channel
    localStorage.setItem(`${STORAGE_KEY}_${channel}`, JSON.stringify(messages.slice(-200)));
  } catch { /* ignore */ }
}

export default function ChatWindow() {
  const { address } = useAccount();
  const [messages, setMessages]         = useState<Message[]>([]);
  const [inputMessage, setInputMessage] = useState('');
  const [selectedChannel, setSelectedChannel] = useState('general');
  const [unreadCounts, setUnreadCounts] = useState<Record<string, number>>({});
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const prevChannel    = useRef(selectedChannel);

  // Load messages when channel changes
  useEffect(() => {
    const msgs = loadMessages(selectedChannel);
    setMessages(msgs);
    // Clear unread for this channel
    setUnreadCounts(prev => ({ ...prev, [selectedChannel]: 0 }));
  }, [selectedChannel]);

  // Scroll to bottom on new messages
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleSendMessage = useCallback(() => {
    if (!inputMessage.trim() || !address) return;

    const newMsg: Message = {
      id: `${Date.now()}_${Math.random().toString(36).slice(2)}`,
      sender: address,
      senderName: `${address.slice(0, 6)}…${address.slice(-4)}`,
      content: inputMessage.trim(),
      timestamp: Date.now(),
      type: 'text',
    };

    setMessages(prev => {
      const updated = [...prev, newMsg];
      saveMessages(selectedChannel, updated);
      return updated;
    });
    setInputMessage('');
  }, [inputMessage, address, selectedChannel]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  return (
    <div className="glass rounded-xl overflow-hidden h-[620px] flex">
      {/* Sidebar */}
      <div className="w-60 bg-white/5 border-r border-white/10 flex flex-col shrink-0">
        <div className="p-4 border-b border-white/10">
          <h3 className="text-base font-bold text-white">Channels</h3>
          <div className="flex items-center gap-2 mt-1">
            <span className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
            <span className="text-xs text-gray-400">OZF Community</span>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-2 space-y-0.5">
          {CHANNELS.map((ch) => (
            <button
              key={ch.id}
              onClick={() => setSelectedChannel(ch.id)}
              className={`w-full text-left px-3 py-2.5 rounded-lg transition-all ${
                selectedChannel === ch.id
                  ? 'bg-primary-500 text-white'
                  : 'text-gray-300 hover:bg-white/10'
              }`}
            >
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium"># {ch.name}</span>
                {(unreadCounts[ch.id] ?? 0) > 0 && (
                  <span className="px-1.5 py-0.5 bg-red-500 text-white text-xs font-bold rounded-full">
                    {unreadCounts[ch.id]}
                  </span>
                )}
              </div>
              <p className="text-xs opacity-60 truncate mt-0.5">{ch.memberCount} members</p>
            </button>
          ))}
        </div>
      </div>

      {/* Main chat area */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Header */}
        <div className="p-4 border-b border-white/10 bg-white/5 shrink-0">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-base font-bold text-white">
                # {CHANNELS.find((c) => c.id === selectedChannel)?.name}
              </h3>
              <p className="text-xs text-gray-400">
                {CHANNELS.find((c) => c.id === selectedChannel)?.description}
              </p>
            </div>
            <span className="text-xs text-gray-500">
              {CHANNELS.find((c) => c.id === selectedChannel)?.memberCount} members
            </span>
          </div>
        </div>

        {/* Messages */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4 min-h-0">
          {messages.length === 0 ? (
            <div className="flex items-center justify-center h-full">
              <div className="text-center">
                <div className="text-4xl mb-3">💬</div>
                <p className="text-gray-400 text-sm">No messages yet. Start the conversation!</p>
              </div>
            </div>
          ) : (
            <>
              {messages.map((msg) =>
                msg.type === 'system' ? (
                  <div key={msg.id} className="text-center">
                    <p className="text-xs text-gray-500 italic">{msg.content}</p>
                  </div>
                ) : (
                  <div key={msg.id} className="flex gap-3">
                    <div className="w-9 h-9 rounded-full bg-gradient-to-br from-blue-500 to-purple-500 flex items-center justify-center font-bold text-white text-xs shrink-0">
                      {msg.senderName.slice(0, 2).toUpperCase()}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-baseline gap-2 mb-0.5">
                        <span className={`font-semibold text-sm ${msg.sender === address ? 'text-primary-400' : 'text-white'}`}>
                          {msg.sender === address ? 'You' : msg.senderName}
                        </span>
                        <span className="text-xs text-gray-500">
                          {new Date(msg.timestamp).toLocaleTimeString()}
                        </span>
                      </div>
                      <p className="text-sm text-gray-300 break-words">{msg.content}</p>
                    </div>
                  </div>
                )
              )}
              <div ref={messagesEndRef} />
            </>
          )}
        </div>

        {/* Input */}
        <div className="p-4 border-t border-white/10 bg-white/5 shrink-0">
          {address ? (
            <div className="flex gap-2">
              <input
                type="text"
                value={inputMessage}
                onChange={(e) => setInputMessage(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder={`Message #${CHANNELS.find((c) => c.id === selectedChannel)?.name}…`}
                className="flex-1 bg-white/5 border border-white/10 rounded-lg px-4 py-2.5 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 text-sm"
              />
              <button
                onClick={handleSendMessage}
                disabled={!inputMessage.trim()}
                className="px-4 py-2.5 bg-primary-500 hover:bg-primary-600 disabled:opacity-40 text-white rounded-lg transition-all"
              >
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                </svg>
              </button>
            </div>
          ) : (
            <p className="text-center text-sm text-gray-400 py-2">
              Connect your wallet to join the conversation
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
