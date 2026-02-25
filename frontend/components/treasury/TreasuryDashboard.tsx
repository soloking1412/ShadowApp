'use client';

import { useState, useMemo, useEffect } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { CONTRACTS, CURRENCY_NAMES } from '@/lib/contracts';
import { formatEther, parseEther, formatUnits } from 'viem';
import { OICDTreasuryABI } from '@/lib/abis';

export default function TreasuryDashboard() {
  const { address } = useAccount();
  const [selectedCurrency, setSelectedCurrency] = useState(9);
  const [mintAmount, setMintAmount] = useState('');
  const [recipient, setRecipient] = useState('');

  const { writeContract, data: hash, error: writeError } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });
  const [txError, setTxError] = useState<string | null>(null);
  const [showCastCmd, setShowCastCmd] = useState(false);

  useEffect(() => {
    if (!writeError) return;
    const msg = (writeError as { shortMessage?: string })?.shortMessage ?? writeError.message ?? 'Mint failed';
    setTxError(msg.length > 120 ? msg.slice(0, 120) + '…' : msg);
    const t = setTimeout(() => setTxError(null), 7000);
    return () => clearTimeout(t);
  }, [writeError]);

  // Read currency data from contract
  const { data: currencyData } = useReadContract({
    address: CONTRACTS.OICDTreasury,
    abi: OICDTreasuryABI,
    functionName: 'currencies',
    args: [BigInt(selectedCurrency)],
  });

  // Read user balance for selected currency
  const { data: userBalance } = useReadContract({
    address: CONTRACTS.OICDTreasury,
    abi: OICDTreasuryABI,
    functionName: 'balanceOf',
    args: address ? [address, BigInt(selectedCurrency)] : undefined,
    query: { enabled: !!address },
  });

  const handleMint = async () => {
    if (!recipient || !mintAmount) return;

    writeContract({
      address: CONTRACTS.OICDTreasury,
      abi: OICDTreasuryABI,
      functionName: 'mint',
      args: [recipient as `0x${string}`, BigInt(selectedCurrency), parseEther(mintAmount), '0x'],
    });
  };

  const currencies = Object.entries(CURRENCY_NAMES);

  // Get mint limit from currency data or use default
  const mintLimit = useMemo(() => {
    if (currencyData && Array.isArray(currencyData) && currencyData[6]) {
      return formatUnits(currencyData[6] as bigint, 18);
    }
    return '250000000000';
  }, [currencyData]);

  // Get total supply from currency data
  const totalSupply = useMemo(() => {
    if (currencyData && Array.isArray(currencyData) && currencyData[3]) {
      return formatUnits(currencyData[3] as bigint, 18);
    }
    return '0';
  }, [currencyData]);

  // Count of active currencies
  const activeCurrencies = currencies.length;

  return (
    <div className="space-y-6">
      {txError && (
        <div className="flex items-start gap-3 px-4 py-3 bg-red-900/40 border border-red-500/40 rounded-xl text-sm">
          <span className="text-red-400 shrink-0 mt-0.5">✕</span>
          <div className="flex-1"><p className="font-semibold text-red-300">Mint failed</p><p className="text-red-400/80 text-xs mt-0.5">{txError}</p></div>
          <button onClick={() => setTxError(null)} className="text-red-500 hover:text-red-300 text-xs shrink-0">dismiss</button>
        </div>
      )}
      {isSuccess && (
        <div className="flex items-center gap-2 px-4 py-3 bg-green-900/30 border border-green-500/30 rounded-xl text-sm">
          <span className="text-green-400">✓</span><p className="text-green-300 font-semibold">Mint transaction confirmed</p>
        </div>
      )}
      <div className="glass rounded-xl p-6">
        <h2 className="text-2xl font-bold text-white mb-2">OICD Treasury</h2>
        <p className="text-gray-400 mb-6">Manage global currency reserves and minting operations</p>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <div className="p-4 bg-gradient-to-br from-blue-500/20 to-purple-500/20 border border-blue-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Total Currencies</p>
            <p className="text-3xl font-bold text-white">{activeCurrencies}</p>
            <p className="text-xs text-blue-400 mt-1">Active globally</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-green-500/20 to-emerald-500/20 border border-green-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Mint Limit ({CURRENCY_NAMES[selectedCurrency]})</p>
            <p className="text-3xl font-bold text-white">{parseFloat(mintLimit).toLocaleString()}</p>
            <p className="text-xs text-green-400 mt-1">Tokens</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-amber-500/20 to-orange-500/20 border border-amber-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Total Supply ({CURRENCY_NAMES[selectedCurrency]})</p>
            <p className="text-3xl font-bold text-white">{parseFloat(totalSupply).toLocaleString()}</p>
            <p className="text-xs text-amber-400 mt-1">Tokens minted</p>
          </div>
        </div>
      </div>

      <div className="glass rounded-xl p-6">
        <h3 className="text-xl font-bold text-white mb-4">Mint Currency</h3>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">Select Currency</label>
            <select
              value={selectedCurrency}
              onChange={(e) => setSelectedCurrency(Number(e.target.value))}
              className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
            >
              {currencies.map(([id, name]) => (
                <option key={id} value={id}>
                  {name} - {id}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">Recipient Address</label>
            <input
              type="text"
              value={recipient}
              onChange={(e) => setRecipient(e.target.value)}
              placeholder="0x..."
              className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">
              Amount
            </label>
            <input
              type="number"
              value={mintAmount}
              onChange={(e) => setMintAmount(e.target.value)}
              placeholder="0.00"
              className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
            />
            <p className="text-xs text-gray-400 mt-1">
              Max: {parseFloat(mintLimit).toLocaleString()} |
              {address && userBalance ? ` Your Balance: ${formatUnits(userBalance as bigint, 18)}` : ' Connect wallet to see balance'}
            </p>
          </div>

          <button
            onClick={handleMint}
            disabled={isConfirming || !address || !recipient || !mintAmount}
            className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isConfirming ? 'Minting...' : 'Mint Tokens'}
          </button>

          {isSuccess && (
            <div className="p-4 bg-green-500/10 border border-green-500/20 rounded-lg">
              <p className="text-sm text-green-400">Tokens minted successfully!</p>
            </div>
          )}

          {/* MetaMask native token warning explainer */}
          <div className="p-4 bg-yellow-900/20 border border-yellow-500/30 rounded-lg">
            <p className="text-xs font-semibold text-yellow-400 mb-1">ℹ MetaMask &quot;Unexpected native token symbol&quot; warning</p>
            <p className="text-xs text-yellow-300/70">
              This is a MetaMask safety notice for local chain 31337, not an error.
              The native token IS Ether (ETH). Click <strong className="text-yellow-300">&quot;I understand, continue&quot;</strong> in the MetaMask popup to proceed normally.
              It will not affect your transaction.
            </p>
          </div>

          {/* Quick-fill presets */}
          <div className="border-t border-white/10 pt-4">
            <p className="text-xs font-semibold text-gray-400 mb-2 uppercase tracking-wide">Quick Fill</p>
            <div className="flex flex-wrap gap-2">
              {[
                { label: '25M OICD → 0x8c96…D9a', addr: '0x8c96540B2dfD9c7077782bDeB052E7a18c267D9a', amt: '25000000', cid: 10 },
                { label: '25M OTD → 0x8c96…D9a',  addr: '0x8c96540B2dfD9c7077782bDeB052E7a18c267D9a', amt: '25000000', cid: 9  },
                { label: '10M USD → 0x8c96…D9a',  addr: '0x8c96540B2dfD9c7077782bDeB052E7a18c267D9a', amt: '10000000', cid: 1  },
              ].map(p => (
                <button key={p.label} onClick={() => { setRecipient(p.addr); setMintAmount(p.amt); setSelectedCurrency(p.cid); }}
                  className="text-xs bg-blue-500/20 hover:bg-blue-500/30 text-blue-300 px-3 py-1.5 rounded-lg border border-blue-500/30 transition-all font-mono">
                  {p.label}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* ── Cast / Docker alternative (no MetaMask) ── */}
      <div className="glass rounded-xl p-5">
        <button onClick={() => setShowCastCmd(v => !v)}
          className="flex items-center justify-between w-full text-left">
          <div>
            <p className="text-sm font-bold text-white">Terminal Mint (no MetaMask required)</p>
            <p className="text-xs text-gray-400 mt-0.5">Run directly via Docker — no gas prompts, no wallet popups</p>
          </div>
          <span className="text-gray-400 text-lg">{showCastCmd ? '▲' : '▼'}</span>
        </button>

        {showCastCmd && (
          <div className="mt-4 space-y-3">
            <p className="text-xs text-gray-400">
              Mint <strong className="text-white">25,000,000 OICD</strong> (currency ID 10) to{' '}
              <code className="text-blue-400">0x8c96540B2dfD9c7077782bDeB052E7a18c267D9a</code>:
            </p>

            <pre className="text-[11px] text-green-300 font-mono bg-black/40 rounded-lg px-4 py-3 overflow-x-auto leading-relaxed whitespace-pre">{`docker compose exec anvil cast send \\
  $OICD_TREASURY \\
  "mint(address,uint256,uint256,bytes)" \\
  0x8c96540B2dfD9c7077782bDeB052E7a18c267D9a \\
  10 \\
  25000000000000000000000000 \\
  "0x" \\
  --rpc-url http://localhost:8545 \\
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`}</pre>

            <p className="text-xs text-gray-500">
              Or use the shell script at project root:{' '}
              <code className="bg-white/5 px-1 rounded">bash scripts/mint-tokens.sh</code>
            </p>

            <div className="p-3 bg-amber-900/20 border border-amber-500/20 rounded-lg text-xs text-amber-300/80">
              Replace <code className="bg-black/30 px-1 rounded">$OICD_TREASURY</code> with the actual address from your <code className="bg-black/30 px-1 rounded">.env.local</code> file
              (<code className="bg-black/30 px-1 rounded">NEXT_PUBLIC_OICD_TREASURY_ADDRESS</code>).
              The private key above is Anvil account 0 (pre-funded with 10,000 test ETH).
            </div>
          </div>
        )}
      </div>

      <div className="glass rounded-xl p-6">
        <h3 className="text-xl font-bold text-white mb-4">Currency Overview</h3>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 max-h-96 overflow-y-auto">
          {currencies.map(([id, name]) => (
            <div
              key={id}
              className="p-4 bg-white/5 hover:bg-white/10 border border-white/10 rounded-lg transition-all cursor-pointer"
            >
              <div className="flex items-center justify-between mb-2">
                <span className="font-bold text-white">{name}</span>
                <span className="text-xs text-gray-400">ID: {id}</span>
              </div>
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-400">Status</span>
                <span className="text-green-400 flex items-center gap-1">
                  <div className="w-2 h-2 rounded-full bg-green-400" />
                  Active
                </span>
              </div>
              <div className="mt-2 pt-2 border-t border-white/10">
                <p className="text-xs text-gray-400">Daily Limit: {parseFloat(mintLimit).toLocaleString()}</p>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="glass rounded-xl p-6">
        <h3 className="text-xl font-bold text-white mb-4">OTD Independence</h3>
        <div className="p-4 bg-purple-500/10 border border-purple-500/20 rounded-lg">
          <p className="text-sm text-gray-300 mb-2">
            OTD (ID: 8) operates as an independent currency separate from other OICD currencies.
          </p>
          <ul className="space-y-1 text-xs text-gray-400">
            <li className="flex items-center gap-2">
              <div className="w-1.5 h-1.5 rounded-full bg-purple-500" />
              Independent minting and supply control
            </li>
            <li className="flex items-center gap-2">
              <div className="w-1.5 h-1.5 rounded-full bg-purple-500" />
              Separate reserve backing and collateral
            </li>
            <li className="flex items-center gap-2">
              <div className="w-1.5 h-1.5 rounded-full bg-purple-500" />
              Own monetary policy and governance
            </li>
            <li className="flex items-center gap-2">
              <div className="w-1.5 h-1.5 rounded-full bg-purple-500" />
              Daily mint limit per currency
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}
