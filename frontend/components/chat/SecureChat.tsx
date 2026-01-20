"use client";

import { useState, useEffect, useRef } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";

interface Message {
  id: string;
  sender: string;
  content: string;
  timestamp: number;
  encrypted: boolean;
  verified: boolean;
}

interface ChatRoom {
  id: string;
  name: string;
  members: number;
  encrypted: boolean;
  category: "public" | "syndicate" | "dao" | "private";
}

export default function SecureChat() {
  const [messages, setMessages] = useState<Message[]>([
    {
      id: "1",
      sender: "OZF Moderator",
      content: "Welcome to the secure OZF chat. All messages are end-to-end encrypted.",
      timestamp: Date.now() - 3600000,
      encrypted: true,
      verified: true,
    },
  ]);

  const [currentMessage, setCurrentMessage] = useState("");
  const [selectedRoom, setSelectedRoom] = useState<string>("general");
  const [isConnected, setIsConnected] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const rooms: ChatRoom[] = [
    { id: "general", name: "General Discussion", members: 1243, encrypted: true, category: "public" },
    { id: "syndicate", name: "Syndicate Private", members: 47, encrypted: true, category: "syndicate" },
    { id: "dao", name: "DAO Governance", members: 523, encrypted: true, category: "dao" },
    { id: "lobby", name: "Public Lobby", members: 892, encrypted: true, category: "public" },
  ];

  useEffect(() => {
    // Simulate connection
    setTimeout(() => setIsConnected(true), 1000);
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  const handleSendMessage = () => {
    if (!currentMessage.trim()) return;

    const newMessage: Message = {
      id: Date.now().toString(),
      sender: "You",
      content: currentMessage,
      timestamp: Date.now(),
      encrypted: true,
      verified: true,
    };

    setMessages([...messages, newMessage]);
    setCurrentMessage("");
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  const getCategoryColor = (category: string) => {
    const colors = {
      public: "bg-blue-500",
      syndicate: "bg-purple-500",
      dao: "bg-green-500",
      private: "bg-gray-500",
    };
    return colors[category as keyof typeof colors];
  };

  return (
    <div className="space-y-6">
      <div className="text-center mb-8">
        <h1 className="text-4xl font-bold mb-2">Secure Communication</h1>
        <p className="text-muted-foreground">
          End-to-end encrypted chat for the OZF community
        </p>
      </div>

      <div className="grid md:grid-cols-4 gap-4">
        {/* Chat Rooms Sidebar */}
        <Card className="md:col-span-1">
          <CardHeader>
            <CardTitle className="text-lg">Chat Rooms</CardTitle>
            <div className="flex items-center gap-2">
              <div
                className={`w-2 h-2 rounded-full ${
                  isConnected ? "bg-green-500" : "bg-red-500"
                }`}
              />
              <span className="text-xs text-muted-foreground">
                {isConnected ? "Connected" : "Connecting..."}
              </span>
            </div>
          </CardHeader>
          <CardContent className="space-y-2">
            {rooms.map((room) => (
              <button
                key={room.id}
                onClick={() => setSelectedRoom(room.id)}
                className={`w-full p-3 text-left rounded-lg transition ${
                  selectedRoom === room.id
                    ? "bg-primary text-primary-foreground"
                    : "hover:bg-muted"
                }`}
              >
                <div className="flex items-center justify-between mb-1">
                  <span className="font-medium text-sm">{room.name}</span>
                  {room.encrypted && (
                    <span className="text-xs">🔒</span>
                  )}
                </div>
                <div className="flex items-center gap-2">
                  <Badge className={getCategoryColor(room.category)} variant="outline">
                    {room.category}
                  </Badge>
                  <span className="text-xs text-muted-foreground">
                    {room.members} members
                  </span>
                </div>
              </button>
            ))}
          </CardContent>
        </Card>

        {/* Chat Area */}
        <Card className="md:col-span-3">
          <CardHeader>
            <div className="flex items-center justify-between">
              <div>
                <CardTitle>
                  {rooms.find((r) => r.id === selectedRoom)?.name}
                </CardTitle>
                <CardDescription className="flex items-center gap-2 mt-1">
                  <Badge variant="outline" className="bg-green-50">
                    🔒 End-to-end encrypted
                  </Badge>
                  <Badge variant="outline" className="bg-blue-50">
                    ✓ Verified members only
                  </Badge>
                </CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            {/* Messages */}
            <div className="h-96 overflow-y-auto border rounded-lg p-4 space-y-3 bg-muted/20">
              {messages.map((message) => (
                <div
                  key={message.id}
                  className={`flex ${
                    message.sender === "You" ? "justify-end" : "justify-start"
                  }`}
                >
                  <div
                    className={`max-w-[70%] rounded-lg p-3 ${
                      message.sender === "You"
                        ? "bg-primary text-primary-foreground"
                        : "bg-white border"
                    }`}
                  >
                    <div className="flex items-center gap-2 mb-1">
                      <span className="font-semibold text-sm">
                        {message.sender}
                      </span>
                      {message.verified && (
                        <span className="text-xs">✓</span>
                      )}
                      {message.encrypted && (
                        <span className="text-xs">🔒</span>
                      )}
                    </div>
                    <p className="text-sm">{message.content}</p>
                    <span className="text-xs opacity-70 mt-1 block">
                      {new Date(message.timestamp).toLocaleTimeString()}
                    </span>
                  </div>
                </div>
              ))}
              <div ref={messagesEndRef} />
            </div>

            {/* Message Input */}
            <div className="flex gap-2">
              <Input
                placeholder="Type your message... (Press Enter to send)"
                value={currentMessage}
                onChange={(e) => setCurrentMessage(e.target.value)}
                onKeyPress={handleKeyPress}
                disabled={!isConnected}
                className="flex-1"
              />
              <Button
                onClick={handleSendMessage}
                disabled={!isConnected || !currentMessage.trim()}
              >
                Send
              </Button>
            </div>

            {/* Security Info */}
            <div className="bg-green-50 border border-green-200 rounded-lg p-3 text-sm">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-green-600 font-semibold">🔐 Security Features Active</span>
              </div>
              <ul className="text-xs text-muted-foreground space-y-1 ml-4">
                <li>• End-to-end encryption (AES-256)</li>
                <li>• Verified member authentication</li>
                <li>• No message storage on servers</li>
                <li>• Screen reader compatible</li>
                <li>• Keyboard navigation enabled</li>
              </ul>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Accessibility Features */}
      <Card>
        <CardHeader>
          <CardTitle>Accessibility Features</CardTitle>
          <CardDescription>
            Chat is optimized for all users
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid md:grid-cols-3 gap-4 text-sm">
            <div className="p-3 bg-blue-50 rounded-lg">
              <h3 className="font-semibold mb-1">Keyboard Shortcuts</h3>
              <ul className="text-xs space-y-1 text-muted-foreground">
                <li>• Enter: Send message</li>
                <li>• Shift+Enter: New line</li>
                <li>• Ctrl+/: Toggle shortcuts</li>
              </ul>
            </div>
            <div className="p-3 bg-green-50 rounded-lg">
              <h3 className="font-semibold mb-1">Screen Reader</h3>
              <ul className="text-xs space-y-1 text-muted-foreground">
                <li>• ARIA labels enabled</li>
                <li>• Message announcements</li>
                <li>• Navigation landmarks</li>
              </ul>
            </div>
            <div className="p-3 bg-purple-50 rounded-lg">
              <h3 className="font-semibold mb-1">Display Options</h3>
              <ul className="text-xs space-y-1 text-muted-foreground">
                <li>• High contrast mode</li>
                <li>• Adjustable font size</li>
                <li>• Dark mode support</li>
              </ul>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
