import time
from app.services.data_fetcher import DataFetcher

class WatchlistService:
    def __init__(self):
        self.fetcher = DataFetcher()
        # --- CACHING SYSTEM ---
        self.cached_data = []
        self.last_update_time = 0
        self.cache_duration = 60 # Keep data for 60 seconds to prevent API bans

    def get_market_overview(self):
        """Fetches the watchlist, respecting Angel One API limits."""
        
        current_time = time.time()
        
        # 1. Return cached data if it's less than 60 seconds old
        if current_time - self.last_update_time < self.cache_duration and self.cached_data:
            print("⚡ Returning Watchlist from Cache (Saved API Call)")
            return self.cached_data

        # 2. Your target symbols
        symbols = ["RELIANCE", "TCS", "INFY", "SBIN", "ADANIENT"]
        fresh_data = []

        print("📡 Fetching fresh Watchlist data from Angel One...")
        for symbol in symbols:
            try:
                # --- CRITICAL FIX: THE RATE LIMITER ---
                # Pauses the loop for 0.4 seconds to stay under 3 requests/sec limit
                time.sleep(0.4) 
                
                df = self.fetcher.get_enriched_data(symbol, mode="intraday")
                
                if df is not None and not df.empty:
                    last_close = float(df['close'].iloc[-1])
                    prev_close = float(df['close'].iloc[-2]) if len(df) > 1 else last_close
                    pct_change = ((last_close - prev_close) / prev_close) * 100
                    rsi = float(df['rsi'].iloc[-1]) if 'rsi' in df.columns else 50.0
                    
                    fresh_data.append({
                        "symbol": symbol,
                        "current_price": last_close,
                        "change_pct": pct_change,
                        "rsi": rsi,
                        "status": "BULLISH" if pct_change > 0 else "BEARISH"
                    })
            except Exception as e:
                print(f"⚠️ Skipping {symbol} due to API rate limit: {e}")

        # 3. Save to cache
        if fresh_data:
            self.cached_data = fresh_data
            self.last_update_time = current_time

        return self.cached_data