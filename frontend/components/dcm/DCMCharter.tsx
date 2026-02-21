'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import {
  useCurrentScore,
  useGetPillar,
  useReportCount,
  usePublishReport,
  useRetailFee,
  useInstitutionalFee,
  useTransactionFeeBps,
  useIsActiveSubscriber,
} from '@/hooks/contracts/useDCMMarketCharter';

// Pillar display metadata
const PILLAR_META = [
  { label: 'Public Market Health',      color: 'blue',   icon: '📈' },
  { label: 'Global Market Health',      color: 'purple', icon: '🌐' },
  { label: 'Corporate Financial Health',color: 'amber',  icon: '🏢' },
  { label: 'Public Financial Health',   color: 'green',  icon: '🏛️' },
];

const colorMap: Record<string, { bar: string; text: string; border: string; bg: string }> = {
  blue:   { bar: 'bg-blue-500',   text: 'text-blue-300',   border: 'border-blue-700/50',   bg: 'bg-blue-900/20' },
  purple: { bar: 'bg-purple-500', text: 'text-purple-300', border: 'border-purple-700/50', bg: 'bg-purple-900/20' },
  amber:  { bar: 'bg-amber-500',  text: 'text-amber-300',  border: 'border-amber-700/50',  bg: 'bg-amber-900/20' },
  green:  { bar: 'bg-green-500',  text: 'text-green-300',  border: 'border-green-700/50',  bg: 'bg-green-900/20' },
};

function ScoreGauge({ score, max = 100, color = 'blue' }: { score: number; max?: number; color?: string }) {
  const pct = Math.min(100, (score / max) * 100);
  const c = colorMap[color] ?? colorMap.blue;
  return (
    <div className="w-full bg-gray-700 rounded-full h-2 mt-1">
      <div
        className={`h-2 rounded-full transition-all duration-500 ${c.bar}`}
        style={{ width: `${pct}%` }}
      />
    </div>
  );
}

function PillarCard({ idx }: { idx: number }) {
  const { data } = useGetPillar(idx);
  const meta = PILLAR_META[idx];
  const c = colorMap[meta.color];

  if (!data) {
    return (
      <div className={`rounded-xl border p-4 ${c.border} ${c.bg} animate-pulse`}>
        <div className="h-4 bg-gray-700 rounded w-3/4 mb-2" />
        <div className="h-2 bg-gray-700 rounded mb-4" />
        <div className="space-y-2">
          {[0,1,2,3].map(i => <div key={i} className="h-3 bg-gray-700 rounded" />)}
        </div>
      </div>
    );
  }

  const [, pillarScore, metricNames, metricScores] = data as [string, number, string[], number[]];

  return (
    <div className={`rounded-xl border p-4 ${c.border} ${c.bg}`}>
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <span className="text-xl">{meta.icon}</span>
          <h4 className={`text-sm font-semibold ${c.text}`}>{meta.label}</h4>
        </div>
        <span className={`text-lg font-bold ${c.text}`}>{pillarScore}/100</span>
      </div>
      <ScoreGauge score={pillarScore} color={meta.color} />

      <div className="mt-3 space-y-2">
        {metricNames.map((name: string, i: number) => (
          <div key={i} className="flex items-center justify-between">
            <span className="text-xs text-gray-400 flex-1 truncate pr-2">{name}</span>
            <div className="flex items-center gap-2">
              <div className="w-16 bg-gray-700 rounded-full h-1">
                <div
                  className={`h-1 rounded-full ${c.bar}`}
                  style={{ width: `${metricScores[i]}%` }}
                />
              </div>
              <span className="text-xs text-gray-300 w-6 text-right">{metricScores[i]}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

export default function DCMCharter() {
  const { address } = useAccount();
  const [showSub, setShowSub] = useState(false);

  const { data: scoreData }    = useCurrentScore();
  const { data: reportCount }  = useReportCount();
  const { data: retailFee }    = useRetailFee();
  const { data: instFee }      = useInstitutionalFee();
  const { data: feeBps }       = useTransactionFeeBps();
  const { data: isSub }        = useIsActiveSubscriber(address);

  const { publishReport, isPending, isConfirming, isSuccess, error } = usePublishReport();

  const [total, p1, p2, p3, p4] = scoreData
    ? (scoreData as [bigint | number, number, number, number, number])
    : [null, null, null, null, null];

  const totalNum = total !== null ? Number(total) : null;
  const healthPct = totalNum !== null ? ((totalNum / 400) * 100).toFixed(1) : null;

  const getHealthLabel = (score: number | null) => {
    if (score === null) return { label: '—', color: 'text-gray-400' };
    if (score >= 350) return { label: 'Excellent', color: 'text-green-400' };
    if (score >= 280) return { label: 'Good',      color: 'text-blue-400' };
    if (score >= 200) return { label: 'Fair',      color: 'text-amber-400' };
    return { label: 'Poor', color: 'text-red-400' };
  };

  const health = getHealthLabel(totalNum);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-gradient-to-r from-blue-900/40 to-purple-900/40 border border-blue-700/50 rounded-xl p-6">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-2xl font-bold text-blue-300">DCM Market Charter</h2>
            <p className="text-blue-400/70 text-sm mt-1">
              SGM Decentralized Capital Markets — 4-Pillar Health Scoring System
            </p>
          </div>
          <div className="text-right">
            <div className={`text-3xl font-bold ${health.color}`}>
              {totalNum !== null ? totalNum : '—'}/400
            </div>
            <div className={`text-sm font-medium ${health.color}`}>{health.label}</div>
          </div>
        </div>

        {/* Overall gauge */}
        {totalNum !== null && (
          <div className="mt-4">
            <div className="flex justify-between text-xs text-gray-400 mb-1">
              <span>Overall Market Health</span>
              <span>{healthPct}%</span>
            </div>
            <div className="w-full bg-gray-700 rounded-full h-3">
              <div
                className="h-3 rounded-full bg-gradient-to-r from-blue-500 via-purple-500 to-green-500 transition-all duration-700"
                style={{ width: `${healthPct}%` }}
              />
            </div>
          </div>
        )}

        {/* Quick stats */}
        <div className="grid grid-cols-4 gap-3 mt-4">
          {[
            { label: 'Public Market', score: p1, color: 'blue' },
            { label: 'Global Market', score: p2, color: 'purple' },
            { label: 'Corporate',     score: p3, color: 'amber' },
            { label: 'Public Fin.',   score: p4, color: 'green' },
          ].map(({ label, score, color }) => (
            <div key={label} className="bg-black/30 rounded-lg p-2 text-center">
              <div className={`text-lg font-bold ${colorMap[color]?.text ?? 'text-white'}`}>
                {score !== null ? score : '—'}
              </div>
              <div className="text-xs text-gray-400">{label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* 4 Pillar Cards */}
      <div className="grid grid-cols-2 gap-4">
        {[0, 1, 2, 3].map((idx) => <PillarCard key={idx} idx={idx} />)}
      </div>

      {/* Revenue Model */}
      <div className="bg-gray-800/50 border border-gray-700 rounded-xl p-5">
        <h3 className="text-sm font-semibold text-gray-300 mb-4">Revenue Model</h3>
        <div className="grid grid-cols-3 gap-4">
          <div className="bg-black/30 rounded-lg p-4 text-center">
            <div className="text-2xl font-bold text-blue-300">$3</div>
            <div className="text-xs text-gray-400 mt-1">Retail / Month</div>
            <div className="text-xs text-blue-400/70 mt-1">Individual access</div>
          </div>
          <div className="bg-black/30 rounded-lg p-4 text-center">
            <div className="text-2xl font-bold text-purple-300">$8</div>
            <div className="text-xs text-gray-400 mt-1">Institutional / Month</div>
            <div className="text-xs text-purple-400/70 mt-1">Full data access</div>
          </div>
          <div className="bg-black/30 rounded-lg p-4 text-center">
            <div className="text-2xl font-bold text-amber-300">
              {feeBps !== undefined ? `${Number(feeBps) / 100}%` : '0.09%'}
            </div>
            <div className="text-xs text-gray-400 mt-1">Transaction Fee</div>
            <div className="text-xs text-amber-400/70 mt-1">Per trade</div>
          </div>
        </div>

        {/* Subscription status */}
        {address && (
          <div className="mt-4 p-3 rounded-lg bg-black/20 border border-gray-700/50">
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-300">Subscription Status</span>
              {isSub ? (
                <span className="px-2 py-1 bg-green-900/30 text-green-400 rounded text-xs border border-green-700/50">
                  Active Subscriber
                </span>
              ) : (
                <span className="px-2 py-1 bg-gray-700 text-gray-400 rounded text-xs">
                  Not Subscribed
                </span>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Publish Report */}
      <div className="bg-gray-800/50 border border-gray-700 rounded-xl p-5">
        <div className="flex items-center justify-between mb-3">
          <div>
            <h3 className="text-sm font-semibold text-white">Health Reports</h3>
            <p className="text-xs text-gray-400 mt-0.5">
              {reportCount != null ? reportCount.toString() : '0'} reports published on-chain
            </p>
          </div>
          {address && (
            <button
              onClick={() => publishReport()}
              disabled={isPending || isConfirming}
              className="px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-700 text-white text-sm font-medium rounded-lg transition-colors"
            >
              {isPending ? 'Confirm…' : isConfirming ? 'Publishing…' : 'Publish Report'}
            </button>
          )}
        </div>
        {isSuccess && (
          <p className="text-green-400 text-xs mt-2">Report published successfully on-chain!</p>
        )}
        {!!error && (
          <p className="text-red-400 text-xs mt-2">
            {error instanceof Error ? error.message : String(error)}
          </p>
        )}
      </div>

      {/* About DCM Charter */}
      <div className="bg-gray-800/30 border border-gray-700/50 rounded-xl p-5">
        <h3 className="text-sm font-semibold text-gray-300 mb-3">About the DCM Market Charter</h3>
        <div className="text-sm text-gray-400 space-y-2">
          <p>
            The <strong className="text-white">DCM Market Charter</strong> is a comprehensive 4-pillar
            health scoring framework developed by Samuel Global Management (SGM) for monitoring the
            health of the Decentralized Capital Markets platform.
          </p>
          <p>
            Each of the 4 pillars contains 4 metrics scored 0–100, giving a total possible score
            of <strong className="text-white">400/400</strong>. Scores are updated by oracles and
            snapshotted as immutable health reports on-chain.
          </p>
          <div className="grid grid-cols-2 gap-3 mt-3">
            {PILLAR_META.map((p, i) => (
              <div key={i} className="flex items-start gap-2">
                <span>{p.icon}</span>
                <div>
                  <div className="text-white text-xs font-medium">{p.label}</div>
                  <div className="text-gray-500 text-xs">4 metrics · 100 pts</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
