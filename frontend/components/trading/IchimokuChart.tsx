'use client';

import { useEffect, useRef, useState } from 'react';
import { createChart, IChartApi, ISeriesApi, CandlestickData, Time, LineStyle } from 'lightweight-charts';

interface IchimokuChartProps {
  currencyPair: string;
  height?: number;
}

interface IchimokuData {
  tenkanSen: number;
  kijunSen: number;
  senkouSpanA: number;
  senkouSpanB: number;
  chikouSpan: number;
}

export default function IchimokuChart({ currencyPair, height = 500 }: IchimokuChartProps) {
  const chartContainerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const [timeframe, setTimeframe] = useState<'1H' | '4H' | '1D' | '1W'>('1D');

  useEffect(() => {
    if (!chartContainerRef.current) return;

    const chart = createChart(chartContainerRef.current, {
      width: chartContainerRef.current.clientWidth,
      height,
      layout: {
        background: { color: '#0a0e1a' },
        textColor: '#ffffff',
      },
      grid: {
        vertLines: { color: '#1a1f37' },
        horzLines: { color: '#1a1f37' },
      },
      crosshair: {
        mode: 1,
      },
      rightPriceScale: {
        borderColor: '#2B2B43',
      },
      timeScale: {
        borderColor: '#2B2B43',
        timeVisible: true,
      },
    });

    chartRef.current = chart;

    const candlestickSeries = chart.addCandlestickSeries({
      upColor: '#26a69a',
      downColor: '#ef5350',
      borderVisible: false,
      wickUpColor: '#26a69a',
      wickDownColor: '#ef5350',
    });

    const tenkanSenSeries = chart.addLineSeries({
      color: '#0ea5e9',
      lineWidth: 2,
      title: 'Tenkan-sen (9)',
    });

    const kijunSenSeries = chart.addLineSeries({
      color: '#f59e0b',
      lineWidth: 2,
      title: 'Kijun-sen (26)',
    });

    const senkouSpanASeries = chart.addLineSeries({
      color: 'rgba(14, 165, 233, 0.3)',
      lineWidth: 1,
      title: 'Senkou Span A',
      lineStyle: LineStyle.Solid,
    });

    const senkouSpanBSeries = chart.addLineSeries({
      color: 'rgba(245, 158, 11, 0.3)',
      lineWidth: 1,
      title: 'Senkou Span B',
      lineStyle: LineStyle.Solid,
    });

    const chikouSpanSeries = chart.addLineSeries({
      color: '#8b5cf6',
      lineWidth: 2,
      title: 'Chikou Span (26)',
      lineStyle: LineStyle.Dotted,
    });

    const mockData = generateMockData(100);
    const ichimokuData = calculateIchimoku(mockData);

    candlestickSeries.setData(mockData);
    tenkanSenSeries.setData(ichimokuData.tenkanSen);
    kijunSenSeries.setData(ichimokuData.kijunSen);
    senkouSpanASeries.setData(ichimokuData.senkouSpanA);
    senkouSpanBSeries.setData(ichimokuData.senkouSpanB);
    chikouSpanSeries.setData(ichimokuData.chikouSpan);

    chart.timeScale().fitContent();

    const handleResize = () => {
      if (chartContainerRef.current && chartRef.current) {
        chartRef.current.applyOptions({ width: chartContainerRef.current.clientWidth });
      }
    };

    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
      chart.remove();
    };
  }, [height, currencyPair, timeframe]);

  return (
    <div className="glass rounded-xl p-6">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-xl font-bold text-white">{currencyPair}</h3>
          <p className="text-sm text-gray-400">Ichimoku Cloud Analysis</p>
        </div>
        <div className="flex gap-2">
          {(['1H', '4H', '1D', '1W'] as const).map((tf) => (
            <button
              key={tf}
              onClick={() => setTimeframe(tf)}
              className={`px-4 py-2 rounded-lg font-medium transition-all ${
                timeframe === tf
                  ? 'bg-primary-500 text-white'
                  : 'bg-white/5 text-gray-400 hover:bg-white/10'
              }`}
            >
              {tf}
            </button>
          ))}
        </div>
      </div>

      <div ref={chartContainerRef} className="w-full" />

      <div className="mt-4 grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="p-3 bg-white/5 rounded-lg">
          <div className="flex items-center gap-2 mb-1">
            <div className="w-3 h-3 rounded-full bg-blue-500" />
            <span className="text-xs text-gray-400">Tenkan-sen</span>
          </div>
          <p className="text-sm font-semibold text-white">Conversion Line (9)</p>
        </div>
        <div className="p-3 bg-white/5 rounded-lg">
          <div className="flex items-center gap-2 mb-1">
            <div className="w-3 h-3 rounded-full bg-amber-500" />
            <span className="text-xs text-gray-400">Kijun-sen</span>
          </div>
          <p className="text-sm font-semibold text-white">Base Line (26)</p>
        </div>
        <div className="p-3 bg-white/5 rounded-lg">
          <div className="flex items-center gap-2 mb-1">
            <div className="w-3 h-3 rounded-full bg-purple-500" />
            <span className="text-xs text-gray-400">Chikou Span</span>
          </div>
          <p className="text-sm font-semibold text-white">Lagging Span (26)</p>
        </div>
        <div className="p-3 bg-white/5 rounded-lg col-span-2">
          <div className="flex items-center gap-2 mb-1">
            <div className="w-3 h-3 rounded-full bg-gradient-to-r from-blue-500 to-amber-500" />
            <span className="text-xs text-gray-400">Kumo (Cloud)</span>
          </div>
          <p className="text-sm font-semibold text-white">Senkou Span A & B</p>
        </div>
      </div>
    </div>
  );
}

function generateMockData(count: number): CandlestickData[] {
  const data: CandlestickData[] = [];
  let basePrice = 50000;
  const now = Math.floor(Date.now() / 1000);
  const interval = 86400;

  for (let i = 0; i < count; i++) {
    const time = (now - (count - i) * interval) as Time;
    const open = basePrice + (Math.random() - 0.5) * 1000;
    const close = open + (Math.random() - 0.5) * 2000;
    const high = Math.max(open, close) + Math.random() * 500;
    const low = Math.min(open, close) - Math.random() * 500;

    data.push({ time, open, high, low, close });
    basePrice = close;
  }

  return data;
}

function calculateIchimoku(candleData: CandlestickData[]) {
  const tenkanPeriod = 9;
  const kijunPeriod = 26;
  const senkouBPeriod = 52;
  const displacement = 26;

  const calculateHighLowAverage = (period: number, index: number): number => {
    const start = Math.max(0, index - period + 1);
    const slice = candleData.slice(start, index + 1);
    const high = Math.max(...slice.map((d) => d.high));
    const low = Math.min(...slice.map((d) => d.low));
    return (high + low) / 2;
  };

  const tenkanSen = candleData.map((_, i) => ({
    time: candleData[i].time,
    value: calculateHighLowAverage(tenkanPeriod, i),
  }));

  const kijunSen = candleData.map((_, i) => ({
    time: candleData[i].time,
    value: calculateHighLowAverage(kijunPeriod, i),
  }));

  // Senkou Span A & B: Only include valid displaced points (no future projection beyond data)
  const senkouSpanA = candleData
    .slice(0, -displacement) // Exclude last 'displacement' points
    .map((_, i) => ({
      time: candleData[i + displacement].time,
      value: (tenkanSen[i].value + kijunSen[i].value) / 2,
    }));

  const senkouSpanB = candleData
    .slice(0, -displacement)
    .map((_, i) => ({
      time: candleData[i + displacement].time,
      value: calculateHighLowAverage(senkouBPeriod, i),
    }));

  // Chikou Span: Only include valid displaced points (no past projection beyond data)
  const chikouSpan = candleData
    .slice(displacement) // Skip first 'displacement' points
    .map((d, i) => ({
      time: candleData[i].time,
      value: d.close,
    }));

  return {
    tenkanSen,
    kijunSen,
    senkouSpanA,
    senkouSpanB,
    chikouSpan,
  };
}
