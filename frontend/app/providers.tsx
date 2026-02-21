'use client';

import { ReactNode } from 'react';
import { WagmiProvider, http, createConfig } from 'wagmi';
import { arbitrumSepolia } from 'wagmi/chains';
import { defineChain } from 'viem';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import {
  RainbowKitProvider,
  getDefaultConfig,
  connectorsForWallets,
  darkTheme,
} from '@rainbow-me/rainbowkit';
import { injectedWallet, coinbaseWallet } from '@rainbow-me/rainbowkit/wallets';
import '@rainbow-me/rainbowkit/styles.css';

const anvil = defineChain({
  id: 31337,
  name: 'Anvil Local',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: ['http://localhost:8545'] },
  },
  testnet: true,
});

const chainId = parseInt(process.env.NEXT_PUBLIC_CHAIN_ID || '421614');
const isLocal = chainId === 31337;
const walletConnectProjectId = process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID || '';
const chains = isLocal
  ? ([anvil, arbitrumSepolia] as const)
  : ([arbitrumSepolia, anvil] as const);

const transports = {
  [anvil.id]: http(process.env.NEXT_PUBLIC_RPC_URL || 'http://localhost:8545'),
  [arbitrumSepolia.id]: http(process.env.NEXT_PUBLIC_ARBITRUM_RPC_URL),
};

// Local dev (no WC project ID): use connectorsForWallets with ONLY injectedWallet.
// injectedWallet does NOT use WalletConnect internally → no WC Core init → no relay errors.
// connectorsForWallets wraps the connector in RainbowKit's format so the modal
// correctly shows "MetaMask" / "Browser Wallet" options (raw injected() does not).
// Production: use getDefaultConfig which includes WalletConnect, Coinbase, etc.
const config = walletConnectProjectId
  ? getDefaultConfig({
      appName: 'ShadowDapp',
      projectId: walletConnectProjectId,
      chains,
      transports,
      ssr: true,
    })
  : createConfig({
      chains,
      transports,
      connectors: connectorsForWallets(
        [{ groupName: 'Wallets', wallets: [injectedWallet, coinbaseWallet] }],
        { appName: 'ShadowDapp', projectId: 'local-dev-only' },
      ),
      ssr: true,
    });

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: false,
      staleTime: 10_000,
    },
  },
});

export function Providers({ children }: { children: ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider
          initialChain={isLocal ? anvil : arbitrumSepolia}
          theme={darkTheme({
            accentColor: '#0ea5e9',
            accentColorForeground: 'white',
            borderRadius: 'medium',
            fontStack: 'system',
          })}
        >
          {children}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
