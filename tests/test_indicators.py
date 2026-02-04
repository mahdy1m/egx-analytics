import pandas as pd
from app.services.indicators import add_indicators


def make_df():
    data = {
        "Open": [10, 11, 12, 13, 14],
        "High": [11, 12, 13, 14, 15],
        "Low": [9, 10, 11, 12, 13],
        "Close": [10, 11, 12, 13, 14],
        "Volume": [100, 110, 120, 130, 140],
    }
    df = pd.DataFrame(data)
    df.index = pd.date_range("2023-01-01", periods=len(df))
    df.index.name = "Date"
    return df


def test_add_indicators_columns():
    df = make_df()
    out = add_indicators(df)
    for col in ["SMA_20", "EMA_20", "RSI_14", "MACD", "MACD_signal", "OBV", "BB_upper", "BB_lower"]:
        assert col in out.columns


def test_obv_behaviour():
    df = make_df()
    out = add_indicators(df)
    # OBV starts at 0 and then changes with volume depending on price direction
    assert out["OBV"].iloc[0] == 0
    assert out["OBV"].iloc[-1] != 0
