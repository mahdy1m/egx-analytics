<<<<<<< HEAD
from app.services.egx_connector import map_symbol

__all__ = ["map_symbol"]
=======
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
>>>>>>> origin/main
