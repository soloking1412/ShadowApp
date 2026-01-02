'use client';

import { useState, useEffect, useRef } from 'react';
import { useAccount } from 'wagmi';
import { io, Socket } from 'socket.io-client';

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
  unread: number;
}

export default function ChatWindow() {
  const { address } = useAccount();
  const [socket, setSocket] = useState<Socket | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputMessage, setInputMessage] = useState('');
  const [selectedChannel, setSelectedChannel] = useState<string>('general');
  const [isConnected, setIsConnected] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const channels: Channel[] = [
    { id: 'general', name: 'General', description: 'General discussion', memberCount: 487, unread: 0 },
    { id: 'trading', name: 'Trading', description: 'Trading strategies and signals', memberCount: 342, unread: 3 },
    { id: 'governance', name: 'Governance', description: 'DAO proposals and voting', memberCount: 156, unread: 0 },
    { id: 'bonds', name: 'Bonds', description: '2DI Bonds and infrastructure', memberCount: 89, unread: 1 },
    { id: 'forex', name: 'Forex', description: 'Currency reserves and forex', memberCount: 234, unread: 0 },
    { id: 'announcements', name: 'Announcements', description: 'Official announcements', memberCount: 892, unread: 2 },
  ];

  useEffect(() => {
    const socketUrl = process.env.NEXT_PUBLIC_CHAT_SERVER_URL || 'http://localhost:3001';
    const newSocket = io(socketUrl, {
      transports: ['websocket'],
      reconnection: true,
    });

    newSocket.on('connect', () => {
      setIsConnected(true);
      if (address) {
        newSocket.emit('join', { address, channel: selectedChannel });
      }
    });

    newSocket.on('disconnect', () => {
      setIsConnected(false);
    });

    newSocket.on('message', (message: Message) => {
      setMessages((prev) => [...prev, message]);
    });

    newSocket.on('history', (history: Message[]) => {
      setMessages(history);
    });

    setSocket(newSocket);

    return () => {
      newSocket.close();
    };
  }, []);

  useEffect(() => {
    if (socket && address) {
      socket.emit('join', { address, channel: selectedChannel });
      socket.emit('getHistory', { channel: selectedChannel });
    }
  }, [selectedChannel, socket, address]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleSendMessage = () => {
    if (!inputMessage.trim() || !socket || !address) return;

    const message: Message = {
      id: Date.now().toString(),
      sender: address,
      senderName: address.slice(0, 6) + '...' + address.slice(-4),
      content: inputMessage,
      timestamp: Date.now(),
      type: 'text',
    };

    socket.emit('message', { channel: selectedChannel, message });
    setInputMessage('');
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  return (
    <div className="glass rounded-xl overflow-hidden h-[600px] flex">
      <div className="w-64 bg-white/5 border-r border-white/10 flex flex-col">
        <div className="p-4 border-b border-white/10">
          <h3 className="text-lg font-bold text-white mb-1">Channels</h3>
          <div className="flex items-center gap-2">
            <div className={`w-2 h-2 rounded-full ${isConnected ? 'bg-green-400' : 'bg-red-400'} animate-pulse`} />
            <span className="text-xs text-gray-400">{isConnected ? 'Connected' : 'Disconnected'}</span>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-2 space-y-1">
          {channels.map((channel) => (
            <button
              key={channel.id}
              onClick={() => setSelectedChannel(channel.id)}
              className={`w-full text-left p-3 rounded-lg transition-all ${
                selectedChannel === channel.id
                  ? 'bg-primary-500 text-white'
                  : 'bg-white/5 text-gray-300 hover:bg-white/10'
              }`}
            >
              <div className="flex items-center justify-between mb-1">
                <span className="font-semibold text-sm"># {channel.name}</span>
                {channel.unread > 0 && (
                  <span className="px-2 py-0.5 bg-red-500 text-white text-xs font-bold rounded-full">
                    {channel.unread}
                  </span>
                )}
              </div>
              <p className="text-xs opacity-75 truncate">{channel.description}</p>
              <p className="text-xs opacity-60 mt-1">{channel.memberCount} members</p>
            </button>
          ))}
        </div>
      </div>

      <div className="flex-1 flex flex-col">
        <div className="p-4 border-b border-white/10 bg-white/5">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-lg font-bold text-white">
                # {channels.find((c) => c.id === selectedChannel)?.name}
              </h3>
              <p className="text-xs text-gray-400">
                {channels.find((c) => c.id === selectedChannel)?.description}
              </p>
            </div>
            <div className="text-right text-xs text-gray-400">
              {channels.find((c) => c.id === selectedChannel)?.memberCount} members online
            </div>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {messages.length === 0 ? (
            <div className="flex items-center justify-center h-full">
              <div className="text-center">
                <svg className="w-16 h-16 text-gray-600 mx-auto mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                </svg>
                <p className="text-gray-400 text-sm">No messages yet. Start the conversation!</p>
              </div>
            </div>
          ) : (
            <>
              {messages.map((message) =>
                message.type === 'system' ? (
                  <div key={message.id} className="text-center">
                    <p className="text-xs text-gray-500 italic">{message.content}</p>
                  </div>
                ) : (
                  <div key={message.id} className="flex gap-3">
                    <div className="w-10 h-10 rounded-full bg-gradient-to-br from-blue-500 to-purple-500 flex items-center justify-center font-bold text-white text-sm flex-shrink-0">
                      {message.senderName.slice(0, 2).toUpperCase()}
                    </div>
                    <div className="flex-1">
                      <div className="flex items-baseline gap-2 mb-1">
                        <span className="font-semibold text-white text-sm">{message.senderName}</span>
                        <span className="text-xs text-gray-500">
                          {new Date(message.timestamp).toLocaleTimeString()}
                        </span>
                      </div>
                      <p className="text-sm text-gray-300 break-words">{message.content}</p>
                    </div>
                  </div>
                )
              )}
              <div ref={messagesEndRef} />
            </>
          )}
        </div>

        <div className="p-4 border-t border-white/10 bg-white/5">
          {address ? (
            <div className="flex gap-2">
              <input
                type="text"
                value={inputMessage}
                onChange={(e) => setInputMessage(e.target.value)}
                onKeyPress={handleKeyPress}
                placeholder={`Message #${channels.find((c) => c.id === selectedChannel)?.name}`}
                className="flex-1 bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
              <button
                onClick={handleSendMessage}
                disabled={!inputMessage.trim() || !isConnected}
                className="px-6 py-3 bg-primary-500 hover:bg-primary-600 text-white font-semibold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                </svg>
              </button>
            </div>
          ) : (
            <div className="text-center py-3">
              <p className="text-sm text-gray-400">Connect your wallet to join the conversation</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
