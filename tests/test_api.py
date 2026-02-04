from fastapi.testclient import TestClient
import pandas as pd
from app.main import app

from app.services import data_fetcher

client = TestClient(app)


def make_df():
    data = {
        "Open": [10, 11],
        "High": [11, 12],
        "Low": [9, 10],
        "Close": [10, 11],
        "Volume": [100, 110],
    }
    df = pd.DataFrame(data)
    df.index = pd.date_range("2023-01-01", periods=len(df))
    df.index.name = "Date"
    return df


def test_prices_endpoint(monkeypatch):
    df = make_df()

    def fake_fetch(symbol, period="90d", interval="1d"):
        return df

    monkeypatch.setattr(data_fetcher, "fetch_symbol_ohlcv", fake_fetch)

    res = client.get("/api/v1/prices/CIB")
    assert res.status_code == 200
    body = res.json()
    assert body["symbol"] == "CIB"
    assert "data" in body
    assert body["rows"] == 2
