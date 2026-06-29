import json
import os
from groq import Groq
from datetime import datetime, timedelta
from dotenv import load_dotenv
load_dotenv()
client = Groq(api_key=os.getenv("GROQ_API_KEY"))
def get_hybrid_prediction(stock_symbol, ohlc_data, rsi_value, lstm_predictions):
    last_close = float(ohlc_data['close'].iloc[-1])
    atr = float(ohlc_data['atr'].iloc[-1]) if 'atr' in ohlc_data.columns else (last_close * 0.01)
    ema_20 = float(ohlc_data['ema_20'].iloc[-1]) if 'ema_20' in ohlc_data.columns else last_close
    volume_avg = float(ohlc_data['volume'].tail(20).mean()) if 'volume' in ohlc_data.columns else 0
    volatility = (atr / last_close) * 100
    now = datetime.now()
    current_time_str = now.strftime('%Y-%m-%d %I:%M %p IST')
    today = now.date()
    weekday = now.weekday()
    if weekday >= 4:
        days_ahead = 7 - weekday
        next_trading_day = today + timedelta(days=days_ahead)
    else:
        next_trading_day = today + timedelta(days=1)
    next_market_open = f"{next_trading_day} 09:15 AM IST"
    next_market_close = f"{next_trading_day} 03:30 PM IST"
    lstm_prices = []
    if isinstance(lstm_predictions, list) and len(lstm_predictions) > 0:
        if isinstance(lstm_predictions[0], dict):
            lstm_prices = [round(p.get("close", last_close), 2) for p in lstm_predictions]
        else:
            lstm_prices = lstm_predictions
    short_lstm_prices = lstm_prices[:10]
    prompt = f"""
    [INST] System: You are a helpful, beginner-friendly AI Trading Tutor for {stock_symbol}.
    MARKET STATE:
    - Current Time: {current_time_str}
    - Current Price: Rs.{last_close:.2f}
    - 20-period EMA: Rs.{ema_20:.2f}
    - RSI (Wilder's): {rsi_value:.2f}
    - ATR: Rs.{atr:.2f} (Volatility: {volatility:.2f}%)
    - Avg Volume (20): {volume_avg:.0f}
    - Next Market Session: {next_market_open} to {next_market_close}
    LSTM FORECAST (Next 10 prices, stepping by 15-minutes each):
    {short_lstm_prices}
    YOUR TASK:
    1. Look at the LSTM Forecast prices. Find the best price to enter the trade (lowest for BUY, highest for SELL).
    2. Provide EXACT buy_time and sell_time in "YYYY-MM-DD HH:MM AM/PM IST" format. Calculate this using the 15-minute intervals from current time. These must be within next trading session hours (9:15 AM - 3:30 PM IST, Mon-Fri only).
    3. Write a "reasoning" explanation that is EXTREMELY SIMPLE for a total beginner, stating the EXACT DATE AND TIME to execute.
    4. TRADING STYLE: Based on the volatility ({volatility:.2f}%), RSI ({rsi_value:.2f}), and forecast trend, recommend one trading style:
       - "Scalping" if volatility > 2% and RSI is extreme (>70 or <30)
       - "Intraday" if moderate volatility and clear directional trend
       - "Swing" if trend spans multiple days with good support/resistance
       - "Positional" if strong fundamental trend over weeks
       Include a short reason WHY this style suits this stock.
    5. RISK LEVEL: "Low" if ATR < 1% of price, "Medium" if 1-2%, "High" if > 2%.
    6. CANDLESTICK TAGGING: Look at the sequence of forecasted prices. Assign a logical candlestick pattern and a risk level to EACH of those price steps.
    OUTPUT FORMAT (Strict JSON):
    {
        "action": "BUY" | "SELL" | "HOLD",
        "reasoning": "Simple explanation with EXACT execution date and time...",
        "target_price": float,
        "stop_loss": float,
        "buy_time": "YYYY-MM-DD HH:MM AM IST",
        "sell_time": "YYYY-MM-DD HH:MM AM IST",
        "trading_style": "Scalping" | "Intraday" | "Swing" | "Positional",
        "style_reason": "Short explanation why this style suits this stock...",
        "risk_level": "Low" | "Medium" | "High",
        "enriched_forecast": [
            { "close": float, "pattern": "string", "risk": "string"}
        ]
    }
    [/INST]
    """
    try:
        chat_completion = client.chat.completions.create(
            messages=[
                {
                    "role": "system",
                    "content": "You are a specialized Financial AI that only outputs structured JSON."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            model="llama-3.1-8b-instant",
            temperature=0.3,
            max_tokens=600,
            response_format={"type": "json_object"}
        )
        raw_content = chat_completion.choices[0].message.content
        result = json.loads(raw_content)
        final_future_path = []
        enriched = result.get("enriched_forecast", [])
        for i, price in enumerate(lstm_prices):
            if i < len(enriched):
                final_future_path.append({
                    "close": price,
                    "pattern": enriched[i].get("pattern", "Standard"),
                    "risk": enriched[i].get("risk", "Low risk")
                })
            else:
                risk = "High risk" if i > 5 else "Med risk"
                final_future_path.append({
                    "close": price,
                    "pattern": "Trend Continuation",
                    "risk": risk
                })
        result["future_path"] = final_future_path
        result.setdefault("buy_time", next_market_open)
        result.setdefault("sell_time", next_market_close)
        result.setdefault("trading_style", "Intraday")
        result.setdefault("style_reason", "Default intraday strategy based on current market conditions.")
        result.setdefault("risk_level", "Medium")
        return result
    except Exception as e:
        print(f"[ERROR] Neural Engine Fault: {e}")
        fallback_path = [{"close": p, "pattern": "Standard", "risk": "Med risk"} for p in lstm_prices]
        return {
            "action": "HOLD",
            "reasoning": "Neural synchronization in progress. Waiting for optimal market timing...",
            "target_price": last_close * 1.02,
            "stop_loss": last_close * 0.98,
            "buy_time": next_market_open,
            "sell_time": next_market_close,
            "trading_style": "Intraday",
            "style_reason": "Default strategy while AI engine recalibrates.",
            "risk_level": "Medium",
            "future_path": fallback_path
        }
