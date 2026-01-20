"use client";

import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";

interface LobbyProposal {
  id: string;
  title: string;
  description: string;
  category: "monetary" | "fiscal" | "investment" | "regulation";
  author: string;
  votes: number;
  status: "active" | "under_review" | "approved" | "rejected";
  timestamp: number;
}

export default function PublicLobby() {
  const [proposals, setProposals] = useState<LobbyProposal[]>([
    {
      id: "1",
      title: "Increase Infrastructure Investment in Developing Nations",
      description: "Propose 15% increase in global infrastructure bonds for emerging markets",
      category: "investment",
      author: "0x1234...5678",
      votes: 1250,
      status: "active",
      timestamp: Date.now() - 86400000,
    },
    {
      id: "2",
      title: "Reform International Monetary Policy",
      description: "Advocate for decentralized reserve currency system",
      category: "monetary",
      author: "0xabcd...ef12",
      votes: 890,
      status: "under_review",
      timestamp: Date.now() - 172800000,
    },
  ]);

  const [newProposal, setNewProposal] = useState({
    title: "",
    description: "",
    category: "investment" as const,
  });

  const handleSubmitProposal = () => {
    if (!newProposal.title || !newProposal.description) return;

    const proposal: LobbyProposal = {
      id: Date.now().toString(),
      title: newProposal.title,
      description: newProposal.description,
      category: newProposal.category,
      author: "0x0000...0000", // Would be connected wallet
      votes: 0,
      status: "active",
      timestamp: Date.now(),
    };

    setProposals([proposal, ...proposals]);
    setNewProposal({ title: "", description: "", category: "investment" });
  };

  const handleVote = (id: string) => {
    setProposals(
      proposals.map((p) =>
        p.id === id ? { ...p, votes: p.votes + 1 } : p
      )
    );
  };

  const getCategoryColor = (category: string) => {
    const colors = {
      monetary: "bg-blue-500",
      fiscal: "bg-green-500",
      investment: "bg-purple-500",
      regulation: "bg-orange-500",
    };
    return colors[category as keyof typeof colors];
  };

  const getStatusColor = (status: string) => {
    const colors = {
      active: "bg-green-100 text-green-800",
      under_review: "bg-yellow-100 text-yellow-800",
      approved: "bg-blue-100 text-blue-800",
      rejected: "bg-red-100 text-red-800",
    };
    return colors[status as keyof typeof colors];
  };

  return (
    <div className="space-y-6">
      <div className="text-center mb-8">
        <h1 className="text-4xl font-bold mb-2">Public Lobby</h1>
        <p className="text-muted-foreground">
          Propose financial changes and investments to shape the world economy
        </p>
      </div>

      {/* Submit New Proposal */}
      <Card>
        <CardHeader>
          <CardTitle>Submit New Proposal</CardTitle>
          <CardDescription>
            Share your ideas for economic reforms and investment strategies
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <label className="text-sm font-medium">Title</label>
            <Input
              placeholder="Brief title for your proposal"
              value={newProposal.title}
              onChange={(e) =>
                setNewProposal({ ...newProposal, title: e.target.value })
              }
            />
          </div>
          <div>
            <label className="text-sm font-medium">Description</label>
            <Textarea
              placeholder="Detailed description of your proposal and expected impact"
              rows={4}
              value={newProposal.description}
              onChange={(e) =>
                setNewProposal({ ...newProposal, description: e.target.value })
              }
            />
          </div>
          <div>
            <label className="text-sm font-medium">Category</label>
            <select
              className="w-full p-2 border rounded"
              value={newProposal.category}
              onChange={(e) =>
                setNewProposal({
                  ...newProposal,
                  category: e.target.value as any,
                })
              }
            >
              <option value="investment">Investment</option>
              <option value="monetary">Monetary Policy</option>
              <option value="fiscal">Fiscal Policy</option>
              <option value="regulation">Regulation</option>
            </select>
          </div>
          <Button onClick={handleSubmitProposal} className="w-full">
            Submit Proposal
          </Button>
        </CardContent>
      </Card>

      {/* Active Proposals */}
      <div className="space-y-4">
        <h2 className="text-2xl font-bold">Active Proposals</h2>
        {proposals.map((proposal) => (
          <Card key={proposal.id}>
            <CardHeader>
              <div className="flex items-start justify-between">
                <div className="space-y-2">
                  <CardTitle>{proposal.title}</CardTitle>
                  <div className="flex gap-2">
                    <Badge className={getCategoryColor(proposal.category)}>
                      {proposal.category}
                    </Badge>
                    <Badge className={getStatusColor(proposal.status)}>
                      {proposal.status.replace("_", " ")}
                    </Badge>
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-2xl font-bold">{proposal.votes}</div>
                  <div className="text-sm text-muted-foreground">votes</div>
                </div>
              </div>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-muted-foreground">{proposal.description}</p>
              <div className="flex items-center justify-between">
                <div className="text-sm text-muted-foreground">
                  By {proposal.author} •{" "}
                  {new Date(proposal.timestamp).toLocaleDateString()}
                </div>
                <Button onClick={() => handleVote(proposal.id)}>
                  Vote for this proposal
                </Button>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
