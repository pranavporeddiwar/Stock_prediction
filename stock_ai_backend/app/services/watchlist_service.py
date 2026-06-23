import asyncio
import time
from app.services.data_fetcher import DataFetcher

class WatchlistService:
    def __init__(self, fetcher_instance=None):
        # Bind the shared Singleton DataFetcher instance to avoid multiple sessions
        self.fetcher = fetcher_instance if fetcher_instance else DataFetcher()
        
        # --- HIGH-PERFORMANCE CACHING SYSTEM ---
        self.cached_data = []
        self.last_update_time = 0
        self.cache_duration = 60  # Cache duration remains 60 seconds

    async def get_market_overview(self):
        """
        Asynchronously fetches the watchlist overview.
        Utilizes non-blocking async sleep to respect broker rate limits safely.
        """
        current_time = time.time()
        
        # 1. Evaluate cache status first to save internal compute and API weight
        if current_time - self.last_update_time < self.cache_duration and self.cached_data:
            print("⚡ Watchlist Performance Cache: HIT")
            return self.cached_data

        # 2. Define our asset matrix
        symbols = ["RELIANCE", "TCS", "INFY", "SBIN", "ADANIENT"]
        fresh_data = []

        print("📡 Watchlist Engine: Initializing asynchronous, non-blocking fetch pipeline...")
        
        for symbol in symbols:
            try:
                # 👇 CRITICAL ARCHITECTURAL FIX: Non-blocking async rate limiter
                # This yields thread control back to FastAPI's loop while waiting,
                # allowing other endpoints or chat messages to handle instantly.
                await asyncio.sleep(0.4) 
                
                # Fetching broker data inside an external worker thread pool cleanly
                df = await asyncio.to_thread(self.fetcher.get_enriched_data, symbol, mode="intraday")
                
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
                print(f"⚠️ Watchlist Matrix Exception for {symbol}: {e}")

        # 3. Commit fresh telemetry states to memory cache
        if fresh_data:
            self.cached_data = fresh_data
            self.last_update_time = current_time

        return fresh_data