'use client';
import { useAnvilStatus } from '@/hooks/useAnvilStatus';

/**
 * Shows a dismissible warning banner when Anvil (local blockchain) is offline.
 * Useful for development — tells the user exactly how to start Anvil.
 */
export default function AnvilStatusBanner() {
  const status = useAnvilStatus();

  if (status !== 'offline') return null;

  return (
    <div className="flex items-start gap-3 px-4 py-3 bg-red-900/30 border-b border-red-500/40 text-sm">
      <span className="text-red-400 text-lg leading-none mt-0.5">⚠</span>
      <div>
        <p className="font-semibold text-red-300">Local blockchain offline</p>
        <p className="text-red-400/80 text-xs mt-0.5">
          Anvil node at <code className="bg-red-900/40 px-1 rounded">localhost:8545</code> is not reachable.
          Contract reads / writes will fail. To start:
        </p>
        <pre className="mt-1.5 text-[11px] text-red-300 bg-red-950/60 rounded px-2 py-1.5 font-mono leading-snug">
{`docker compose up --force-recreate deployer`}
        </pre>
        <p className="text-red-400/70 text-[11px] mt-1">
          Then copy the printed <code className="bg-red-900/40 px-1 rounded">NEXT_PUBLIC_*_ADDRESS</code> values
          to <code className="bg-red-900/40 px-1 rounded">frontend/.env.local</code> and restart Next.js.
        </p>
      </div>
    </div>
  );
}
