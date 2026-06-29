import pandas as pd
import os
import pyotp
import re
from dotenv import load_dotenv
from SmartApi import SmartConnect
from datetime import datetime, timedelta
load_dotenv()
class DataFetcher:
    def __init__(self):
        try:
            csv_path = "NSE_Symbols.csv"
            if os.path.exists(csv_path):
                self.symbols_lut = pd.read_csv(csv_path, low_memory=False, encoding='utf-8')
                self.symbols_lut.columns = [c.strip() for c in self.symbols_lut.columns]
                if 'exch_seg' in self.symbols_lut.columns:
                    self.symbols_lut = self.symbols_lut[self.symbols_lut['exch_seg'] == 'NSE']
                print(f" DataFetcher: CSV Loaded. Mapping {len(self.symbols_lut)} NSE symbols.")
            else:
                print(f" DataFetcher: {csv_path} not found. Using empty mapping.")
                self.symbols_lut = pd.DataFrame()
        except Exception as e:
            print(f" DataFetcher: CSV Error: {e}")
            self.symbols_lut = pd.DataFrame()
        self.api = self._init_session()
    def _init_session(self):
        try:
            api_key = os.getenv("API_KEY")
            client_id = os.getenv("CLIENT_ID")
            pin = os.getenv("PIN")
            totp_secret = os.getenv("TOTP_SECRET", "").replace(" ", "")
            if not all([api_key, client_id, pin, totp_secret]):
                print(" DataFetcher: Missing API Credentials in .env")
                print(f"DEBUG: API_KEY present: {bool(api_key)}, CLIENT_ID: {bool(client_id)}")
                return None
            api = SmartConnect(api_key=api_key)
            totp_code = pyotp.TOTP(totp_secret).now()
            session = api.generateSession(client_id, pin, totp_code)
            if session.get('status') and session.get('data'):
                print(" ANGEL ONE SESSION ACTIVE")
                return api
            else:
                print(f" Login Failed: {session.get('message')}")
                return None
        except Exception as e:
            print(f" DataFetcher: Login Exception: {e}")
            return None
    def get_enriched_data(self, symbol_input, mode="intraday"):
        if self.symbols_lut.empty or not self.api:
            print(" Fetcher Stalled: API Session not authenticated.")
            return None
        query = symbol_input.upper().strip()
        match = self.symbols_lut[
            (self.symbols_lut['symbol'].str.upper() == query) |
            (self.symbols_lut['symbol'].str.upper() == f"{query}-EQ")
        ]
        if match.empty:
            match = self.symbols_lut[self.symbols_lut['symbol'].str.upper().str.contains(query)]
        if match.empty:
            print(f" Symbol {query} not found in NSE List.")
            return None
        token = str(match.iloc[0]['token'])
        trading_symbol = str(match.iloc[0]['symbol'])
        interval = "FIFTEEN_MINUTE" if mode.lower() == "intraday" else "ONE_MINUTE"
        try:
            to_time = (datetime.now() - timedelta(minutes=1)).strftime('%Y-%m-%d %H:%M')
            from_time = (datetime.now() - timedelta(days=14)).strftime('%Y-%m-%d 09:15')
            print(f" API Request: {trading_symbol} (Token: {token})")
            res = self.api.getCandleData({
                "exchange": "NSE",
                "symboltoken": token,
                "interval": interval,
                "fromdate": from_time,
                "todate": to_time
            })
            if res.get('status') and res.get('data'):
                df = pd.DataFrame(res['data'], columns=['time', 'open', 'high', 'low', 'close', 'volume'])
                for col in ['open', 'high', 'low', 'close', 'volume']:
                    df[col] = pd.to_numeric(df[col], errors='coerce')
                df['h_o'] = ((df['high'] - df['close']) / (df['close'] + 0.001)) * 100
                df['pct_chng'] = ((df['close'] - df['open']) / (df['open'] + 0.001)) * 100
                final_df = df.dropna().reset_index(drop=True)
                print(f" Live Data: {len(final_df)} candles retrieved for {query}")
                return final_df
            print(f" API Error: {res.get('message', 'Empty Data Received')}")
            return None
        except Exception as e:
            print(f" Fetcher Error: {e}")
            return None
