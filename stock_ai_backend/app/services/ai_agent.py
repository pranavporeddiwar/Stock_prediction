import json
import os
from groq import Groq
from datetime import datetime, timedelta
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

client = Groq(api_key=os.getenv("GROQ_API_KEY"))

def get_hybrid_prediction(stock_symbol, ohlc_data, rsi_value, lstm_predictions):
    """
    Advanced Neural Logic: Orchestrates LSTM trend data with 
    Llama-3 reasoning to assign Candlestick Patterns and Risk Metrics.
    """
    
    # 1. Extract Professional Metrics
    last_close = float(ohlc_data['close'].iloc[-1])
    atr = float(ohlc_data['atr'].iloc[-1]) if 'atr' in ohlc_data.columns else (last_close * 0.01)
    ema_20 = float(ohlc_data['ema_20'].iloc[-1]) if 'ema_20' in ohlc_data.columns else last_close
    
    # 2. Time-Sync the Matrix
    now = datetime.now()
    current_time_str = now.strftime('%Y-%m-%d %I:%M %p')
    
    # Extract raw prices from the LSTM path
    lstm_prices = []
    if isinstance(lstm_predictions, list) and len(lstm_predictions) > 0:
        if isinstance(lstm_predictions[0], dict):
            lstm_prices = [round(p.get("close", last_close), 2) for p in lstm_predictions]
        else:
            lstm_prices = lstm_predictions
            
    # We feed the first 10 steps to the LLM to keep response time lightning-fast
    short_lstm_prices = lstm_prices[:10]
            
    # 3. The 3-Pillar Prompt (Fundamentals + Math + Patterns)
    prompt = f"""
    [INST] System: You are a helpful, beginner-friendly AI Trading Tutor for {stock_symbol}.
    
    MARKET STATE:
    - Current Time: {current_time_str}
    - Current Price: ₹{last_close:.2f}
    - 20-period EMA: ₹{ema_20:.2f}
    - RSI (Wilder's): {rsi_value:.2f}
    
    LSTM FORECAST (Next 10 prices, stepping by 15-minutes each):
    {short_lstm_prices}
    
    YOUR TASK:
    1. Look at the LSTM Forecast prices. Find the best price to enter the trade (lowest for BUY, highest for SELL).
    2. Write a "reasoning" explanation that is EXTREMELY SIMPLE for a total beginner, stating the EXACT DATE AND TIME to execute.
    3. CANDLESTICK TAGGING: Look at the sequence of forecasted prices. Assign a logical candlestick pattern (e.g., "Hammer", "Doji", "Bull Engulfing", "Marubozu", "Shooting Star") and a risk level ("Low risk", "Med risk", "High risk") to EACH of those price steps that explains how it would reach that value.
    
    OUTPUT FORMAT (Strict JSON):
    {{
        "action": "BUY" | "SELL" | "HOLD",
        "reasoning": "Simple explanation with EXACT execution date and time...",
        "target_price": float,
        "stop_loss": float,
        "enriched_forecast": [
            {{"close": float, "pattern": "string", "risk": "string"}}
        ]
    }}
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
            model="llama-3.3-70b-versatile", 
            temperature=0.1, 
            response_format={"type": "json_object"}
        )
        
        # Parse the JSON response
        raw_content = chat_completion.choices[0].message.content
        result = json.loads(raw_content)
        
        # 4. Merge the LLM's pattern analysis with the full LSTM math path
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
                # Math extrapolation for remaining nodes beyond the first 10
                risk = "High risk" if i > 5 else "Med risk"
                final_future_path.append({
                    "close": price,
                    "pattern": "Trend Continuation",
                    "risk": risk
                })
                
        # Attach the perfectly fused array to the result
        result["future_path"] = final_future_path
        
        return result
        
    except Exception as e:
        print(f"❌ Neural Engine Fault: {e}")
        # Structured fallback matrix
        fallback_path = [{"close": p, "pattern": "Standard", "risk": "Med risk"} for p in lstm_prices]
        return {
            "action": "HOLD",
            "reasoning": "Neural synchronization in progress. Waiting for optimal market timing...",
            "target_price": last_close * 1.02,
            "stop_loss": last_close * 0.98,
            "future_path": fallback_path
        }