import pandas as pd
import types
import builtins


from app.services.data_fetcher import fetch_symbol_ohlcv


class DummyTicker:
    def __init__(self, df):
        self._df = df

    def history(self, period, interval):
        return self._df


def test_fetch_symbol_ohlcv(monkeypatch):
    # Create a small dataframe with required columns
    data = {
        "Open": [1.0, 2.0],
        "High": [1.1, 2.1],
        "Low": [0.9, 1.9],
        "Close": [1.0, 2.0],
        "Volume": [10, 20],
    }
    df = pd.DataFrame(data)
    df.index = pd.date_range("2023-01-01", periods=2)
    df.index.name = "Date"

    def fake_ticker(sym):
        return DummyTicker(df)

    import yfinance as yf
    monkeypatch.setattr(yf, "Ticker", fake_ticker)

    out = fetch_symbol_ohlcv("CIB")
    assert list(out.columns) == ["Open", "High", "Low", "Close", "Volume"]
    assert len(out) == 2
