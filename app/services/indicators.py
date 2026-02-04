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
