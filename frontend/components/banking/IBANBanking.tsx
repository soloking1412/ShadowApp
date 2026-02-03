'use client';

import React, { useState, useMemo } from 'react';
import { useAccount } from 'wagmi';
import { formatEther, parseEther } from 'viem';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  useMyIBANAccount,
  useRegisterIBAN,
  useDepositToIBAN,
  useWithdrawFromIBAN,
  useInterBankTransfer,
  useUseCredit,
  useRepayCredit,
  SUPPORTED_COUNTRY_CODES,
  formatIBANDisplay,
  calculateAvailableCredit,
  type CountryCode,
} from '@/hooks/contracts/useShadowBank';
import {
  Building2,
  CreditCard,
  ArrowUpRight,
  ArrowDownLeft,
  RefreshCw,
  Check,
  AlertCircle,
  Copy,
  Wallet,
  Percent,
} from 'lucide-react';

interface TabProps {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}

function Tab({ active, onClick, children }: TabProps) {
  return (
    <button
      onClick={onClick}
      className={`px-4 py-2 text-sm font-medium rounded-lg transition-all ${
        active
          ? 'bg-blue-500/20 text-blue-400 border border-blue-500/30'
          : 'text-slate-400 hover:text-white hover:bg-slate-700/50'
      }`}
    >
      {children}
    </button>
  );
}

export function IBANBanking() {
  const { address, isConnected } = useAccount();
  const { ibanHash, account, hasIBAN, isLoading } = useMyIBANAccount();

  // Tab state
  const [activeTab, setActiveTab] = useState<'overview' | 'transfer' | 'credit'>('overview');

  // Registration form state
  const [selectedCountry, setSelectedCountry] = useState<CountryCode>('GB');
  const [bankCode, setBankCode] = useState('SHDW');

  // Transfer form state
  const [recipientIBAN, setRecipientIBAN] = useState('');
  const [transferAmount, setTransferAmount] = useState('');

  // Deposit/Withdraw state
  const [depositAmount, setDepositAmount] = useState('');
  const [withdrawAmount, setWithdrawAmount] = useState('');

  // Credit state
  const [creditAmount, setCreditAmount] = useState('');
  const [repayAmount, setRepayAmount] = useState('');

  // Hooks
  const { registerIBAN, isPending: isRegistering, isSuccess: registerSuccess } = useRegisterIBAN();
  const { deposit, isPending: isDepositing, isSuccess: depositSuccess } = useDepositToIBAN();
  const { withdraw, isPending: isWithdrawing, isSuccess: withdrawSuccess } = useWithdrawFromIBAN();
  const { transfer, calculateFee, calculateNet, isPending: isTransferring, isSuccess: transferSuccess } = useInterBankTransfer();
  const { useCredit, isPending: isUsingCredit, isSuccess: useCreditSuccess } = useUseCredit();
  const { repayCredit, isPending: isRepaying, isSuccess: repaySuccess } = useRepayCredit();

  // Computed values
  const formattedIBAN = useMemo(() => {
    if (!ibanHash || !account) return null;
    return formatIBANDisplay(ibanHash, account.countryCode, account.bankCode);
  }, [ibanHash, account]);

  const availableCredit = useMemo(() => {
    return calculateAvailableCredit(account);
  }, [account]);

  const transferFee = useMemo(() => {
    if (!transferAmount) return '0';
    return calculateFee(transferAmount);
  }, [transferAmount, calculateFee]);

  const transferNet = useMemo(() => {
    if (!transferAmount) return '0';
    return calculateNet(transferAmount);
  }, [transferAmount, calculateNet]);

  // Copy IBAN to clipboard
  const copyIBAN = () => {
    if (formattedIBAN) {
      navigator.clipboard.writeText(formattedIBAN);
    }
  };

  if (!isConnected) {
    return (
      <Card className="bg-slate-800/50 border-slate-700">
        <CardContent className="flex flex-col items-center justify-center py-12">
          <Wallet className="w-12 h-12 text-slate-500 mb-4" />
          <p className="text-slate-400">Connect your wallet to access IBAN Banking</p>
        </CardContent>
      </Card>
    );
  }

  if (isLoading) {
    return (
      <Card className="bg-slate-800/50 border-slate-700">
        <CardContent className="flex items-center justify-center py-12">
          <RefreshCw className="w-8 h-8 text-blue-400 animate-spin" />
        </CardContent>
      </Card>
    );
  }

  // Registration view if no IBAN
  if (!hasIBAN) {
    return (
      <Card className="bg-slate-800/50 border-slate-700">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Building2 className="w-5 h-5 text-blue-400" />
            Register IBAN Account
          </CardTitle>
          <CardDescription>
            Create your Shadow Banking IBAN for international transfers
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <label className="text-sm text-slate-400 mb-2 block">Country</label>
            <select
              value={selectedCountry}
              onChange={(e) => setSelectedCountry(e.target.value as CountryCode)}
              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-4 py-2 text-white focus:border-blue-500 focus:outline-none"
            >
              {SUPPORTED_COUNTRY_CODES.map((code) => (
                <option key={code} value={code}>
                  {code} - {code === 'OZ' ? 'OZF Federation' : code}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="text-sm text-slate-400 mb-2 block">Bank Code (4 characters)</label>
            <Input
              value={bankCode}
              onChange={(e) => setBankCode(e.target.value.toUpperCase().slice(0, 4))}
              placeholder="SHDW"
              className="bg-slate-900 border-slate-700"
              maxLength={4}
            />
          </div>

          <div className="bg-slate-900/50 rounded-lg p-4 border border-slate-700">
            <p className="text-sm text-slate-400">Preview IBAN Format:</p>
            <p className="text-lg font-mono text-white mt-1">
              {selectedCountry}82 {bankCode.padEnd(4, '0')} XXXX
            </p>
          </div>

          <Button
            onClick={() => registerIBAN(selectedCountry, bankCode)}
            disabled={isRegistering || bankCode.length < 4}
            className="w-full bg-blue-600 hover:bg-blue-700"
          >
            {isRegistering ? (
              <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
            ) : (
              <CreditCard className="w-4 h-4 mr-2" />
            )}
            Register IBAN
          </Button>

          {registerSuccess && (
            <div className="flex items-center gap-2 text-green-400 text-sm">
              <Check className="w-4 h-4" />
              IBAN registered successfully!
            </div>
          )}
        </CardContent>
      </Card>
    );
  }

  // Main dashboard view
  return (
    <div className="space-y-4">
      {/* Account Overview Card */}
      <Card className="bg-slate-800/50 border-slate-700">
        <CardHeader className="pb-2">
          <div className="flex items-center justify-between">
            <div>
              <CardTitle className="flex items-center gap-2">
                <CreditCard className="w-5 h-5 text-blue-400" />
                Your IBAN Account
              </CardTitle>
              <CardDescription>Shadow Banking International Account</CardDescription>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-xs px-2 py-1 bg-green-500/20 text-green-400 rounded-full">
                Active
              </span>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          {/* IBAN Display */}
          <div className="bg-slate-900/50 rounded-lg p-4 border border-slate-700 mb-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs text-slate-400 mb-1">IBAN</p>
                <p className="text-xl font-mono text-white">{formattedIBAN}</p>
              </div>
              <Button
                variant="ghost"
                size="sm"
                onClick={copyIBAN}
                className="text-slate-400 hover:text-white"
              >
                <Copy className="w-4 h-4" />
              </Button>
            </div>
          </div>

          {/* Balance Grid */}
          <div className="grid grid-cols-3 gap-4">
            <div className="bg-slate-900/50 rounded-lg p-3 border border-slate-700">
              <p className="text-xs text-slate-400">Balance</p>
              <p className="text-lg font-semibold text-white">
                {account ? formatEther(account.balance) : '0'} ETH
              </p>
            </div>
            <div className="bg-slate-900/50 rounded-lg p-3 border border-slate-700">
              <p className="text-xs text-slate-400">Credit Line</p>
              <p className="text-lg font-semibold text-green-400">
                {account ? formatEther(account.creditLine) : '0'} ETH
              </p>
            </div>
            <div className="bg-slate-900/50 rounded-lg p-3 border border-slate-700">
              <p className="text-xs text-slate-400">Available Credit</p>
              <p className="text-lg font-semibold text-blue-400">
                {formatEther(availableCredit)} ETH
              </p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Tab Navigation */}
      <div className="flex gap-2">
        <Tab active={activeTab === 'overview'} onClick={() => setActiveTab('overview')}>
          Deposit/Withdraw
        </Tab>
        <Tab active={activeTab === 'transfer'} onClick={() => setActiveTab('transfer')}>
          Transfer
        </Tab>
        <Tab active={activeTab === 'credit'} onClick={() => setActiveTab('credit')}>
          Credit
        </Tab>
      </div>

      {/* Tab Content */}
      {activeTab === 'overview' && (
        <div className="grid grid-cols-2 gap-4">
          {/* Deposit */}
          <Card className="bg-slate-800/50 border-slate-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm flex items-center gap-2">
                <ArrowDownLeft className="w-4 h-4 text-green-400" />
                Deposit
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <Input
                type="number"
                value={depositAmount}
                onChange={(e) => setDepositAmount(e.target.value)}
                placeholder="Amount in ETH"
                className="bg-slate-900 border-slate-700"
              />
              <Button
                onClick={() => deposit(depositAmount)}
                disabled={isDepositing || !depositAmount}
                className="w-full bg-green-600 hover:bg-green-700"
              >
                {isDepositing ? <RefreshCw className="w-4 h-4 animate-spin" /> : 'Deposit'}
              </Button>
              {depositSuccess && (
                <p className="text-green-400 text-sm flex items-center gap-1">
                  <Check className="w-4 h-4" /> Deposited!
                </p>
              )}
            </CardContent>
          </Card>

          {/* Withdraw */}
          <Card className="bg-slate-800/50 border-slate-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm flex items-center gap-2">
                <ArrowUpRight className="w-4 h-4 text-orange-400" />
                Withdraw
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <Input
                type="number"
                value={withdrawAmount}
                onChange={(e) => setWithdrawAmount(e.target.value)}
                placeholder="Amount in ETH"
                className="bg-slate-900 border-slate-700"
              />
              <Button
                onClick={() => withdraw(withdrawAmount)}
                disabled={isWithdrawing || !withdrawAmount}
                className="w-full bg-orange-600 hover:bg-orange-700"
              >
                {isWithdrawing ? <RefreshCw className="w-4 h-4 animate-spin" /> : 'Withdraw'}
              </Button>
              {withdrawSuccess && (
                <p className="text-green-400 text-sm flex items-center gap-1">
                  <Check className="w-4 h-4" /> Withdrawn!
                </p>
              )}
            </CardContent>
          </Card>
        </div>
      )}

      {activeTab === 'transfer' && (
        <Card className="bg-slate-800/50 border-slate-700">
          <CardHeader>
            <CardTitle className="text-sm flex items-center gap-2">
              <ArrowUpRight className="w-4 h-4 text-blue-400" />
              Inter-Bank Transfer
            </CardTitle>
            <CardDescription>
              Transfer to another IBAN account (0.009% fee)
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <label className="text-sm text-slate-400 mb-2 block">Recipient IBAN Hash</label>
              <Input
                value={recipientIBAN}
                onChange={(e) => setRecipientIBAN(e.target.value)}
                placeholder="0x..."
                className="bg-slate-900 border-slate-700 font-mono"
              />
            </div>

            <div>
              <label className="text-sm text-slate-400 mb-2 block">Amount</label>
              <Input
                type="number"
                value={transferAmount}
                onChange={(e) => setTransferAmount(e.target.value)}
                placeholder="Amount in ETH"
                className="bg-slate-900 border-slate-700"
              />
            </div>

            {transferAmount && (
              <div className="bg-slate-900/50 rounded-lg p-3 border border-slate-700 space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-slate-400">Transfer Fee (0.009%)</span>
                  <span className="text-orange-400">{transferFee} ETH</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-slate-400">Recipient Receives</span>
                  <span className="text-green-400">{transferNet} ETH</span>
                </div>
              </div>
            )}

            <Button
              onClick={() => transfer(recipientIBAN as `0x${string}`, transferAmount)}
              disabled={isTransferring || !recipientIBAN || !transferAmount}
              className="w-full bg-blue-600 hover:bg-blue-700"
            >
              {isTransferring ? (
                <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
              ) : (
                <ArrowUpRight className="w-4 h-4 mr-2" />
              )}
              Send Transfer
            </Button>

            {transferSuccess && (
              <div className="flex items-center gap-2 text-green-400 text-sm">
                <Check className="w-4 h-4" />
                Transfer completed successfully!
              </div>
            )}
          </CardContent>
        </Card>
      )}

      {activeTab === 'credit' && (
        <div className="grid grid-cols-2 gap-4">
          {/* Use Credit */}
          <Card className="bg-slate-800/50 border-slate-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm flex items-center gap-2">
                <Percent className="w-4 h-4 text-purple-400" />
                Use Credit
              </CardTitle>
              <CardDescription>
                Available: {formatEther(availableCredit)} ETH
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              <Input
                type="number"
                value={creditAmount}
                onChange={(e) => setCreditAmount(e.target.value)}
                placeholder="Amount in ETH"
                className="bg-slate-900 border-slate-700"
              />
              <Button
                onClick={() => useCredit(creditAmount)}
                disabled={isUsingCredit || !creditAmount || parseEther(creditAmount || '0') > availableCredit}
                className="w-full bg-purple-600 hover:bg-purple-700"
              >
                {isUsingCredit ? <RefreshCw className="w-4 h-4 animate-spin" /> : 'Use Credit'}
              </Button>
              {useCreditSuccess && (
                <p className="text-green-400 text-sm flex items-center gap-1">
                  <Check className="w-4 h-4" /> Credit disbursed!
                </p>
              )}
            </CardContent>
          </Card>

          {/* Repay Credit */}
          <Card className="bg-slate-800/50 border-slate-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm flex items-center gap-2">
                <ArrowDownLeft className="w-4 h-4 text-green-400" />
                Repay Credit
              </CardTitle>
              <CardDescription>
                Outstanding: {account ? formatEther(account.creditUsed) : '0'} ETH
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              <Input
                type="number"
                value={repayAmount}
                onChange={(e) => setRepayAmount(e.target.value)}
                placeholder="Amount in ETH"
                className="bg-slate-900 border-slate-700"
              />
              <Button
                onClick={() => repayCredit(repayAmount)}
                disabled={isRepaying || !repayAmount}
                className="w-full bg-green-600 hover:bg-green-700"
              >
                {isRepaying ? <RefreshCw className="w-4 h-4 animate-spin" /> : 'Repay'}
              </Button>
              {repaySuccess && (
                <p className="text-green-400 text-sm flex items-center gap-1">
                  <Check className="w-4 h-4" /> Repaid!
                </p>
              )}
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}

export default IBANBanking;
