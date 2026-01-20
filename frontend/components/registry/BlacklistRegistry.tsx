"use client";

import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";

interface BlacklistEntry {
  id: string;
  name: string;
  type: "country" | "company" | "organization";
  reason: string;
  addedBy: string;
  dateAdded: number;
  status: "blacklisted" | "under_appeal" | "review_pending";
  appealDetails?: string;
  votes: {
    maintain: number;
    remove: number;
  };
}

export default function BlacklistRegistry() {
  const [entries, setEntries] = useState<BlacklistEntry[]>([
    {
      id: "1",
      name: "Corrupt Financial Corp",
      type: "company",
      reason: "Multiple violations of international financial regulations, money laundering",
      addedBy: "Syndicate Review Board",
      dateAdded: Date.now() - 86400000 * 30,
      status: "blacklisted",
      votes: { maintain: 234, remove: 12 },
    },
    {
      id: "2",
      name: "Nation X",
      type: "country",
      reason: "Ongoing human rights violations, economic exploitation",
      addedBy: "OZF Council",
      dateAdded: Date.now() - 86400000 * 60,
      status: "blacklisted",
      votes: { maintain: 456, remove: 89 },
    },
    {
      id: "3",
      name: "Questionable NGO",
      type: "organization",
      reason: "Suspected fraud and misuse of funds",
      addedBy: "Community Vote",
      dateAdded: Date.now() - 86400000 * 15,
      status: "under_appeal",
      appealDetails: "Organization has submitted evidence of compliance reforms",
      votes: { maintain: 123, remove: 167 },
    },
  ]);

  const [newEntry, setNewEntry] = useState({
    name: "",
    type: "company" as const,
    reason: "",
  });

  const [appealForm, setAppealForm] = useState({
    entryId: "",
    details: "",
  });

  const [filter, setFilter] = useState<string>("all");

  const handleAddEntry = () => {
    if (!newEntry.name || !newEntry.reason) return;

    const entry: BlacklistEntry = {
      id: Date.now().toString(),
      name: newEntry.name,
      type: newEntry.type,
      reason: newEntry.reason,
      addedBy: "Community Member",
      dateAdded: Date.now(),
      status: "review_pending",
      votes: { maintain: 0, remove: 0 },
    };

    setEntries([entry, ...entries]);
    setNewEntry({ name: "", type: "company", reason: "" });
  };

  const handleAppeal = (entryId: string) => {
    setEntries(
      entries.map((e) =>
        e.id === entryId
          ? {
              ...e,
              status: "under_appeal" as const,
              appealDetails: appealForm.details,
            }
          : e
      )
    );
    setAppealForm({ entryId: "", details: "" });
  };

  const handleVote = (entryId: string, voteType: "maintain" | "remove") => {
    setEntries(
      entries.map((e) =>
        e.id === entryId
          ? {
              ...e,
              votes: {
                ...e.votes,
                [voteType]: e.votes[voteType] + 1,
              },
            }
          : e
      )
    );
  };

  const getTypeColor = (type: string) => {
    const colors = {
      country: "bg-red-500",
      company: "bg-orange-500",
      organization: "bg-yellow-500",
    };
    return colors[type as keyof typeof colors];
  };

  const getStatusColor = (status: string) => {
    const colors = {
      blacklisted: "bg-red-100 text-red-800",
      under_appeal: "bg-yellow-100 text-yellow-800",
      review_pending: "bg-blue-100 text-blue-800",
    };
    return colors[status as keyof typeof colors];
  };

  const filteredEntries =
    filter === "all" ? entries : entries.filter((e) => e.type === filter);

  return (
    <div className="space-y-6">
      <div className="text-center mb-8">
        <h1 className="text-4xl font-bold mb-2">OZF Blacklist Registry</h1>
        <p className="text-lg text-purple-600 font-semibold mb-2">
          OZHUMANILL ZAYED FEDERATION
        </p>
        <p className="text-muted-foreground">
          Countries, companies, and organizations under review or sanctions
        </p>
      </div>

      {/* Filter Tabs */}
      <div className="flex gap-2 border-b">
        <button
          onClick={() => setFilter("all")}
          className={`px-4 py-2 ${
            filter === "all" ? "border-b-2 border-primary font-medium" : ""
          }`}
        >
          All ({entries.length})
        </button>
        <button
          onClick={() => setFilter("country")}
          className={`px-4 py-2 ${
            filter === "country" ? "border-b-2 border-primary font-medium" : ""
          }`}
        >
          Countries ({entries.filter((e) => e.type === "country").length})
        </button>
        <button
          onClick={() => setFilter("company")}
          className={`px-4 py-2 ${
            filter === "company" ? "border-b-2 border-primary font-medium" : ""
          }`}
        >
          Companies ({entries.filter((e) => e.type === "company").length})
        </button>
        <button
          onClick={() => setFilter("organization")}
          className={`px-4 py-2 ${
            filter === "organization"
              ? "border-b-2 border-primary font-medium"
              : ""
          }`}
        >
          Organizations (
          {entries.filter((e) => e.type === "organization").length})
        </button>
      </div>

      {/* Submit New Entry */}
      <Card>
        <CardHeader>
          <CardTitle>Submit Blacklist Nomination</CardTitle>
          <CardDescription>
            Nominate an entity for syndicate review (requires community approval)
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <label className="text-sm font-medium">Entity Name</label>
            <Input
              placeholder="Name of country, company, or organization"
              value={newEntry.name}
              onChange={(e) =>
                setNewEntry({ ...newEntry, name: e.target.value })
              }
            />
          </div>
          <div>
            <label className="text-sm font-medium">Type</label>
            <select
              className="w-full p-2 border rounded"
              value={newEntry.type}
              onChange={(e) =>
                setNewEntry({ ...newEntry, type: e.target.value as any })
              }
            >
              <option value="company">Company</option>
              <option value="country">Country</option>
              <option value="organization">Organization</option>
            </select>
          </div>
          <div>
            <label className="text-sm font-medium">
              Reason for Blacklisting
            </label>
            <Textarea
              placeholder="Detailed explanation with evidence and justification"
              rows={4}
              value={newEntry.reason}
              onChange={(e) =>
                setNewEntry({ ...newEntry, reason: e.target.value })
              }
            />
          </div>
          <Button onClick={handleAddEntry} className="w-full">
            Submit for Review
          </Button>
        </CardContent>
      </Card>

      {/* Blacklist Entries */}
      <div className="space-y-4">
        <h2 className="text-2xl font-bold">Registry Entries</h2>
        {filteredEntries.map((entry) => (
          <Card key={entry.id}>
            <CardHeader>
              <div className="flex items-start justify-between">
                <div className="space-y-2">
                  <CardTitle className="flex items-center gap-2">
                    {entry.name}
                    <Badge className={getTypeColor(entry.type)}>
                      {entry.type}
                    </Badge>
                  </CardTitle>
                  <Badge className={getStatusColor(entry.status)}>
                    {entry.status.replace(/_/g, " ")}
                  </Badge>
                </div>
                <div className="text-right">
                  <div className="text-sm font-medium">Community Vote</div>
                  <div className="text-xs text-muted-foreground">
                    Maintain: {entry.votes.maintain} | Remove:{" "}
                    {entry.votes.remove}
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
                <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3">
                  <h3 className="font-semibold text-sm mb-1">
                    Appeal Details:
                  </h3>
                  <p className="text-sm text-muted-foreground">
                    {entry.appealDetails}
                  </p>
                </div>
              )}

              <div className="flex items-center justify-between text-sm text-muted-foreground">
                <div>
                  Added by {entry.addedBy} •{" "}
                  {new Date(entry.dateAdded).toLocaleDateString()}
                </div>
                <div className="flex gap-2">
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => handleVote(entry.id, "maintain")}
                  >
                    Vote to Maintain
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => handleVote(entry.id, "remove")}
                  >
                    Vote to Remove
                  </Button>
                </div>
              </div>

              {entry.status === "blacklisted" && !entry.appealDetails && (
                <div className="border-t pt-4">
                  <h3 className="font-semibold text-sm mb-2">
                    File an Appeal
                  </h3>
                  <div className="flex gap-2">
                    <Textarea
                      placeholder="Enter appeal details and evidence for syndicate review..."
                      rows={2}
                      value={
                        appealForm.entryId === entry.id
                          ? appealForm.details
                          : ""
                      }
                      onChange={(e) =>
                        setAppealForm({
                          entryId: entry.id,
                          details: e.target.value,
                        })
                      }
                    />
                    <Button
                      onClick={() => handleAppeal(entry.id)}
                      disabled={
                        appealForm.entryId !== entry.id ||
                        !appealForm.details
                      }
                    >
                      Submit Appeal
                    </Button>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Appeals Process Info */}
      <Card className="border-blue-500">
        <CardHeader>
          <CardTitle>Appeals Process</CardTitle>
          <CardDescription>
            How blacklisted entities can request review
          </CardDescription>
        </CardHeader>
        <CardContent>
          <ol className="list-decimal list-inside space-y-2 text-sm">
            <li>Entity submits formal appeal with evidence of compliance/reform</li>
            <li>Appeal is reviewed by the Syndicate Review Board</li>
            <li>Community members vote on whether to maintain or remove blacklist</li>
            <li>
              Super-majority (66%) vote required to remove from blacklist
            </li>
            <li>
              Appeals can be re-submitted after 90 days if rejected
            </li>
          </ol>
          <div className="mt-4 p-3 bg-blue-50 rounded-lg text-sm">
            <strong>Note:</strong> The OZF (OZHUMANILL ZAYED FEDERATION) will
            not support blacklisted entities unless they successfully complete
            the appellate proceeding.
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
