import pandas as pd
import numpy as np
import os
import pyotp
import time
from dotenv import load_dotenv
from SmartApi import SmartConnect
from datetime import datetime, timedelta

# --- ABSOLUTE PATH LOGIC ---
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
BASE_DIR = os.path.abspath(os.path.join(CURRENT_DIR, "../../"))
load_dotenv(os.path.join(BASE_DIR, ".env"))

class DataFetcher:
    def __init__(self):
        self.symbols_lut = self._load_csv()
        self.api = self._init_session()

    def _load_csv(self):
        try:
            csv_path = os.path.join(BASE_DIR, "NSE_Symbols.csv")
            if os.path.exists(csv_path):
                df = pd.read_csv(csv_path, low_memory=False)
                df.columns = [c.strip() for c in df.columns]
                return df[df['exch_seg'] == 'NSE'] if 'exch_seg' in df.columns else df
            return pd.DataFrame()
        except Exception as e:
            print(f"❌ DataFetcher: CSV Error: {e}")
            return pd.DataFrame()

    def _init_session(self):
        try:
            api_key = os.getenv("API_KEY")
            client_id = os.getenv("CLIENT_ID")
            pin = os.getenv("PIN")
            totp_secret = os.getenv("TOTP_SECRET", "").replace(" ", "")

            if not all([api_key, client_id, pin, totp_secret]):
                return None

            api = SmartConnect(api_key=api_key)
            totp_code = pyotp.TOTP(totp_secret).now()
            session = api.generateSession(client_id, pin, totp_code)
            return api if session.get('status') else None
        except Exception as e:
            print(f"❌ DataFetcher: Login Exception: {e}")
            return None

    def get_enriched_data(self, symbol_input, mode="intraday"):
        if self.symbols_lut.empty or not self.api: return None

        query = symbol_input.upper().strip()
        match = self.symbols_lut[(self.symbols_lut['symbol'].str.upper() == query) | 
                                 (self.symbols_lut['symbol'].str.upper() == f"{query}-EQ")]
        
        if match.empty: return None
            
        token = str(match.iloc[0]['token'])
        trading_symbol = str(match.iloc[0]['symbol'])
        interval = "FIFTEEN_MINUTE" if mode.lower() == "intraday" else "ONE_MINUTE"
        
        try:
            now = datetime.now()
            from_time = (now - timedelta(days=20)).strftime('%Y-%m-%d 09:15')
            to_time = now.strftime('%Y-%m-%d %H:%M')

            res = self.api.getCandleData({
                "exchange": "NSE", "symboltoken": token, "interval": interval,
                "fromdate": from_time, "todate": to_time
            })

            if res and res.get('status') and res.get('data'):
                df = pd.DataFrame(res['data'], columns=['time', 'open', 'high', 'low', 'close', 'volume'])
                for col in ['open', 'high', 'low', 'close', 'volume']:
                    df[col] = pd.to_numeric(df[col], errors='coerce')
                
                # Injection: Live Price Tick
                try:
                    ltp_res = self.api.ltpData("NSE", trading_symbol, token)
                    if ltp_res and ltp_res.get('status'):
                        live_ltp = float(ltp_res['data']['ltp'])
                        df.at[df.index[-1], 'close'] = live_ltp
                        df.at[df.index[-1], 'high'] = max(df.at[df.index[-1], 'high'], live_ltp)
                        df.at[df.index[-1], 'low'] = min(df.at[df.index[-1], 'low'], live_ltp)
                except: pass

                # Professional Indicators
                df['rsi'] = self._calculate_rsi(df['close'])
                df['atr'] = self._calculate_atr(df)
                df['ema_20'] = df['close'].ewm(span=20, adjust=False).mean()
                df['h_o'] = ((df['high'] - df['close']) / (df['close'] + 0.001)) * 100
                df['pct_chng'] = df['close'].pct_change() * 100
                
                return df.dropna().reset_index(drop=True)
            return None
        except Exception as e:
            print(f"❌ Fetcher Error: {e}")
            return None

    def _calculate_rsi(self, series, period=14):
        delta = series.diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
        rs = gain / (loss + 0.00001)
        return 100 - (100 / (1 + rs))

    def _calculate_atr(self, df, period=14):
        high_low = df['high'] - df['low']
        high_close = (df['high'] - df['close'].shift()).abs()
        low_close = (df['low'] - df['close'].shift()).abs()
        return pd.concat([high_low, high_close, low_close], axis=1).max(axis=1).rolling(window=period).mean()