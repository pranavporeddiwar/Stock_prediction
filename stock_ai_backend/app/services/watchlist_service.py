import asyncio
import time
from app.services.data_fetcher import DataFetcher
class WatchlistService:
    def __init__(self, fetcher_instance=None):
        self.fetcher = fetcher_instance if fetcher_instance else DataFetcher()
        self.cached_data = []
        self.last_update_time = 0
        self.cache_duration = 60
    async def get_market_overview(self):
        current_time = time.time()
        if current_time - self.last_update_time < self.cache_duration and self.cached_data:
            print(" Watchlist Performance Cache: HIT")
            return self.cached_data
        symbols = ["RELIANCE", "TCS", "INFY", "SBIN", "ADANIENT"]
        fresh_data = []
        print(" Watchlist Engine: Initializing asynchronous, non-blocking fetch pipeline...")
        for symbol in symbols:
            try:
                await asyncio.sleep(0.4)
                df = await asyncio.to_thread(self.fetcher.get_enriched_data, symbol, mode="intraday")
                if df is not None and not df.empty:
                    last_close = float(df['close'].iloc[-1])
                    prev_close = float(df['close'].iloc[-2]) if len(df) > 1 else last_close
                    pct_change = ((last_close - prev_close) / prev_close) * 100
                    rsi = float(df['rsi'].iloc[-1]) if 'rsi' in df.columns else 50.0
                    atr = float(df['atr'].iloc[-1]) if 'atr' in df.columns else 0
                    volatility = (atr / last_close) * 100 if last_close > 0 else 0
                    if volatility > 2.0 and (rsi > 70 or rsi < 30):
                        trading_style = "Scalping"
                        style_reason = f"High volatility ({volatility:.1f}%) with extreme RSI ({rsi:.0f}) creates quick profit opportunities."
                    elif volatility > 1.0 and 30 < rsi < 70:
                        trading_style = "Intraday"
                        style_reason = f"Moderate volatility ({volatility:.1f}%) with balanced RSI ({rsi:.0f}) suits same-day trades."
                    elif 0.5 < volatility <= 1.5:
                        trading_style = "Swing"
                        style_reason = f"Steady trend with {volatility:.1f}% volatility. Hold 2-5 days for optimal returns."
                    else:
                        trading_style = "Positional"
                        style_reason = f"Low volatility ({volatility:.1f}%) suggests a stable long-term trend. Hold for weeks."
                    fresh_data.append({
                        "symbol": symbol,
                        "current_price": last_close,
                        "change_pct": round(pct_change, 2),
                        "rsi": round(rsi, 1),
                        "volatility": round(volatility, 2),
                        "trading_style": trading_style,
                        "style_reason": style_reason,
                        "status": "BULLISH" if pct_change > 0 else "BEARISH"
                    })
            except Exception as e:
                print(f" Watchlist Matrix Exception for {symbol}: {e}")
        if fresh_data:
            self.cached_data = fresh_data
            self.last_update_time = current_time
        return fresh_data
