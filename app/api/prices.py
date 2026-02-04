from fastapi import APIRouter, HTTPException, Query
from typing import Optional
import pandas as pd

from app.services import data_fetcher, add_indicators, map_symbol

router = APIRouter()

@router.get("/{symbol}")
async def get_prices(
    symbol: str,
    period: Optional[str] = Query("90d", description="yfinance period (e.g. 30d, 90d)"),
    interval: Optional[str] = Query("1d", description="yfinance interval (e.g. 1d, 1h)"),
    with_indicators: bool = Query(True, description="Include technical indicators in the result"),
):
    """Return OHLCV data (and optional indicators) for a symbol.

    The endpoint attempts a simple EGX mapping and falls back to the raw symbol if needed.
    """
    try:
        mapped = map_symbol(symbol)
        df: pd.DataFrame = data_fetcher.fetch_symbol_ohlcv(mapped, period=period, interval=interval)
    except Exception as exc:
        raise HTTPException(status_code=404, detail=str(exc))

    if with_indicators:
        df = add_indicators(df)

    # Convert to JSON-serializable structure
    df = df.reset_index()
    records = df.to_dict(orient="records")
    # Replace NaN with None for JSON compatibility (pandas keeps NaN in float arrays)
    cleaned = []
    for r in records:
        cleaned.append({k: (None if pd.isna(v) else v) for k, v in r.items()})
    records = cleaned

    return {"symbol": symbol, "mapped": mapped, "rows": len(records), "data": records}
