import React, { useEffect, useRef } from "react";
import { createChart } from "lightweight-charts";

export default function Chart({ series }) {
  const ref = useRef();

  useEffect(() => {
    if (!ref.current) return;
    const chart = createChart(ref.current, { width: 800, height: 380 });
    const candlestick = chart.addCandlestickSeries();
    const data = (series || []).map((r) => ({
      time: new Date(r.Date).toISOString().slice(0,10),
      open: r.Open,
      high: r.High,
      low: r.Low,
      close: r.Close,
    }));
    candlestick.setData(data);
    return () => chart.remove();
  }, [series]);

  return <div ref={ref} />;
}
