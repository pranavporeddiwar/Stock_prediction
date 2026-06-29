import os
import requests
import pandas as pd
from dotenv import load_dotenv
load_dotenv()
class StockService:
    def __init__(self):
        self.api_key = os.getenv("RX8JSG2TYR1ZCK6M")
        self.base_url = "https://www.alphavantage.co/query"
    def get_real_time_candles(self, symbol: str):
        params = {
            "function": "TIME_SERIES_INTRADAY",
            "symbol": f"{symbol}.NSE",
            "interval": "15min",
            "apikey": self.api_key,
            "outputsize": "full"
        }
        response = requests.get(self.base_url, params=params)
        data = response.json()
        if "Note" in data:
            print(" API Limit reached. Wait a minute or use a different key.")
            return None
        time_series = data.get("Time Series (15min)", {})
        df = pd.DataFrame.from_dict(time_series, orient='index')
        df.columns = ['Open', 'High', 'Low', 'Close', 'Volume']
        df.index = pd.to_datetime(df.index)
        df = df.sort_index().astype(float)
        return df
