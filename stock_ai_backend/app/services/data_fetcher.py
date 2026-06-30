import pandas as pd
import numpy as np
import os
import pyotp
import time
import threading
from dotenv import load_dotenv
from SmartApi import SmartConnect
from datetime import datetime, timedelta
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
BASE_DIR = os.path.abspath(os.path.join(CURRENT_DIR, "../../"))
load_dotenv(os.path.join(BASE_DIR, ".env"))
class DataFetcher:
    def __init__(self):
        self.symbols_lut = self._load_csv()
        self._lock = threading.Lock()
        self.api = self._init_session()
        self._last_auth_time = datetime.now() if self.api else None
    def _load_csv(self):
        try:
            csv_path = os.path.join(BASE_DIR, "NSE_Symbols.csv")
            if os.path.exists(csv_path):
                df = pd.read_csv(csv_path, low_memory=False)
                df.columns = [c.strip() for c in df.columns]
                return df[df['exch_seg'] == 'NSE'] if 'exch_seg' in df.columns else df
            return pd.DataFrame()
        except Exception as e:
            print(f"[ERROR] DataFetcher: CSV Error: {e}")
            return pd.DataFrame()
    def _init_session(self):
        try:
            api_key = os.getenv("API_KEY")
            client_id = os.getenv("CLIENT_ID")
            pin = os.getenv("PIN")
            totp_secret = os.getenv("TOTP_SECRET", "").replace(" ", "")
            if not all([api_key, client_id, pin, totp_secret]):
                print("[ERROR] DataFetcher: Missing broker credentials in .env")
                return None
            api = SmartConnect(api_key=api_key)
            totp_code = pyotp.TOTP(totp_secret).now()
            time.sleep(1)
            session = api.generateSession(client_id, pin, totp_code)
            if session and session.get('status'):
                self._refresh_token_str = session['data']['refreshToken']
                print("[OK] DataFetcher: Broker session established successfully.")
                return api
            else:
                print(f"[ERROR] DataFetcher: Session rejected: {session.get('message', 'Unknown') if session else 'None'}")
                return None
        except Exception as e:
            print(f"[ERROR] DataFetcher: Login Exception: {e}")
            return None
    def _refresh_session(self):
        with self._lock:
            print("[REFRESH] DataFetcher: Refreshing broker session...")
            if getattr(self, '_refresh_token_str', None) and self.api:
                try:
                    res = self.api.generateToken(self._refresh_token_str)
                    if res and res.get('status'):
                        self._refresh_token_str = res['data']['refreshToken']
                        self._last_auth_time = datetime.now()
                        print("[OK] DataFetcher: Session renewed silently via refresh token.")
                        return True
                except Exception as e:
                    print(f"[WARN] DataFetcher: Silent refresh failed: {e}")
            print("[WARN] DataFetcher: Falling back to full TOTP login...")
            time.sleep(2)
            self.api = self._init_session()
            self._last_auth_time = datetime.now() if self.api else None
            return self.api is not None
    def _is_session_stale(self):
        if not self._last_auth_time:
            return True
        return (datetime.now() - self._last_auth_time).total_seconds() > 20 * 3600
    def is_session_alive(self):
        if not self.api:
            return False
        try:
            profile = self.api.getProfile(os.getenv("CLIENT_ID", ""))
            return profile is not None and profile.get('status', False)
        except Exception:
            return False
    def get_enriched_data(self, symbol_input, mode="intraday"):
        if self.symbols_lut.empty:
            return None
        if self._is_session_stale() or not self.api:
            self._refresh_session()
        if not self.api:
            return None
        query = symbol_input.upper().strip()
        match = self.symbols_lut[(self.symbols_lut['symbol'].str.upper() == query) |
                                 (self.symbols_lut['symbol'].str.upper() == f"{query}-EQ")]
        if match.empty: return None
        token = str(match.iloc[0]['token'])
        trading_symbol = str(match.iloc[0]['symbol'])
        interval = "FIFTEEN_MINUTE" if mode.lower() == "intraday" else "ONE_MINUTE"
        for attempt in range(2):
            result = self._fetch_candles(token, trading_symbol, interval)
            if result is not None:
                return result
            if attempt == 0:
                print(f"[WARN] DataFetcher: Fetch failed for {query}, refreshing session (attempt {attempt + 1})...")
                if not self._refresh_session():
                    print("[ERROR] DataFetcher: Session refresh failed. Cannot recover.")
                    return None
        return None
    def _fetch_candles(self, token, trading_symbol, interval):
        try:
            now = datetime.now()
            from_time = (now - timedelta(days=20)).strftime('%Y-%m-%d 09:15')
            to_time = now.strftime('%Y-%m-%d %H:%M')
            
            # Add delay to prevent "Access denied because of exceeding access rate" (Rate Limit: 3 requests/sec)
            time.sleep(0.5) 
            
            res = self.api.getCandleData({
                "exchange": "NSE", "symboltoken": token, "interval": interval,
                "fromdate": from_time, "todate": to_time
            })
            if res and res.get('status') and res.get('data'):
                df = pd.DataFrame(res['data'], columns=['time', 'open', 'high', 'low', 'close', 'volume'])
                for col in ['open', 'high', 'low', 'close', 'volume']:
                    df[col] = pd.to_numeric(df[col], errors='coerce')
                try:
                    ltp_res = self.api.ltpData("NSE", trading_symbol, token)
                    if ltp_res and ltp_res.get('status'):
                        live_ltp = float(ltp_res['data']['ltp'])
                        df.at[df.index[-1], 'close'] = live_ltp
                        df.at[df.index[-1], 'high'] = max(df.at[df.index[-1], 'high'], live_ltp)
                        df.at[df.index[-1], 'low'] = min(df.at[df.index[-1], 'low'], live_ltp)
                except Exception:
                    pass
                df['rsi'] = self._calculate_rsi(df['close'])
                df['atr'] = self._calculate_atr(df)
                df['ema_20'] = df['close'].ewm(span=20, adjust=False).mean()
                df['h_o'] = ((df['high'] - df['close']) / (df['close'] + 0.001)) * 100
                df['pct_chng'] = df['close'].pct_change() * 100
                enriched = df.dropna().reset_index(drop=True)
                return enriched if not enriched.empty else None
            return None
        except Exception as e:
            print(f"[ERROR] Fetcher Error: {e}")
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
