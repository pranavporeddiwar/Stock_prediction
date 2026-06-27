import os
import asyncio
from fastapi import FastAPI, Query, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore

# --- INTERNAL NEURAL SERVICES ---
from app.services.data_fetcher import DataFetcher
from app.services.prediction_service import PredictionService
from app.services.watchlist_service import WatchlistService
from app.services.ai_agent import get_hybrid_prediction
from app.services.backtest_service import perform_strategy_simulation  # 🔬 NEW: Backtest Engine Import

# --- FIREBASE SETUP ---
def init_firebase():
    try:
        cred = credentials.Certificate("/etc/secrets/serviceAccountKey.json") if os.path.exists("/etc/secrets/serviceAccountKey.json") else credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
        return firestore.client()
    except Exception as e:
        print(f"❌ Firebase Init Error: {e}")
        return None

db = init_firebase()
app = FastAPI(title="Neural Stream Backend")

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# Services initialization
data_fetcher = DataFetcher()
prediction_engine = PredictionService()
watchlist_manager = WatchlistService(fetcher_instance=data_fetcher)

# ==========================================
# 🩺 CLOUD HEALTH CHECK
# ==========================================
@app.get("/health-check")
async def health_check():
    return {
        "status": "operational" if (data_fetcher.api and prediction_engine.model and db) else "degraded",
        "nodes": {"broker": bool(data_fetcher.api), "ai_engine": bool(prediction_engine.model), "cloud_db": bool(db)},
        "timestamp": datetime.now().isoformat()
    }

# ==========================================
# 🧠 PRIMARY AI PREDICTION ENDPOINT
# ==========================================
@app.get("/predict")
async def get_prediction(symbol: str = Query(...)):
    df = await asyncio.to_thread(data_fetcher.get_enriched_data, symbol)
    if df is None or df.empty: 
        raise HTTPException(status_code=404, detail="Data unavailable")
    
    current_price = float(df['close'].iloc[-1])
    lstm_future = prediction_engine.generate_forecast(df)
    ai_analysis = get_hybrid_prediction(symbol, df, float(df['rsi'].iloc[-1]), lstm_future)

    response = {
        "symbol": symbol.upper(), "current_price": current_price,
        "history": df.tail(60).to_dict(orient="records"),
        "future_path": lstm_future, "action": ai_analysis.get("action", "HOLD"),
        "reasoning": ai_analysis.get("reasoning", "Analyzing..."),
        "target_price": ai_analysis.get("target_price", current_price * 1.02),
        "stop_loss": ai_analysis.get("stop_loss", current_price * 0.98),
        "sentiment": 0.72
    }
    return response

# ==========================================
# 🔬 BACKTEST STRATEGY LAB ENDPOINT
# ==========================================
@app.get("/backtest/{symbol}")
async def run_backtest(symbol: str):
    print(f"🔬 Running Strategy Simulation for {symbol.upper()}...")
    df = await asyncio.to_thread(data_fetcher.get_enriched_data, symbol)
    
    if df is None or df.empty:
        raise HTTPException(status_code=404, detail=f"Market data unavailable for {symbol.upper()}")
    
    try:
        # Run the historical data through the simulation engine
        report = perform_strategy_simulation(df, prediction_engine)
        
        # Attach the symbol to the payload for frontend context
        report["symbol"] = symbol.upper()
        
        return report
    except Exception as e:
        print(f"❌ Backtest Engine Error: {e}")
        raise HTTPException(status_code=500, detail="Internal simulation error")

# ==========================================
# ⚡ WEBSOCKET LIVE STREAM
# ==========================================
@app.websocket("/ws/live/{symbol}")
async def live_stock_stream(websocket: WebSocket, symbol: str):
    await websocket.accept()
    try:
        while True:
            df = await asyncio.to_thread(data_fetcher.get_enriched_data, symbol)
            if df is not None:
                await websocket.send_json({
                    "current_price": float(df['close'].iloc[-1]),
                    "history": df.tail(60).to_dict(orient="records"),
                    "rsi": float(df['rsi'].iloc[-1])
                })
            await asyncio.sleep(5)
    except WebSocketDisconnect: 
        pass