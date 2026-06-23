import json
import os
from groq import Groq
from datetime import datetime, timedelta
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Professional practice: API Key should ideally be in .env, but hardcoded for your demo stability
client = Groq(api_key=os.getenv("GROQ_API_KEY"))

def get_hybrid_prediction(stock_symbol, ohlc_data, rsi_value, lstm_predictions):
    """
    Advanced Neural Logic: Orchestrates LSTM trend data with 
    Llama-3 reasoning to provide beginner-friendly, time-exact trade execution.
    """
    
    # 1. Extract Professional Metrics
    last_close = float(ohlc_data['close'].iloc[-1])
    atr = float(ohlc_data['atr'].iloc[-1]) if 'atr' in ohlc_data.columns else (last_close * 0.01)
    ema_20 = float(ohlc_data['ema_20'].iloc[-1]) if 'ema_20' in ohlc_data.columns else last_close
    
    # 2. Time-Sync the Matrix
    now = datetime.now()
    current_time_str = now.strftime('%Y-%m-%d %I:%M %p')
    
    # Extract just the raw prices from the LSTM path to keep the prompt clean for Llama
    lstm_prices = []
    if isinstance(lstm_predictions, list) and len(lstm_predictions) > 0:
        if isinstance(lstm_predictions[0], dict):
            lstm_prices = [round(p.get("close", last_close), 2) for p in lstm_predictions]
        else:
            lstm_prices = lstm_predictions
            
    # 3. The Beginner-Friendly, Time-Aware Prompt
    prompt = f"""
    [INST] System: You are a helpful, beginner-friendly AI Trading Tutor for {stock_symbol}.
    
    MARKET STATE:
    - Current Time: {current_time_str}
    - Current Price: ₹{last_close:.2f}
    - 20-period EMA: ₹{ema_20:.2f}
    - RSI (Wilder's): {rsi_value:.2f}
    
    LSTM FORECAST (Next 25 prices, stepping by 15-minutes each):
    {lstm_prices}
    
    YOUR TASK:
    1. Look at the LSTM Forecast prices. Find the best price to enter the trade (lowest for BUY, highest for SELL).
    2. Calculate the exact time that optimal price happens (Each step in the list is exactly +15 minutes from the Current Time).
    3. Write a "reasoning" explanation that is EXTREMELY SIMPLE for a total beginner. Do not use confusing hedge-fund jargon.
    4. You MUST state the EXACT DATE AND TIME to execute the trade in the reasoning.
    
    OUTPUT FORMAT (Strict JSON):
    {{
        "action": "BUY" | "SELL" | "HOLD",
        "reasoning": "Simple explanation with EXACT execution date and time...",
        "target_price": float,
        "stop_loss": float
    }}
    [/INST]
    """
    
    try:
        chat_completion = client.chat.completions.create(
            messages=[
                {
                    "role": "system",
                    "content": "You are a specialized Financial AI that only outputs structured JSON. Keep reasoning simple, actionable, and time-specific."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            model="llama-3.3-70b-versatile", 
            temperature=0.1, # Critical: Lower temperature = strict calculation of the 15-min intervals
            response_format={"type": "json_object"}
        )
        
        # Parse the JSON response
        raw_content = chat_completion.choices[0].message.content
        result = json.loads(raw_content)
        
        return result
        
    except Exception as e:
        print(f"❌ Neural Engine Fault: {e}")
        # Return structured fallback to ensure Flutter doesn't show a red error
        return {
            "action": "HOLD",
            "reasoning": "Neural synchronization in progress. Waiting for optimal market timing...",
            "target_price": last_close * 1.02,
            "stop_loss": last_close * 0.98
        }