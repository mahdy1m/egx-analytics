#!/usr/bin/env bash
set -e

BASE="egx-analytics"
echo "Creating project at ./${BASE} ..."

# Remove existing directory to ensure clean scaffold (CAUTION: this deletes existing folder)
if [ -d "${BASE}" ]; then
  echo "Removing existing ./${BASE} (override)..."
  rm -rf "${BASE}"
fi

mkdir -p ${BASE}
cd ${BASE}

# README.md
cat > README.md <<'EOF'
# EGX-Analytics

منصة مفتوحة المصدر لتحليل أسهم البورصة المصرية (EGX) — مؤشرات فنية، كشف الزخم، اكتشاف Breakouts، تنبيهات، ولوحة عرض تفاعلية.

ملاحظة: هذه نسخة PoC تستخدم yfinance كمصدر بيانات مجاني/مؤجل. للحصول على أسعار فورية وموثوقة استخدم مزود مدفوع أو واجهة وساطة.

Quick start (Docker Compose):

1. Clone the repo
2. cd egx-analytics
3. docker-compose up --build

The backend exposes a simple API at http://localhost:8000/api/v1/prices/{symbol}

See docs/ for architecture, data sources and contribution guidelines.

License: MIT
EOF

# LICENSE (MIT)
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 mahdy1m

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

# .gitignore
cat > .gitignore <<'EOF'
__pycache__/
.env
node_modules/
dist/
.vscode/
*.pyc
*.pyo
*.sqlite3
.DS_Store
egx-analytics.zip
egx-analytics.tar.gz
EOF

# docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: '3.8'
services:
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - DATA_SOURCE=YFINANCE
    volumes:
      - ./backend:/app
  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    volumes:
      - ./frontend:/app
  redis:
    image: redis:7
    ports:
      - "6379:6379"
EOF

# backend scaffold
mkdir -p backend/app/api backend/app/services
cat > backend/app/main.py <<'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import prices

app = FastAPI(title="EGX Analytics API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(prices.router, prefix="/api/v1/prices", tags=["prices"])

@app.get("/")
async def root():
    return {"message": "EGX Analytics API is running"}
EOF

cat > backend/app/api/prices.py <<'EOF'
from fastapi import APIRouter, HTTPException
from app.services.data_fetcher import fetch_symbol_ohlcv
from app.services.indicators import add_indicators

router = APIRouter()

@router.get("/{symbol}")
async def get_prices(symbol: str, period: str = "90d", interval: str = "1d"):
    """
    Returns OHLCV for symbol plus basic indicators
    """
    try:
        df = fetch_symbol_ohlcv(symbol, period=period, interval=interval)
        df_ind = add_indicators(df)
        # Convert to simple JSON-friendly structure
        data = df_ind.reset_index().to_dict(orient="records")
        return {"symbol": symbol, "data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
EOF

cat > backend/app/services/data_fetcher.py <<'EOF'
import pandas as pd
import yfinance as yf

def fetch_symbol_ohlcv(symbol: str, period: str = "90d", interval: str = "1d") -> pd.DataFrame:
    """
    Fetches OHLCV using yfinance (PoC). For EGX, symbol naming may require suffix (e.g., 'CIB.CA' or local mapping).
    """
    # For many EGX tickers, yfinance uses suffix '.CA' or different mapping.
    yf_sym = symbol
    if not symbol.upper().endswith(".CA"):
        yf_sym = symbol + ".CA"
    ticker = yf.Ticker(yf_sym)
    df = ticker.history(period=period, interval=interval)
    if df.empty:
        # Try without suffix
        df = ticker.history(period=period, interval=interval)
    if df.empty:
        raise ValueError(f"No data for symbol {symbol} via yfinance")
    # Keep standardized columns
    df = df[["Open", "High", "Low", "Close", "Volume"]]
    df.index.name = "Date"
    return df
EOF

cat > backend/app/services/indicators.py <<'EOF'
import pandas as pd

def add_indicators(df: pd.DataFrame) -> pd.DataFrame:
    """
    Add common technical indicators: SMA, EMA, RSI, MACD, OBV, Bollinger Bands
    """
    df = df.copy()
    # SMA/EMA
    df["SMA_20"] = df["Close"].rolling(window=20, min_periods=1).mean()
    df["EMA_20"] = df["Close"].ewm(span=20, adjust=False).mean()

    # RSI
    delta = df["Close"].diff()
    up = delta.clip(lower=0)
    down = -1 * delta.clip(upper=0)
    ma_up = up.rolling(14, min_periods=1).mean()
    ma_down = down.rolling(14, min_periods=1).mean()
    rs = ma_up / (ma_down + 1e-9)
    df["RSI_14"] = 100 - (100 / (1 + rs))

    # MACD
    ema12 = df["Close"].ewm(span=12, adjust=False).mean()
    ema26 = df["Close"].ewm(span=26, adjust=False).mean()
    df["MACD"] = ema12 - ema26
    df["MACD_signal"] = df["MACD"].ewm(span=9, adjust=False).mean()

    # OBV
    obv = [0]
    for i in range(1, len(df)):
        if df["Close"].iat[i] > df["Close"].iat[i-1]:
            obv.append(obv[-1] + df["Volume"].iat[i])
        elif df["Close"].iat[i] < df["Close"].iat[i-1]:
            obv.append(obv[-1] - df["Volume"].iat[i])
        else:
            obv.append(obv[-1])
    df["OBV"] = obv

    # Bollinger Bands
    sma = df["Close"].rolling(20).mean()
    std = df["Close"].rolling(20).std()
    df["BB_upper"] = sma + (std * 2)
    df["BB_lower"] = sma - (std * 2)

    return df
EOF

cat > backend/requirements.txt <<'EOF'
fastapi
uvicorn[standard]
pandas
yfinance
numpy
python-multipart
aiohttp
EOF

cat > backend/Dockerfile <<'EOF'
FROM python:3.11-slim

WORKDIR /app
COPY ./app ./app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# frontend scaffold
mkdir -p frontend/pages frontend/components
cat > frontend/package.json <<'EOF'
{
  "name": "egx-analytics-frontend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev -p 3000",
    "build": "next build",
    "start": "next start -p 3000"
  },
  "dependencies": {
    "next": "13.4.0",
    "react": "18.2.0",
    "react-dom": "18.2.0",
    "axios": "^1.4.0",
    "lightweight-charts": "^3.7.0"
  }
}
EOF

cat > frontend/pages/index.js <<'EOF'
import React, { useEffect, useState } from "react";
import axios from "axios";
import Chart from "../components/Chart";

export default function Home() {
  const [symbol, setSymbol] = useState("CIB");
  const [data, setData] = useState([]);

  const fetchData = async () => {
    try {
      const res = await axios.get(`http://localhost:8000/api/v1/prices/${symbol}`);
      setData(res.data.data || []);
    } catch (e) {
      console.error(e);
      alert("خطأ في جلب البيانات. تأكد من أن backend يعمل.");
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  return (
    <div style={{ padding: 20 }}>
      <h1>EGX Analytics (PoC)</h1>
      <div>
        <input value={symbol} onChange={(e) => setSymbol(e.target.value)} />
        <button onClick={fetchData}>جلب السعر</button>
      </div>
      <Chart series={data} />
    </div>
  );
}
EOF

cat > frontend/components/Chart.jsx <<'EOF'
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
EOF

cat > frontend/Dockerfile <<'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]
EOF

# data_connectors
mkdir -p data_connectors
cat > data_connectors/egx_connector.py <<'EOF'
"""
Simple mapping helper for EGX tickers.
This file can be extended to map local tickers to yfinance symbols or to call an official EGX API.
"""
EGX_MAP = {
    "CIB": "CIB.CA",
    "EGX30": "EGX30",
    # Add more mappings as needed
}

def map_symbol(sym: str) -> str:
    return EGX_MAP.get(sym.upper(), sym)
EOF

# basic docs folder
mkdir -p docs
cat > docs/ARCHITECTURE.md <<'EOF'
EGX-Analytics Architecture (PoC)

- Frontend: Next.js + Lightweight Charts for candlestick rendering.
- Backend: FastAPI exposing endpoints to fetch OHLCV and computed indicators.
- Data source (PoC): yfinance (delayed/free). Replace data_fetcher with paid provider for real-time.
- Realtime: Redis included in docker-compose for future Pub/Sub.
- Storage: None in PoC - suggested: TimescaleDB/Postgres for production.

To extend:
- Add auth, DB, scheduling (Celery), WebSocket streaming, paid data connectors.
EOF

# basic CI (optional)
mkdir -p .github/workflows
cat > .github/workflows/ci.yml <<'EOF'
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: 3.11
      - name: Install backend deps
        run: |
          cd backend
          python -m pip install --upgrade pip
          pip install -r requirements.txt
      - name: Run quick backend check
        run: |
          python - <<PY
import importlib,sys
spec = importlib.util.spec_from_file_location("ind", "backend/app/services/indicators.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
print("Indicators module loaded")
PY
EOF

# go back and create archive
cd ..
if command -v zip >/dev/null 2>&1; then
  echo "Creating egx-analytics.zip ..."
  zip -r egx-analytics.zip ${BASE}
  echo "Created egx-analytics.zip"
else
  echo "zip not found; creating tar.gz..."
  tar -czf egx-analytics.tar.gz ${BASE}
  echo "Created egx-analytics.tar.gz"
fi

echo "Done. Project scaffold is in ./${BASE} and archive created."
echo "Next steps:"
echo "  cd ${BASE}"
echo "  # initialize git and push to GitHub (replace origin URL with your repo):"
echo "  git init"
echo "  git add ."
echo "  git commit -m \"Initial scaffold for EGX-Analytics\""
echo "  git branch -M main"
echo "  git remote add origin git@github.com:mahdy1m/egx-analytics.git"
echo "  git push -u origin main"