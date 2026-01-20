"use client";

import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

interface MediaSource {
  id: string;
  name: string;
  url: string;
  category: "mainstream" | "contrarian" | "independent" | "government";
  governmentPromoted: boolean;
  reliability: number;
  bias: "left" | "center" | "right" | "neutral";
  recentArticles: number;
}

interface Article {
  id: string;
  title: string;
  source: string;
  url: string;
  category: string;
  governmentNarrative: boolean;
  timestamp: number;
}

export default function MediaMonitor() {
  const [sources] = useState<MediaSource[]>([
    {
      id: "1",
      name: "Global Economic Times",
      url: "https://example.com/get",
      category: "mainstream",
      governmentPromoted: true,
      reliability: 65,
      bias: "center",
      recentArticles: 45,
    },
    {
      id: "2",
      name: "Alternative Finance Daily",
      url: "https://example.com/afd",
      category: "contrarian",
      governmentPromoted: false,
      reliability: 78,
      bias: "neutral",
      recentArticles: 23,
    },
    {
      id: "3",
      name: "Independent Economic Review",
      url: "https://example.com/ier",
      category: "independent",
      governmentPromoted: false,
      reliability: 85,
      bias: "neutral",
      recentArticles: 18,
    },
    {
      id: "4",
      name: "State Financial Bulletin",
      url: "https://example.com/sfb",
      category: "government",
      governmentPromoted: true,
      reliability: 55,
      bias: "left",
      recentArticles: 67,
    },
  ]);

  const [articles] = useState<Article[]>([
    {
      id: "1",
      title: "Central Banks Signal New Monetary Easing",
      source: "Global Economic Times",
      url: "#",
      category: "mainstream",
      governmentNarrative: true,
      timestamp: Date.now() - 3600000,
    },
    {
      id: "2",
      title: "Hidden Risks in Global Debt Markets Exposed",
      source: "Alternative Finance Daily",
      url: "#",
      category: "contrarian",
      governmentNarrative: false,
      timestamp: Date.now() - 7200000,
    },
    {
      id: "3",
      title: "Analysis: True State of Sovereign Reserves",
      source: "Independent Economic Review",
      url: "#",
      category: "independent",
      governmentNarrative: false,
      timestamp: Date.now() - 10800000,
    },
  ]);

  const [filter, setFilter] = useState<string>("all");

  const getCategoryColor = (category: string) => {
    const colors = {
      mainstream: "bg-blue-500",
      contrarian: "bg-purple-500",
      independent: "bg-green-500",
      government: "bg-red-500",
    };
    return colors[category as keyof typeof colors];
  };

  const getBiasColor = (bias: string) => {
    const colors = {
      left: "bg-blue-100 text-blue-800",
      center: "bg-gray-100 text-gray-800",
      right: "bg-red-100 text-red-800",
      neutral: "bg-green-100 text-green-800",
    };
    return colors[bias as keyof typeof colors];
  };

  const filteredArticles =
    filter === "all"
      ? articles
      : articles.filter((a) => a.category === filter);

  return (
    <div className="space-y-6">
      <div className="text-center mb-8">
        <h1 className="text-4xl font-bold mb-2">Media Monitor</h1>
        <p className="text-muted-foreground">
          Track contrarian sites and government-promoted media narratives
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
          All Sources
        </button>
        <button
          onClick={() => setFilter("contrarian")}
          className={`px-4 py-2 ${
            filter === "contrarian"
              ? "border-b-2 border-primary font-medium"
              : ""
          }`}
        >
          Contrarian
        </button>
        <button
          onClick={() => setFilter("government")}
          className={`px-4 py-2 ${
            filter === "government"
              ? "border-b-2 border-primary font-medium"
              : ""
          }`}
        >
          Government Promoted
        </button>
        <button
          onClick={() => setFilter("independent")}
          className={`px-4 py-2 ${
            filter === "independent"
              ? "border-b-2 border-primary font-medium"
              : ""
          }`}
        >
          Independent
        </button>
      </div>

      {/* Media Sources */}
      <div className="grid md:grid-cols-2 gap-4">
        <Card>
          <CardHeader>
            <CardTitle>Tracked Media Sources</CardTitle>
            <CardDescription>
              Monitoring {sources.length} media outlets
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            {sources.map((source) => (
              <div
                key={source.id}
                className="p-3 border rounded-lg hover:bg-muted/50 transition"
              >
                <div className="flex items-start justify-between mb-2">
                  <div>
                    <h3 className="font-semibold">{source.name}</h3>
                    <a
                      href={source.url}
                      className="text-sm text-blue-500 hover:underline"
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      {source.url}
                    </a>
                  </div>
                  {source.governmentPromoted && (
                    <Badge variant="destructive" className="text-xs">
                      Gov Promoted
                    </Badge>
                  )}
                </div>
                <div className="flex gap-2 flex-wrap">
                  <Badge className={getCategoryColor(source.category)}>
                    {source.category}
                  </Badge>
                  <Badge className={getBiasColor(source.bias)}>
                    {source.bias}
                  </Badge>
                  <Badge variant="outline">
                    Reliability: {source.reliability}%
                  </Badge>
                  <Badge variant="outline">
                    {source.recentArticles} articles
                  </Badge>
                </div>
              </div>
            ))}
          </CardContent>
        </Card>

        {/* Recent Articles */}
        <Card>
          <CardHeader>
            <CardTitle>Recent Articles</CardTitle>
            <CardDescription>Latest coverage from tracked sources</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            {filteredArticles.map((article) => (
              <div
                key={article.id}
                className="p-3 border rounded-lg hover:bg-muted/50 transition"
              >
                <div className="flex items-start justify-between mb-2">
                  <h3 className="font-semibold text-sm">{article.title}</h3>
                  {article.governmentNarrative && (
                    <Badge variant="outline" className="text-xs bg-red-50">
                      Gov Narrative
                    </Badge>
                  )}
                </div>
                <div className="text-xs text-muted-foreground mb-2">
                  {article.source} •{" "}
                  {new Date(article.timestamp).toLocaleString()}
                </div>
                <div className="flex gap-2">
                  <Badge className={getCategoryColor(article.category)}>
                    {article.category}
                  </Badge>
                  <Button size="sm" variant="outline" className="h-6 text-xs">
                    Read Article
                  </Button>
                </div>
              </div>
            ))}
          </CardContent>
        </Card>
      </div>

      {/* Government Narrative Alert */}
      <Card className="border-orange-500">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <span className="text-orange-500">⚠️</span>
            Government Narrative Detection
          </CardTitle>
          <CardDescription>
            Tracking media sources heavily promoted by governments
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-2">
            <p className="text-sm">
              <strong>
                {sources.filter((s) => s.governmentPromoted).length}
              </strong>{" "}
              sources identified as government-promoted
            </p>
            <p className="text-sm">
              <strong>
                {articles.filter((a) => a.governmentNarrative).length}
              </strong>{" "}
              articles align with official narratives
            </p>
            <p className="text-sm text-muted-foreground">
              Compare government-promoted content with independent and
              contrarian sources for balanced perspective
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
