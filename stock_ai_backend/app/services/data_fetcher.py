import pandas as pd
import numpy as np
import os
import pyotp
import time  # Required for API speed limiting
from dotenv import load_dotenv
from SmartApi import SmartConnect
from datetime import datetime, timedelta

# --- ABSOLUTE PATH & SECURITY LOGIC ---
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
BASE_DIR = os.path.abspath(os.path.join(CURRENT_DIR, "../../"))

# 🔒 Load the hidden environment variables into server RAM
load_dotenv(os.path.join(BASE_DIR, ".env"))

class DataFetcher:
    def __init__(self):
        try:
            csv_path = os.path.join(BASE_DIR, "NSE_Symbols.csv")
            if os.path.exists(csv_path):
                self.symbols_lut = pd.read_csv(csv_path, low_memory=False, encoding='utf-8')
                self.symbols_lut.columns = [c.strip() for c in self.symbols_lut.columns]
                if 'exch_seg' in self.symbols_lut.columns:
                    self.symbols_lut = self.symbols_lut[self.symbols_lut['exch_seg'] == 'NSE']
                print(f"✅ DataFetcher: CSV Loaded from {csv_path}")
            else:
                self.symbols_lut = pd.DataFrame()
        except Exception as e:
            print(f"❌ DataFetcher: CSV Error: {e}")
            self.symbols_lut = pd.DataFrame()

        self.api = self._init_session()

    def _init_session(self):
        try:
            # 🔒 SECURE CREDENTIAL EXTRACTION
            api_key = os.getenv("API_KEY")
            client_id = os.getenv("CLIENT_ID")
            pin = os.getenv("PIN")
            totp_secret = os.getenv("TOTP_SECRET", "").replace(" ", "")

            # Safety check to ensure the .env file is being read correctly
            if not all([api_key, client_id, pin, totp_secret]):
                print("⚠️ CRITICAL SECURITY FAULT: Missing Angel One credentials in .env file!")
                return None

            api = SmartConnect(api_key=api_key)
            totp_code = pyotp.TOTP(totp_secret).now()
            session = api.generateSession(client_id, pin, totp_code)
            
            if session.get('status'):
                print("✅ ANGEL ONE SESSION ACTIVE (Secured via .env)")
                return api
            else:
                print(f"❌ Angel One Login Rejected: {session.get('message', 'Unknown Error')}")
                return None
        except Exception as e:
            print(f"❌ DataFetcher: Login Exception: {e}")
            return None

    def _calculate_professional_rsi(self, series, period=14):
        """Calculates RSI using Wilder's Smoothing Method (Professional Grade)"""
        delta = series.diff()
        gain = (delta.where(delta > 0, 0))
        loss = (-delta.where(delta < 0, 0))

        # Initial Average Gain/Loss (Simple Average)
        avg_gain = gain.rolling(window=period, min_periods=period).mean()
        avg_loss = loss.rolling(window=period, min_periods=period).mean()

        # Smoothed Average Gain/Loss
        for i in range(period, len(avg_gain)):
            avg_gain.iloc[i] = (avg_gain.iloc[i-1] * (period - 1) + gain.iloc[i]) / period
            avg_loss.iloc[i] = (avg_loss.iloc[i-1] * (period - 1) + loss.iloc[i]) / period

        rs = avg_gain / (avg_loss + 0.00001) # Avoid div by zero
        return 100 - (100 / (1 + rs))

    def _calculate_atr(self, df, period=14):
        """Calculates Average True Range for Realistic Candle Projection"""
        high_low = df['high'] - df['low']
        high_close = (df['high'] - df['close'].shift()).abs()
        low_close = (df['low'] - df['close'].shift()).abs()
        
        ranges = pd.concat([high_low, high_close, low_close], axis=1)
        true_range = ranges.max(axis=1)
        return true_range.rolling(window=period).mean()

    def get_enriched_data(self, symbol_input, mode="intraday"):
        if self.symbols_lut.empty or not self.api:
            return None

        query = symbol_input.upper().strip()
        match = self.symbols_lut[
            (self.symbols_lut['symbol'].str.upper() == query) | 
            (self.symbols_lut['symbol'].str.upper() == f"{query}-EQ")
        ]
        
        if match.empty:
            return None
            
        token = str(match.iloc[0]['token'])
        trading_symbol = str(match.iloc[0]['symbol'])
        interval = "FIFTEEN_MINUTE" if mode.lower() == "intraday" else "ONE_MINUTE"
        
        try:
            now = datetime.now()
            if now.weekday() >= 5: # Weekend Logic
                days_to_subtract = 1 if now.weekday() == 5 else 2
                last_friday = now - timedelta(days=days_to_subtract)
                to_time = last_friday.strftime('%Y-%m-%d 15:30')
                from_time = (last_friday - timedelta(days=20)).strftime('%Y-%m-%d 09:15')
            else:
                to_time = now.strftime('%Y-%m-%d %H:%M')
                from_time = (now - timedelta(days=20)).strftime('%Y-%m-%d 09:15')

            # --- UNCONDITIONAL THROTTLING ---
            time.sleep(0.5) 
            
            res = None
            for attempt in range(3): # Try up to 3 times
                try:
                    res = self.api.getCandleData({
                        "exchange": "NSE", 
                        "symboltoken": token, 
                        "interval": interval,
                        "fromdate": from_time,
                        "todate": to_time
                    })
                    break # If successful, break out of the retry loop
                    
                except Exception as api_err:
                    if "Access denied" in str(api_err) or "JSON" in str(api_err):
                        if attempt < 2:
                            sleep_time = attempt + 2 # Wait 2s, then 3s
                            print(f"⏳ Rate Limit hit for {trading_symbol}. Retrying in {sleep_time}s...")
                            time.sleep(sleep_time)
                        else:
                            raise api_err
                    else:
                        raise api_err 

            if res and res.get('status') and res.get('data'):
                df = pd.DataFrame(res['data'], columns=['time', 'open', 'high', 'low', 'close', 'volume'])
                for col in ['open', 'high', 'low', 'close', 'volume']:
                    df[col] = pd.to_numeric(df[col], errors='coerce')
                
                # =========================================================
                # ⚡ ABSOLUTE LIVE PRICE (LTP) INJECTION
                # =========================================================
                try:
                    time.sleep(0.5) 
                    ltp_res = self.api.ltpData("NSE", trading_symbol, token)
                    if ltp_res and ltp_res.get('status') and ltp_res.get('data'):
                        live_ltp = float(ltp_res['data']['ltp'])
                        df.at[df.index[-1], 'close'] = live_ltp
                        df.at[df.index[-1], 'high'] = max(df.at[df.index[-1], 'high'], live_ltp)
                        df.at[df.index[-1], 'low'] = min(df.at[df.index[-1], 'low'], live_ltp)
                        print(f"⚡ {trading_symbol} LIVE TICK APPLIED: ₹{live_ltp}")
                except Exception as ltp_err:
                    print(f"⚠️ Live LTP fetch delayed, using latest closed candle: {ltp_err}")

                # --- PROFESSIONAL INDICATOR LAYER ---
                df['rsi'] = self._calculate_professional_rsi(df['close'])
                df['atr'] = self._calculate_atr(df)
                df['ema_20'] = df['close'].ewm(span=20, adjust=False).mean()
                df['h_o'] = ((df['high'] - df['close']) / (df['close'] + 0.001)) * 100
                df['pct_chng'] = df['close'].pct_change() * 100
                
                final_df = df.dropna().reset_index(drop=True)
                print(f"📊 {trading_symbol}: Technicals Synced (RSI: {final_df['rsi'].iloc[-1]:.2f})")
                return final_df
            
            return None
        except Exception as e:
            print(f"❌ Fetcher Error: {e}")
            return None