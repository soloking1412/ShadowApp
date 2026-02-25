'use client';
import React, { useState, useEffect } from 'react';
import { useAccount } from 'wagmi';
import { formatEther } from 'viem';
import {
  useOrderCounter, useTotalOrdersProcessed, useTotalVolumeTraded,
  useComputeGLTE, useLatestSignal, useGLTEParams,
  useHFTGetOrder, useGetTraderOrders, useGetTraderStats,
  useHFTPlaceOrder, useHFTCancelOrder, useEmitGLTESignal,
} from '@/hooks/contracts/useHFTEngine';

const ORDER_TYPES = ['Market', 'Limit', 'StopLoss', 'GLTE'];
const ORDER_STATUS = ['Open', 'Filled', 'PartialFill', 'Cancelled', 'Expired'];
const DIRECTIONS = ['Buy', 'Sell'];
const STATUS_COLORS: Record<number, string> = {
  0: 'bg-blue-500/20 text-blue-300',
  1: 'bg-green-500/20 text-green-300',
  2: 'bg-yellow-500/20 text-yellow-300',
  3: 'bg-gray-500/20 text-gray-400',
  4: 'bg-red-500/20 text-red-300',
};

export default function HFTEngineComponent() {
  const { address, isConnected } = useAccount();
  const [tab, setTab] = useState<'glte' | 'orders' | 'place' | 'lookup'>('glte');

  // Place order form
  const [orderType, setOrderType] = useState(0);
  const [direction, setDirection] = useState(0);
  const [baseCcy, setBaseCcy] = useState('USD');
  const [quoteCcy, setQuoteCcy] = useState('EUR');
  const [quantity, setQuantity] = useState('');
  const [limitPrice, setLimitPrice] = useState('0');
  const [stopPrice, setStopPrice] = useState('0');
  const [expirySeconds, setExpirySeconds] = useState('86400');
  const [useGLTE, setUseGLTE] = useState(false);

  // Lookup
  const [lookupOrderId, setLookupOrderId] = useState('');
  const [cancelOrderId, setCancelOrderId] = useState('');

  const { data: orderCount } = useOrderCounter();
  const { data: processedCount } = useTotalOrdersProcessed();
  const { data: volumeTraded } = useTotalVolumeTraded();
  const { data: glteResult } = useComputeGLTE();
  const { data: latestSignal } = useLatestSignal();
  const { data: glteParams } = useGLTEParams();
  const { data: lookupOrder, refetch: refetchOrder } = useHFTGetOrder(lookupOrderId ? BigInt(lookupOrderId) : 0n);
  const { data: traderOrders } = useGetTraderOrders(address);
  const { data: traderStats } = useGetTraderStats(address);

  const { placeOrder, isPending: placing, isSuccess: placed, error: placeErr } = useHFTPlaceOrder();
  const { cancelOrder, isPending: cancelling, error: cancelErr } = useHFTCancelOrder();
  const { emitGLTESignal, isPending: emitting, isSuccess: emitted, error: emitErr } = useEmitGLTESignal();

  const [txError,   setTxError]   = useState<string | null>(null);
  const [txSuccess, setTxSuccess] = useState<string | null>(null);

  useEffect(() => {
    const err = placeErr ?? cancelErr ?? emitErr;
    if (!err) return;
    const msg = (err as { shortMessage?: string })?.shortMessage ?? err.message ?? 'Transaction failed';
    setTxError(msg.length > 120 ? msg.slice(0, 120) + '…' : msg);
    const t = setTimeout(() => setTxError(null), 7000);
    return () => clearTimeout(t);
  }, [placeErr, cancelErr, emitErr]);

  useEffect(() => {
    if (!placed && !emitted) return;
    setTxSuccess(placed ? 'Order placed successfully' : 'GLTE signal emitted');
    const t = setTimeout(() => setTxSuccess(null), 5000);
    return () => clearTimeout(t);
  }, [placed, emitted]);

  const handlePlace = () => {
    if (!quantity) return;
    placeOrder(
      orderType, direction, baseCcy, quoteCcy,
      BigInt(Math.floor(parseFloat(quantity) * 1e18)),
      BigInt(Math.floor(parseFloat(limitPrice) * 1e18)),
      BigInt(Math.floor(parseFloat(stopPrice) * 1e18)),
      BigInt(expirySeconds),
      useGLTE,
    );
  };

  const glteValues = glteResult as [bigint, bigint] | undefined;
  const signal = latestSignal as {
    timestamp: bigint; L_in: bigint; L_out: bigint; bullish: boolean; strength: bigint;
  } | undefined;
  const params = glteParams as {
    W_t: bigint; chi_in: bigint; r_LIBOR: bigint; r_BSE_Delhi: bigint; r_Bursa_Malaysia: bigint;
    chi_out: bigint; OICD: bigint; B_Bolsaro: bigint; B_Tirana: bigint;
    F_Tadawul: bigint; sigma_VIX: bigint; derivativeSpread: bigint;
    gamma: bigint; yuan_OICD_peg: bigint; updatedAt: bigint;
  } | undefined;
  const stats = traderStats as {
    totalOrders: bigint; filledOrders: bigint; totalVolume: bigint; pnl: bigint; lastActivity: bigint;
  } | undefined;

  const TABS = [
    { id: 'glte', label: 'GLTE Signal' },
    { id: 'orders', label: 'My Orders' },
    { id: 'place', label: 'Place Order' },
    { id: 'lookup', label: 'Order Lookup' },
  ] as const;

  return (
    <div className="space-y-6">
      {txError && (
        <div className="flex items-start gap-3 px-4 py-3 bg-red-900/40 border border-red-500/40 rounded-xl text-sm">
          <span className="text-red-400 shrink-0 mt-0.5">✕</span>
          <div className="flex-1"><p className="font-semibold text-red-300">Transaction failed</p><p className="text-red-400/80 text-xs mt-0.5">{txError}</p></div>
          <button onClick={() => setTxError(null)} className="text-red-500 hover:text-red-300 text-xs shrink-0">dismiss</button>
        </div>
      )}
      {txSuccess && (
        <div className="flex items-center gap-2 px-4 py-3 bg-green-900/30 border border-green-500/30 rounded-xl text-sm">
          <span className="text-green-400">✓</span><p className="text-green-300 font-semibold">{txSuccess}</p>
        </div>
      )}
      <div>
        <h2 className="text-2xl font-bold text-white">HFT Engine</h2>
        <p className="text-gray-400 mt-1">GLTE-based sovereign high-frequency trading engine</p>
      </div>

      <div className="flex gap-2 border-b border-white/10 pb-2">
        {TABS.map(t => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={`px-4 py-2 rounded-t text-sm font-medium transition-colors ${
              tab === t.id ? 'bg-cyan-600 text-white' : 'text-gray-400 hover:text-white'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* GLTE Signal */}
      {tab === 'glte' && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
            {[
              { label: 'Total Orders', value: orderCount?.toString() ?? '—' },
              { label: 'Orders Processed', value: processedCount?.toString() ?? '—' },
              { label: 'Volume Traded', value: volumeTraded?.toString() ?? '—' },
            ].map(s => (
              <div key={s.label} className="bg-white/5 rounded-xl p-4 border border-white/10">
                <div className="text-xs text-gray-400">{s.label}</div>
                <div className="text-xl font-bold text-white mt-1">{s.value}</div>
              </div>
            ))}
          </div>

          {/* GLTE Formula Display */}
          <div className="bg-white/5 rounded-xl p-5 border border-white/10 space-y-4">
            <h3 className="font-semibold text-cyan-400">Global Liquidity Transformation Equation (GLTE)</h3>
            <div className="bg-black/30 rounded-lg p-4 font-mono text-xs text-gray-200 space-y-2 leading-relaxed">
              <div className="text-cyan-300 text-xs font-bold mb-1">L_in  (Inflow):</div>
              <div>= (W_t × χ_in[48,678.46%] × r_LIBOR) + r_BSE_Delhi + r_Bursa_Malaysia</div>
              <div className="text-cyan-300 text-xs font-bold mt-2 mb-1">L_out (Outflow):</div>
              <div>= (W_t / E[L_in]) × χ_out[75,834.34%] × (OICD/197) × B_Bolsaro</div>
              <div className="pl-4">+ [B_Tirana + (F_Tadawul × σ_VIX(Oil+deriv_spread_0.05–0.25bp))] × γ × yuan_peg</div>
              <div className="text-yellow-400/70 text-xs pt-1">{ '{ 1 Yuan = 1 OICD }  Sources: BSE Delhi · Bursa Malaysia · Brazil Bolsaro · Tirana · Tawadul' }</div>
            </div>
            {glteValues && (
              <div className="grid grid-cols-2 gap-4">
                <div className="bg-white/5 rounded-lg p-3">
                  <div className="text-xs text-gray-400">L_in (Expected Inflow)</div>
                  <div className="text-lg font-bold text-white">{parseFloat(formatEther(glteValues[0])).toFixed(4)}</div>
                </div>
                <div className="bg-white/5 rounded-lg p-3">
                  <div className="text-xs text-gray-400">L_out (Transformed Outflow)</div>
                  <div className="text-lg font-bold text-white">{parseFloat(formatEther(glteValues[1])).toFixed(4)}</div>
                </div>
              </div>
            )}
            {signal && signal.timestamp > 0n && (
              <div className={`rounded-lg p-4 border ${signal.bullish ? 'border-green-500/30 bg-green-500/10' : 'border-red-500/30 bg-red-500/10'}`}>
                <div className="flex items-center justify-between mb-2">
                  <span className="font-semibold text-white">Latest Signal</span>
                  <span className={`text-sm font-bold ${signal.bullish ? 'text-green-400' : 'text-red-400'}`}>
                    {signal.bullish ? '▲ BULLISH' : '▼ BEARISH'} — {signal.strength.toString()}% strength
                  </span>
                </div>
                <div className="grid grid-cols-3 gap-2 text-sm">
                  <div><span className="text-gray-400">L_in:</span> <span className="text-white">{parseFloat(formatEther(signal.L_in)).toFixed(4)}</span></div>
                  <div><span className="text-gray-400">L_out:</span> <span className="text-white">{parseFloat(formatEther(signal.L_out)).toFixed(4)}</span></div>
                  <div><span className="text-gray-400">Time:</span> <span className="text-white">{new Date(Number(signal.timestamp) * 1000).toLocaleTimeString()}</span></div>
                </div>
              </div>
            )}
            <button
              onClick={() => emitGLTESignal()}
              disabled={emitting || !isConnected}
              className="bg-cyan-600 hover:bg-cyan-700 disabled:opacity-50 text-white font-medium px-5 py-2 rounded"
            >
              {emitting ? 'Emitting…' : emitted ? 'Signal Emitted!' : 'Emit GLTE Signal (owner/executor)'}
            </button>
          </div>

          {/* GLTE Parameters */}
          {params && (
            <div className="bg-white/5 rounded-xl p-5 border border-white/10 space-y-4">
              <h3 className="font-semibold text-white">GLTE Parameters</h3>
              <div>
                <div className="text-xs text-cyan-400 font-semibold uppercase tracking-wider mb-2">L_in Inputs</div>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm">
                  <div><span className="text-gray-400 block text-xs">W_t (Capital)</span><span className="text-white">{parseFloat(formatEther(params.W_t)).toLocaleString()}</span></div>
                  <div><span className="text-gray-400 block text-xs">χ_in (48,678.46%)</span><span className="text-white">{parseFloat(formatEther(params.chi_in)).toFixed(2)}×</span></div>
                  <div><span className="text-gray-400 block text-xs">r_LIBOR</span><span className="text-white">{(parseFloat(formatEther(params.r_LIBOR)) * 100).toFixed(2)}%</span></div>
                  <div><span className="text-gray-400 block text-xs">r_BSE_Delhi</span><span className="text-white">{parseFloat(formatEther(params.r_BSE_Delhi)).toLocaleString()}</span></div>
                  <div><span className="text-gray-400 block text-xs">r_Bursa_Malaysia</span><span className="text-white">{parseFloat(formatEther(params.r_Bursa_Malaysia)).toLocaleString()}</span></div>
                </div>
              </div>
              <div>
                <div className="text-xs text-cyan-400 font-semibold uppercase tracking-wider mb-2">L_out Inputs</div>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm">
                  <div><span className="text-gray-400 block text-xs">χ_out (75,834.34%)</span><span className="text-white">{parseFloat(formatEther(params.chi_out)).toFixed(2)}×</span></div>
                  <div><span className="text-gray-400 block text-xs">OICD Basket /197</span><span className="text-white">{parseFloat(formatEther(params.OICD)).toFixed(0)}</span></div>
                  <div><span className="text-gray-400 block text-xs">B_Bolsaro (Brazil)</span><span className="text-white">{parseFloat(formatEther(params.B_Bolsaro)).toFixed(3)}×</span></div>
                  <div><span className="text-gray-400 block text-xs">B_Tirana (Bonds)</span><span className="text-white">{parseFloat(formatEther(params.B_Tirana)).toLocaleString()}</span></div>
                  <div><span className="text-gray-400 block text-xs">F_Tadawul (Float)</span><span className="text-white">{parseFloat(formatEther(params.F_Tadawul)).toFixed(3)}×</span></div>
                  <div><span className="text-gray-400 block text-xs">σ_VIX(Oil)</span><span className="text-white">{(parseFloat(formatEther(params.sigma_VIX)) * 100).toFixed(1)}%</span></div>
                  <div><span className="text-gray-400 block text-xs">Deriv. Spread</span><span className="text-white">{(parseFloat(formatEther(params.derivativeSpread)) * 10000).toFixed(4)} bp</span></div>
                  <div><span className="text-gray-400 block text-xs">γ (Yuan-OICD)</span><span className="text-white">{parseFloat(formatEther(params.gamma)).toFixed(4)}</span></div>
                  <div><span className="text-gray-400 block text-xs">Yuan/OICD Peg</span><span className="text-white">{parseFloat(formatEther(params.yuan_OICD_peg)).toFixed(4)} ¥=OICD</span></div>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* My Orders */}
      {tab === 'orders' && (
        <div className="space-y-4">
          {stats && (
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              {[
                { label: 'Total Orders', value: stats.totalOrders.toString() },
                { label: 'Filled Orders', value: stats.filledOrders.toString() },
                { label: 'Total Volume', value: parseFloat(formatEther(stats.totalVolume)).toFixed(4) },
              ].map(s => (
                <div key={s.label} className="bg-white/5 rounded-xl p-4 border border-white/10">
                  <div className="text-xs text-gray-400">{s.label}</div>
                  <div className="text-xl font-bold text-white mt-1">{s.value}</div>
                </div>
              ))}
            </div>
          )}
          <div className="bg-white/5 rounded-xl p-4 border border-white/10">
            <h3 className="font-semibold text-white mb-2">My Order IDs</h3>
            {!isConnected && <p className="text-gray-400 text-sm">Connect wallet</p>}
            {isConnected && (!traderOrders || (traderOrders as bigint[]).length === 0) && (
              <p className="text-gray-400 text-sm">No orders placed yet</p>
            )}
            {isConnected && !!traderOrders && (traderOrders as bigint[]).length > 0 && (
              <div className="flex flex-wrap gap-2">
                {(traderOrders as bigint[]).map(id => (
                  <span key={id.toString()} className="bg-cyan-500/20 text-cyan-300 text-xs px-2 py-1 rounded">#{id.toString()}</span>
                ))}
              </div>
            )}
          </div>
          <div className="flex gap-3 max-w-md">
            <input
              className="flex-1 bg-white/10 text-white rounded px-3 py-2 border border-white/20 text-sm"
              placeholder="Order ID to cancel"
              value={cancelOrderId}
              onChange={e => setCancelOrderId(e.target.value)}
              type="number"
            />
            <button
              onClick={() => cancelOrderId && cancelOrder(BigInt(cancelOrderId))}
              disabled={cancelling || !isConnected || !cancelOrderId}
              className="bg-red-600 hover:bg-red-700 disabled:opacity-50 text-white px-4 py-2 rounded text-sm"
            >
              {cancelling ? 'Cancelling…' : 'Cancel Order'}
            </button>
          </div>
        </div>
      )}

      {/* Place Order */}
      {tab === 'place' && (
        <div className="bg-white/5 rounded-xl p-5 border border-white/10 max-w-lg space-y-4">
          <h3 className="font-semibold text-white">Place HFT Order</h3>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-xs text-gray-400 block mb-1">Order Type</label>
              <select className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" value={orderType} onChange={e => setOrderType(Number(e.target.value))}>
                {ORDER_TYPES.map((t, i) => <option key={i} value={i}>{t}</option>)}
              </select>
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Direction</label>
              <select className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" value={direction} onChange={e => setDirection(Number(e.target.value))}>
                {DIRECTIONS.map((d, i) => <option key={i} value={i}>{d}</option>)}
              </select>
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Base Currency</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" value={baseCcy} onChange={e => setBaseCcy(e.target.value.toUpperCase())} placeholder="USD" maxLength={6} />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Quote Currency</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" value={quoteCcy} onChange={e => setQuoteCcy(e.target.value.toUpperCase())} placeholder="EUR" maxLength={6} />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Quantity (1e18 units)</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" type="number" value={quantity} onChange={e => setQuantity(e.target.value)} placeholder="100" />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Limit Price (0 for market)</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" type="number" value={limitPrice} onChange={e => setLimitPrice(e.target.value)} placeholder="0" />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Stop Price (stop-loss)</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" type="number" value={stopPrice} onChange={e => setStopPrice(e.target.value)} placeholder="0" />
            </div>
            <div>
              <label className="text-xs text-gray-400 block mb-1">Expiry (seconds)</label>
              <input className="w-full bg-white/10 text-white rounded px-3 py-2 border border-white/20" type="number" value={expirySeconds} onChange={e => setExpirySeconds(e.target.value)} placeholder="86400" />
            </div>
          </div>
          <label className="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={useGLTE}
              onChange={e => setUseGLTE(e.target.checked)}
              className="w-4 h-4 rounded"
            />
            <span className="text-sm text-gray-200">Use GLTE signal trigger</span>
          </label>
          {useGLTE && glteValues && (
            <div className="text-xs text-cyan-300 bg-cyan-500/10 rounded px-3 py-2">
              Current GLTE: L_in={parseFloat(formatEther(glteValues[0])).toFixed(4)} → L_out={parseFloat(formatEther(glteValues[1])).toFixed(4)} ({glteValues[1] > glteValues[0] ? '▲ Bullish' : '▼ Bearish'})
            </div>
          )}
          <button
            onClick={handlePlace}
            disabled={placing || !isConnected || !quantity}
            className="w-full bg-cyan-600 hover:bg-cyan-700 disabled:opacity-50 text-white font-medium py-2 rounded"
          >
            {placing ? 'Signing…' : placed ? 'Order Placed!' : 'Place Order'}
          </button>
          {!isConnected && <p className="text-xs text-yellow-400">Connect wallet to place orders</p>}
        </div>
      )}

      {/* Order Lookup */}
      {tab === 'lookup' && (
        <div className="space-y-4">
          <div className="flex gap-3 max-w-md">
            <input
              className="flex-1 bg-white/10 text-white rounded px-3 py-2 border border-white/20"
              placeholder="Order ID"
              value={lookupOrderId}
              onChange={e => setLookupOrderId(e.target.value)}
              type="number"
            />
            <button onClick={() => refetchOrder()} className="bg-cyan-600 hover:bg-cyan-700 text-white px-4 py-2 rounded">Lookup</button>
          </div>

          {!!lookupOrder && (lookupOrder as { orderId: bigint }).orderId > 0n && ((): React.ReactElement | null => {
            const o = lookupOrder as {
              orderId: bigint; orderType: number; status: number; direction: number;
              trader: string; baseCurrency: string; quoteCurrency: string;
              quantity: bigint; limitPrice: bigint; filledQuantity: bigint;
              avgFillPrice: bigint; useGLTE: boolean;
            };
            return (
              <div className="bg-white/5 rounded-xl p-5 border border-white/10 space-y-3 max-w-lg">
                <div className="flex items-center justify-between flex-wrap gap-2">
                  <span className="font-semibold text-white">Order #{o.orderId.toString()}</span>
                  <div className="flex gap-2">
                    <span className="text-xs px-2 py-0.5 rounded-full bg-cyan-500/20 text-cyan-300">{ORDER_TYPES[o.orderType]}</span>
                    <span className={`text-xs px-2 py-0.5 rounded-full ${DIRECTIONS[o.direction] === 'Buy' ? 'bg-green-500/20 text-green-300' : 'bg-red-500/20 text-red-300'}`}>{DIRECTIONS[o.direction]}</span>
                    <span className={`text-xs px-2 py-0.5 rounded-full ${STATUS_COLORS[o.status] ?? ''}`}>{ORDER_STATUS[o.status]}</span>
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-2 text-sm">
                  <div><span className="text-gray-400">Pair:</span> <span className="text-white">{o.baseCurrency}/{o.quoteCurrency}</span></div>
                  <div><span className="text-gray-400">Qty:</span> <span className="text-white">{formatEther(o.quantity)}</span></div>
                  <div><span className="text-gray-400">Filled:</span> <span className="text-white">{formatEther(o.filledQuantity)}</span></div>
                  <div><span className="text-gray-400">Avg Fill:</span> <span className="text-white">{formatEther(o.avgFillPrice)}</span></div>
                  <div><span className="text-gray-400">GLTE:</span> <span className="text-white">{o.useGLTE ? 'Yes' : 'No'}</span></div>
                  <div className="col-span-2"><span className="text-gray-400">Trader:</span> <span className="text-white font-mono text-xs">{o.trader}</span></div>
                </div>
              </div>
            );
          })()}
        </div>
      )}
    </div>
  );
}
