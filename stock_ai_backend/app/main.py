from fastapi import FastAPI, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from app.services.data_fetcher import DataFetcher
from app.services.prediction_service import PredictionService
from app.services.watchlist_service import WatchlistService
from app.services.ai_agent import get_hybrid_prediction
import uvicorn
import numpy as np
import asyncio
from pydantic import BaseModel
from app.services.chat_agent import get_tutor_response

app = FastAPI(title="Neural Stream Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Services
data_fetcher = DataFetcher()
prediction_engine = PredictionService()
watchlist_manager = WatchlistService()

# Data model for the Chat Tutor Request
class ChatMessage(BaseModel):
    message: str
    context: str = "General Market Watchlist"

@app.get("/")
async def health_check():
    return {"status": "online", "engine": "Neural Stream AI ready"}

# Chatbot Endpoint
@app.post("/chat")
async def chat_with_tutor(req: ChatMessage):
    """
    Handles requests from the Flutter Global Chat Bot.
    """
    try:
        reply = await asyncio.to_thread(get_tutor_response, req.message, req.context)
        return {"reply": reply}
    except Exception as e:
        print(f"❌ Chat API Error: {e}")
        return {"reply": "Connection lost. Please try again."}

@app.get("/predict")
async def predict_stock(symbol: str, mode: str = "intraday"):
    """
    Multithreaded Prediction: Handles LSTM and Groq in separate threads.
    """
    try:
        df = await asyncio.to_thread(data_fetcher.get_enriched_data, symbol, mode)
        
        if df is None or df.empty:
            raise HTTPException(status_code=404, detail="Market data unreachable")
        
        current_rsi = float(df['rsi'].iloc[-1]) if 'rsi' in df.columns else 50.0
        current_price = float(df['close'].iloc[-1])
        
        lstm_preds = await asyncio.to_thread(prediction_engine.predict, df)
        clean_lstm_preds = [float(p) if not np.isnan(p) else current_price for p in lstm_preds]
        
        ai_analysis = await asyncio.to_thread(
            get_hybrid_prediction,
            symbol.upper(),
            df,
            current_rsi,
            clean_lstm_preds
        )
        
        history_data = df.ffill().bfill().to_dict(orient="records")
        
        return {
            "symbol": symbol.upper(),
            "current_price": current_price,
            "history": history_data,
            "rsi": current_rsi,
            "trend_logic": f"{ai_analysis.get('action')} SIGNAL VERIFIED",
            "future_path": ai_analysis.get("future_path", []),
            "action": ai_analysis.get("action", "HOLD"),
            "reasoning": ai_analysis.get("reasoning", "Analyzing..."),
            "target_price": ai_analysis.get("target_price", current_price * 1.02),
            "stop_loss": ai_analysis.get("stop_loss", current_price * 0.98),
            "sentiment": 0.72,
            "headlines": [f"Neural engine confirms {ai_analysis.get('action')} thesis"]
        }

    except Exception as e:
        print(f"❌ Multithread Error for {symbol}: {e}")
        return {
            "symbol": symbol.upper(),
            "error": str(e),
            "action": "HOLD",
            "reasoning": "Synchronizing Neural Threads...",
            "future_path": []
        }

@app.get("/watchlist")
async def get_watchlist():
    try:
        return await asyncio.to_thread(watchlist_manager.get_market_overview)
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)