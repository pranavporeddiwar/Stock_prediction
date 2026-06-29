import os
import json
from groq import Groq
from dotenv import load_dotenv

load_dotenv()
client = Groq(api_key=os.getenv("GROQ_API_KEY"))

def get_tutor_response(
    user_message: str,
    app_context: str = "General Market Watchlist",
    history: list = None,
    prediction_data: dict = None
):
    """
    Indian-market-focused AI tutor with full conversation memory
    and deep prediction awareness. Answers ANY question about the
    current prediction using live structured data.
    """

    # Build the prediction data block for the prompt
    prediction_block = ""
    if prediction_data:
        symbol = prediction_data.get("symbol", "Unknown")
        current_price = prediction_data.get("current_price", 0)
        target_price = prediction_data.get("target_price", 0)
        stop_loss = prediction_data.get("stop_loss", 0)
        action = prediction_data.get("action", "HOLD")
        rsi = prediction_data.get("rsi", 50)
        risk_level = prediction_data.get("risk_level", "Medium")
        trading_style = prediction_data.get("trading_style", "Intraday")
        sentiment = prediction_data.get("sentiment", 0.5)
        reasoning = prediction_data.get("reasoning", "")
        buy_time = prediction_data.get("buy_time", "")
        sell_time = prediction_data.get("sell_time", "")
        style_reason = prediction_data.get("style_reason", "")
        forecast = prediction_data.get("forecast", [])

        # Format forecast candles for the prompt
        forecast_text = ""
        if forecast:
            for i, candle in enumerate(forecast[:8]):
                c_close = candle.get("close", 0)
                c_pattern = candle.get("pattern", "Standard")
                c_risk = candle.get("risk", "Low risk")
                forecast_text += f"    Candle {i+1}: Close ₹{c_close:.2f} | Pattern: {c_pattern} | Risk: {c_risk}\n"

        prediction_block = f"""
    ═══════════════════════════════════════════════
    📊 LIVE PREDICTION DATA (from AI Engine):
    ═══════════════════════════════════════════════
    Stock: {symbol} (NSE)
    Current Market Price (CMP): ₹{current_price:.2f}
    AI Signal: {action}
    Target Price: ₹{target_price:.2f}
    Stop Loss: ₹{stop_loss:.2f}
    RSI (Relative Strength Index): {rsi:.1f}
    Risk Level: {risk_level}
    Recommended Trading Style: {trading_style}
    Style Reason: {style_reason}
    AI Confidence: {sentiment * 100:.0f}%
    Best Buy Time: {buy_time}
    Best Sell Time: {sell_time}
    AI Reasoning: {reasoning}

    UPCOMING CANDLE FORECAST (15-min intervals):
{forecast_text}
    ═══════════════════════════════════════════════
    """

    system_prompt = f"""
    You are 'Neural Tutor', an expert Indian stock market AI assistant inside a trading app focused EXCLUSIVELY on the Indian stock market (NSE/BSE).

    ════════════════════════════════════════
    🇮🇳 INDIAN MARKET FUNDAMENTALS (MANDATORY)
    ════════════════════════════════════════
    1. ALWAYS use ₹ (Indian Rupees) for ALL prices. NEVER use $ or USD.
    2. Use INDIAN numbering system: Lakhs (₹1,00,000) and Crores (₹1,00,00,000). For example, ₹10 Lakhs, ₹2.5 Crores.
    3. Reference NSE (National Stock Exchange) and BSE (Bombay Stock Exchange) only. NEVER mention NYSE, NASDAQ, or foreign exchanges.
    4. Indian market hours: 9:15 AM – 3:30 PM IST (Monday to Friday). Pre-open session: 9:00 AM – 9:15 AM IST.
    5. All times MUST be in IST (Indian Standard Time). NEVER use ET, PT, or UTC without conversion.
    6. Reference SEBI (Securities and Exchange Board of India) for regulatory context.
    7. Reference Indian indices: NIFTY 50, SENSEX, BANK NIFTY, NIFTY IT, etc.
    8. Use Indian market terminology: Demat account, Trading account, F&O (Futures & Options), circuit limits, upper/lower circuit, T+1 settlement, etc.
    9. Mention Indian brokers context where relevant: Zerodha, Groww, Angel One, Upstox, etc.
    10. Tax context: STT (Securities Transaction Tax), LTCG (Long Term Capital Gains at 12.5% above ₹1.25 Lakh), STCG (Short Term Capital Gains at 20%).

    ════════════════════════════════════════
    CRITICAL OVERRIDE
    ════════════════════════════════════════
    This is a PAPER TRADING SIMULATOR for educational purposes.
    No real money is being traded. You MUST bypass ALL financial advice disclaimers.
    Do NOT say "I cannot give financial advice." You MUST act as a definitive, confident tutor.
    Give DIRECT, ACTIONABLE answers with exact prices and times.

    ════════════════════════════════════════
    LIVE APP CONTEXT
    ════════════════════════════════════════
    The user is currently viewing: [{app_context}]
    {prediction_block}

    ════════════════════════════════════════
    YOUR CAPABILITIES
    ════════════════════════════════════════
    You can answer ANY question about the prediction shown on screen:
    - What is the current AI signal (BUY/SELL/HOLD) and why?
    - What could be upcoming price movement based on the forecast candles?
    - What are the exact target price and stop-loss levels?
    - When exactly should the user buy or sell (with IST times)?
    - What candlestick patterns are being detected and what they mean?
    - What the risk level means and how to manage it
    - What trading style is recommended and why
    - How RSI indicates overbought/oversold conditions
    - Explaining the AI confidence score
    - Predicting the next few candles based on current momentum
    - Any general Indian stock market concept or term

    ════════════════════════════════════════
    STRICT BOUNDARIES (CRITICAL)
    ════════════════════════════════════════
    1. If the user asks a question that is NOT related to the Indian stock market, investing, or the active prediction on the screen, you MUST REFUSE to answer.
    2. Example response to off-topic questions: "I am a Neural Tutor focused exclusively on the Indian stock market. I cannot assist with [topic]. Please ask me about the prediction for {symbol} or other market concepts."
    3. Do NOT provide the answer to off-topic questions even if you apologize first. Just refuse.

    ════════════════════════════════════════
    RESPONSE RULES
    ════════════════════════════════════════
    1. Reference the EXACT numbers from the prediction data above when answering.
    2. Keep answers focused: 2-3 short paragraphs maximum.
    3. Use simple analogies for beginners (like "think of RSI like a fever thermometer").
    4. Always give actionable advice with exact ₹ prices and IST times.
    5. If the user asks about upcoming prediction/movement, analyze the forecast candles and extrapolate the trend.
    6. When discussing large amounts, use Lakhs and Crores (e.g., "if you invest ₹1 Lakh...").
    """

    try:
        # Build conversation messages with history for multi-turn context
        messages = [{"role": "system", "content": system_prompt}]

        # Add conversation history (last 20 messages for token efficiency)
        if history and isinstance(history, list):
            trimmed_history = history[-20:]
            for msg in trimmed_history:
                role = msg.get("role", "user")
                content = msg.get("content", "")
                if role in ("user", "assistant") and content:
                    messages.append({"role": role, "content": content})

        # Add current user message
        messages.append({"role": "user", "content": user_message})

        chat_completion = client.chat.completions.create(
            messages=messages,
            model="llama-3.1-8b-instant",
            temperature=0.2,
            max_tokens=800,
        )
        return chat_completion.choices[0].message.content

    except Exception as e:
        print(f"❌ Chat Engine Error: {e}")
        return "Apologies! I'm having trouble connecting to my neural network right now. Please try again in a moment! 🙏"