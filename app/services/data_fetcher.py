import pandas as pd
import yfinance as yf


def fetch_symbol_ohlcv(symbol: str, period: str = "90d", interval: str = "1d") -> pd.DataFrame:
    """
    Fetches OHLCV using yfinance (PoC). For EGX, symbol naming may require suffix (e.g., 'CIB.CA' or local mapping).
    """
    yf_sym = symbol
    if not symbol.upper().endswith(".CA"):
        yf_sym = symbol + ".CA"
    ticker = yf.Ticker(yf_sym)
    df = ticker.history(period=period, interval=interval)
    if df.empty:
        # Try without suffix (some tickers may be different)
        df = ticker.history(period=period, interval=interval)
    if df.empty:
        raise ValueError(f"No data for symbol {symbol} via yfinance")
    df = df[["Open", "High", "Low", "Close", "Volume"]]
    df.index.name = "Date"
    return df
