'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatEther } from 'viem';
import { CONTRACTS } from '@/lib/contracts';
import {
  SUPPORTED_COUNTRY_CODES,
  useRegisterIBAN,
  useDepositToIBAN,
  useWithdrawFromIBAN,
  useInterBankTransfer,
  useUseCredit,
  useRepayCredit,
  useMyIBANAccount,
  useAllCountries,
  useGlobalDebtIndex,
  formatIBANDisplay,
  calculateAvailableCredit,
} from '@/hooks/contracts/useShadowBank';

function fmt(val: bigint) {
  const n = Number(formatEther(val));
  if (n >= 1e9) return `${(n / 1e9).toFixed(4)}B ETH`;
  if (n >= 1e6) return `${(n / 1e6).toFixed(4)}M ETH`;
  if (n >= 1e3) return `${(n / 1e3).toFixed(4)}K ETH`;
  return `${n.toFixed(6)} ETH`;
}

type Tab = 'register' | 'deposit' | 'withdraw' | 'transfer' | 'credit';

export default function FractionalReserveDashboard() {
  const { address } = useAccount();
  const notDeployed = !CONTRACTS.FractionalReserveBanking;

  // Live contract reads
  const { ibanHash, account, hasIBAN, isLoading: isLoadingAccount } = useMyIBANAccount();
  const { data: allCountries } = useAllCountries();
  const { data: gdi } = useGlobalDebtIndex();

  // Write hooks
  const { registerIBAN, isPending: regPending, isConfirming: regConfirming, isSuccess: regSuccess, error: regError } = useRegisterIBAN();
  const { deposit, isPending: depPending, isConfirming: depConfirming, isSuccess: depSuccess, error: depError } = useDepositToIBAN();
  const { withdraw, isPending: wdPending, isConfirming: wdConfirming, isSuccess: wdSuccess, error: wdError } = useWithdrawFromIBAN();
  const { transfer, calculateFee, calculateNet, isPending: trPending, isConfirming: trConfirming, isSuccess: trSuccess, error: trError } = useInterBankTransfer();
  const { useCredit, isPending: crPending, isConfirming: crConfirming, isSuccess: crSuccess, error: crError } = useUseCredit();
  const { repayCredit, isPending: rpPending, isConfirming: rpConfirming, isSuccess: rpSuccess, error: rpError } = useRepayCredit();

  // Form state
  const [tab, setTab] = useState<Tab>('register');
  const [regCountry, setRegCountry] = useState<typeof SUPPORTED_COUNTRY_CODES[number]>('US');
  const [regBankCode, setRegBankCode] = useState('');
  const [depositAmt, setDepositAmt] = useState('');
  const [withdrawAmt, setWithdrawAmt] = useState('');
  const [toIBAN, setToIBAN] = useState('');
  const [transferAmt, setTransferAmt] = useState('');
  const [creditAmt, setCreditAmt] = useState('');
  const [repayAmt, setRepayAmt] = useState('');

  const countries = (allCountries as string[] | undefined) ?? [];
  const availableCredit = calculateAvailableCredit(account);

  const safeParseEther = (v: string) => {
    try { return v && Number(v) > 0; } catch { return false; }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="glass rounded-xl p-6">
        <h2 className="text-2xl font-bold text-white mb-2">Fractional Reserve Banking</h2>
        <p className="text-gray-400 mb-6">IBAN-based banking system with cross-border transfers and credit lines</p>

        {notDeployed && (
          <div className="mb-4 p-3 bg-yellow-500/10 border border-yellow-500/30 rounded-lg text-yellow-400 text-sm">
            FractionalReserveBanking contract not deployed — deploy via docker compose.
          </div>
        )}

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="p-4 bg-gradient-to-br from-blue-500/20 to-cyan-500/20 border border-blue-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Registered Countries</p>
            <p className="text-3xl font-bold text-white">{countries.length || '—'}</p>
            <p className="text-xs text-blue-400 mt-1">On-chain</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-green-500/20 to-emerald-500/20 border border-green-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">My Balance</p>
            <p className="text-2xl font-bold text-white truncate">
              {account ? fmt(account.balance) : (isLoadingAccount ? '...' : '—')}
            </p>
            <p className="text-xs text-green-400 mt-1">IBAN account</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-purple-500/20 to-violet-500/20 border border-purple-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Available Credit</p>
            <p className="text-2xl font-bold text-white truncate">
              {account ? fmt(availableCredit) : '—'}
            </p>
            <p className="text-xs text-purple-400 mt-1">Credit line</p>
          </div>
          <div className="p-4 bg-gradient-to-br from-amber-500/20 to-orange-500/20 border border-amber-500/30 rounded-lg">
            <p className="text-sm text-gray-400 mb-1">Global Debt Index</p>
            <p className="text-3xl font-bold text-white">
              {gdi !== undefined ? String(gdi) : '—'}
            </p>
            <p className="text-xs text-amber-400 mt-1">On-chain</p>
          </div>
        </div>
      </div>

      {/* My IBAN Card */}
      {address && (
        <div className="glass rounded-xl p-6">
          <h3 className="text-xl font-bold text-white mb-4">My IBAN Account</h3>
          {isLoadingAccount ? (
            <p className="text-gray-400 text-sm">Loading account…</p>
          ) : hasIBAN && account ? (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">IBAN</span>
                  <span className="text-white font-mono text-xs">
                    {formatIBANDisplay(ibanHash!, account.countryCode, account.bankCode)}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Country</span>
                  <span className="text-white font-semibold">{account.countryCode}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Bank Code</span>
                  <span className="text-white font-semibold">{account.bankCode}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Status</span>
                  <span className={account.active ? 'text-green-400' : 'text-red-400'}>
                    {account.active ? 'Active' : 'Inactive'}
                  </span>
                </div>
              </div>
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Balance</span>
                  <span className="text-green-400 font-semibold">{fmt(account.balance)}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Credit Line</span>
                  <span className="text-blue-400 font-semibold">{fmt(account.creditLine)}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Credit Used</span>
                  <span className="text-amber-400 font-semibold">{fmt(account.creditUsed)}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Available Credit</span>
                  <span className="text-purple-400 font-semibold">{fmt(availableCredit)}</span>
                </div>
              </div>
            </div>
          ) : (
            <div className="p-6 text-center bg-white/5 rounded-lg">
              <p className="text-4xl mb-2">🏦</p>
              <p className="text-white font-medium mb-1">No IBAN account found</p>
              <p className="text-gray-400 text-sm">Register an IBAN below to start banking</p>
            </div>
          )}
        </div>
      )}

      {/* Action Tabs */}
      <div className="glass rounded-xl p-6">
        <div className="flex flex-wrap gap-2 mb-6 border-b border-white/10 pb-4">
          {(['register', 'deposit', 'withdraw', 'transfer', 'credit'] as Tab[]).map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`px-4 py-2 text-sm rounded-lg font-medium capitalize transition-all ${
                tab === t
                  ? 'bg-primary-500 text-white'
                  : 'bg-white/5 text-gray-400 hover:text-white hover:bg-white/10'
              }`}
            >
              {t === 'register' ? 'Register IBAN' : t === 'credit' ? 'Credit' : t.charAt(0).toUpperCase() + t.slice(1)}
            </button>
          ))}
        </div>

        {/* Register IBAN */}
        {tab === 'register' && (
          <div className="space-y-4 max-w-md">
            <h3 className="text-lg font-bold text-white">Register New IBAN</h3>
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Country Code</label>
              <select
                value={regCountry}
                onChange={(e) => setRegCountry(e.target.value as typeof SUPPORTED_COUNTRY_CODES[number])}
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-primary-500"
              >
                {SUPPORTED_COUNTRY_CODES.map((c) => (
                  <option key={c} value={c}>{c}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Bank Code (4 chars)</label>
              <input
                type="text"
                maxLength={4}
                value={regBankCode}
                onChange={(e) => setRegBankCode(e.target.value.toUpperCase())}
                placeholder="SHDB"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono"
              />
            </div>
            {regError && <p className="text-red-400 text-sm">{(regError as Error).message.slice(0, 150)}</p>}
            {regSuccess && <p className="text-green-400 text-sm">✓ IBAN registered on-chain!</p>}
            <button
              onClick={() => registerIBAN(regCountry, regBankCode || 'SHDB')}
              disabled={regPending || regConfirming || !address || notDeployed || !!hasIBAN}
              className="w-full py-4 bg-primary-500 hover:bg-primary-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {regPending ? 'Confirm in wallet…' : regConfirming ? 'Registering…' : hasIBAN ? 'Already Registered' : 'Register IBAN'}
            </button>
          </div>
        )}

        {/* Deposit */}
        {tab === 'deposit' && (
          <div className="space-y-4 max-w-md">
            <h3 className="text-lg font-bold text-white">Deposit ETH to IBAN</h3>
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Amount (ETH)</label>
              <input
                type="number"
                value={depositAmt}
                onChange={(e) => setDepositAmt(e.target.value)}
                placeholder="0.01"
                step="0.001"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
            </div>
            {depError && <p className="text-red-400 text-sm">{(depError as Error).message.slice(0, 150)}</p>}
            {depSuccess && <p className="text-green-400 text-sm">✓ Deposit successful!</p>}
            <button
              onClick={() => deposit(depositAmt)}
              disabled={depPending || depConfirming || !address || !safeParseEther(depositAmt) || notDeployed || !hasIBAN}
              className="w-full py-4 bg-green-500 hover:bg-green-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {depPending ? 'Confirm in wallet…' : depConfirming ? 'Depositing…' : 'Deposit to IBAN'}
            </button>
            {!hasIBAN && address && <p className="text-xs text-amber-400">Register an IBAN first</p>}
          </div>
        )}

        {/* Withdraw */}
        {tab === 'withdraw' && (
          <div className="space-y-4 max-w-md">
            <h3 className="text-lg font-bold text-white">Withdraw from IBAN</h3>
            {account && (
              <p className="text-sm text-gray-400">Available: <span className="text-green-400 font-semibold">{fmt(account.balance)}</span></p>
            )}
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Amount (ETH)</label>
              <input
                type="number"
                value={withdrawAmt}
                onChange={(e) => setWithdrawAmt(e.target.value)}
                placeholder="0.01"
                step="0.001"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
            </div>
            {wdError && <p className="text-red-400 text-sm">{(wdError as Error).message.slice(0, 150)}</p>}
            {wdSuccess && <p className="text-green-400 text-sm">✓ Withdrawal successful!</p>}
            <button
              onClick={() => withdraw(withdrawAmt)}
              disabled={wdPending || wdConfirming || !address || !safeParseEther(withdrawAmt) || notDeployed || !hasIBAN}
              className="w-full py-4 bg-amber-500 hover:bg-amber-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {wdPending ? 'Confirm in wallet…' : wdConfirming ? 'Withdrawing…' : 'Withdraw ETH'}
            </button>
          </div>
        )}

        {/* Transfer */}
        {tab === 'transfer' && (
          <div className="space-y-4 max-w-md">
            <h3 className="text-lg font-bold text-white">Inter-Bank Transfer</h3>
            <p className="text-xs text-gray-400">Transfer fee: 0.009% (9 bps)</p>
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Recipient IBAN Hash (0x…)</label>
              <input
                type="text"
                value={toIBAN}
                onChange={(e) => setToIBAN(e.target.value)}
                placeholder="0x..."
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 font-mono text-sm"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">Amount (ETH)</label>
              <input
                type="number"
                value={transferAmt}
                onChange={(e) => setTransferAmt(e.target.value)}
                placeholder="0.01"
                step="0.001"
                className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
              />
              {safeParseEther(transferAmt) && (
                <div className="mt-2 text-xs text-gray-400 space-y-1">
                  <p>Fee: <span className="text-amber-400">{calculateFee(transferAmt)} ETH</span></p>
                  <p>Recipient receives: <span className="text-green-400">{calculateNet(transferAmt)} ETH</span></p>
                </div>
              )}
            </div>
            {trError && <p className="text-red-400 text-sm">{(trError as Error).message.slice(0, 150)}</p>}
            {trSuccess && <p className="text-green-400 text-sm">✓ Transfer sent!</p>}
            <button
              onClick={() => transfer(toIBAN as `0x${string}`, transferAmt)}
              disabled={trPending || trConfirming || !address || !safeParseEther(transferAmt) || !toIBAN || notDeployed || !hasIBAN}
              className="w-full py-4 bg-blue-500 hover:bg-blue-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {trPending ? 'Confirm in wallet…' : trConfirming ? 'Sending…' : 'Send Transfer'}
            </button>
          </div>
        )}

        {/* Credit */}
        {tab === 'credit' && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-4">
              <h3 className="text-lg font-bold text-white">Use Credit</h3>
              {account && (
                <p className="text-sm text-gray-400">
                  Available: <span className="text-purple-400 font-semibold">{fmt(availableCredit)}</span>
                </p>
              )}
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Amount (ETH)</label>
                <input
                  type="number"
                  value={creditAmt}
                  onChange={(e) => setCreditAmt(e.target.value)}
                  placeholder="0.01"
                  step="0.001"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>
              {crError && <p className="text-red-400 text-sm">{(crError as Error).message.slice(0, 150)}</p>}
              {crSuccess && <p className="text-green-400 text-sm">✓ Credit used!</p>}
              <button
                onClick={() => useCredit(creditAmt)}
                disabled={crPending || crConfirming || !address || !safeParseEther(creditAmt) || notDeployed || !hasIBAN}
                className="w-full py-4 bg-purple-500 hover:bg-purple-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {crPending ? 'Confirm in wallet…' : crConfirming ? 'Processing…' : 'Use Credit'}
              </button>
            </div>

            <div className="space-y-4">
              <h3 className="text-lg font-bold text-white">Repay Credit</h3>
              {account && (
                <p className="text-sm text-gray-400">
                  Owed: <span className="text-amber-400 font-semibold">{fmt(account.creditUsed)}</span>
                </p>
              )}
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Amount (ETH)</label>
                <input
                  type="number"
                  value={repayAmt}
                  onChange={(e) => setRepayAmt(e.target.value)}
                  placeholder="0.01"
                  step="0.001"
                  className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500"
                />
              </div>
              {rpError && <p className="text-red-400 text-sm">{(rpError as Error).message.slice(0, 150)}</p>}
              {rpSuccess && <p className="text-green-400 text-sm">✓ Credit repaid!</p>}
              <button
                onClick={() => repayCredit(repayAmt)}
                disabled={rpPending || rpConfirming || !address || !safeParseEther(repayAmt) || notDeployed || !hasIBAN}
                className="w-full py-4 bg-red-500 hover:bg-red-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {rpPending ? 'Confirm in wallet…' : rpConfirming ? 'Repaying…' : 'Repay Credit'}
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Registered Countries on-chain */}
      <div className="glass rounded-xl p-6">
        <h3 className="text-xl font-bold text-white mb-4">Active Countries On-Chain</h3>
        {countries.length === 0 ? (
          <div className="p-8 text-center text-gray-500">
            <p className="text-4xl mb-2">🌐</p>
            <p className="font-medium">No countries registered yet</p>
            <p className="text-xs mt-1">Countries are added when IBANs are first registered</p>
          </div>
        ) : (
          <div className="flex flex-wrap gap-2">
            {countries.map((c) => (
              <span key={c} className="px-3 py-1 bg-blue-500/20 border border-blue-500/30 rounded-full text-blue-300 text-sm font-semibold">
                {c}
              </span>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
