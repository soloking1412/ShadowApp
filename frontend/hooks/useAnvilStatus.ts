'use client';
import { useState, useEffect } from 'react';

export type AnvilStatus = 'checking' | 'online' | 'offline';

/**
 * Polls /api/anvil-status (server-side proxy) every 5 seconds.
 * Using a server route avoids ERR_CONNECTION_REFUSED in the browser console.
 */
export function useAnvilStatus(): AnvilStatus {
  const [status, setStatus] = useState<AnvilStatus>('checking');

  useEffect(() => {
    async function check() {
      try {
        const res = await fetch('/api/anvil-status', { cache: 'no-store' });
        if (!res.ok) { setStatus('offline'); return; }
        const data: { status: string } = await res.json();
        setStatus(data.status === 'online' ? 'online' : 'offline');
      } catch {
        setStatus('offline');
      }
    }

    check();
    const id = setInterval(check, 5_000);
    return () => clearInterval(id);
  }, []);

  return status;
}
