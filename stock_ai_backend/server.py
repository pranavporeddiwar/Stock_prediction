import os
import asyncio
import subprocess
from fastapi import FastAPI, Query, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore
from contextlib import asynccontextmanager

# --- INTERNAL NEURAL SERVICES ---
from app.services.data_fetcher import DataFetcher
from app.services.prediction_service import PredictionService
from app.services.watchlist_service import WatchlistService
from app.services.ai_agent import get_hybrid_prediction
from app.services.backtest_service import perform_strategy_simulation

# --- SCHEDULER & TIMEZONE ENGINES ---
from apscheduler.schedulers.background import BackgroundScheduler
from pytz import timezone

# --- FIREBASE SETUP ---
def init_firebase():
    try:
        cred = credentials.Certificate("/etc/secrets/serviceAccountKey.json") if os.path.exists("/etc/secrets/serviceAccountKey.json") else credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
        return firestore.client()
    except Exception as e:
        print(f"❌ Firebase Init Error: {e}")
        return None

# ==========================================
# ⏰ PRE-MARKET ML TRAINING SCHEDULER
# ==========================================
def run_daily_ml_training():
    """
    Fires automatically before market open (08:30 AM IST).
    Triggers global_train.py in a detached background subprocess.
    """
    print(f"[{datetime.now()}] ⚙️ CRON TRIGGERED: Starting pre-market ML training sequence...")
    try:
        # Runs the script contextually in the background without locking application async workers
        subprocess.Popen(["python", "global_train.py"])
        print("✅ Pre-market training initiated. Model will be ready before 9:15 AM.")
    except Exception as e:
        print(f"❌ Automated Training Failed: {e}")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # --- STARTUP LOGIC ---
    print("☁️ Initializing Pre-Market Scheduler (IST Timezone)...")
    ist_tz = timezone('Asia/Kolkata')
    scheduler = BackgroundScheduler(timezone=ist_tz)
    
    # Schedule Matrix: Execute Monday through Friday at 08:30 AM IST
    scheduler.add_job(
        run_daily_ml_training, 
        'cron', 
        day_of_week='mon-fri', 
        hour=8, 
        minute=30
    )
    scheduler.start()
    print("✅ Pre-Market AI Scheduler Online (08:30 AM Mon-Fri)")
    
    yield # Application Context Boundary (API runs here)
    
    # --- SHUTDOWN LOGIC ---
    scheduler.shutdown()
    print("💤 Pre-Market AI Scheduler Safely Offline.")

# ==========================================
# 🚀 CORE WEB INTERFACE INSTANTIATION
# ==========================================
# Instantiated once with lifespan attached cleanly
app = FastAPI(title="Neural Stream Backend", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware, 
    allow_origins=["*"], 
    allow_methods=["*"], 
    allow_headers=["*"]
)

# Connect Datastore Node
db = init_firebase()

# Services initialization
data_fetcher = DataFetcher()
prediction_engine = PredictionService()
watchlist_manager = WatchlistService(fetcher_instance=data_fetcher)

# ==========================================
# 🩺 CLOUD HEALTH CHECK
# ==========================================
@app.get("/health-check")
async def health_check():
    broker_alive = await asyncio.to_thread(data_fetcher.is_session_alive)
    return {
        "status": "operational" if (broker_alive and prediction_engine.model and db) else "degraded",
        "nodes": {"broker": broker_alive, "ai_engine": bool(prediction_engine.model), "cloud_db": bool(db)},
        "timestamp": datetime.now().isoformat()
    }

# ==========================================
# 📋 WATCHLIST TELEMETRY ENDPOINT
# ==========================================
@app.get("/watchlist")
async def sync_watchlist():
    try:
        # Use the enriched market overview with trading styles and technicals
        data = await watchlist_manager.get_market_overview()
        if data:
            return data  # Returns list of {symbol, current_price, change_pct, rsi, volatility, trading_style, ...}
        else:
            # Fallback if no enriched data available
            return [
                {"symbol": "SBIN", "current_price": 0, "change_pct": 0, "rsi": 50, "volatility": 0, "trading_style": "Intraday", "style_reason": "Loading...", "status": "NEUTRAL"},
                {"symbol": "RELIANCE", "current_price": 0, "change_pct": 0, "rsi": 50, "volatility": 0, "trading_style": "Swing", "style_reason": "Loading...", "status": "NEUTRAL"},
                {"symbol": "TCS", "current_price": 0, "change_pct": 0, "rsi": 50, "volatility": 0, "trading_style": "Positional", "style_reason": "Loading...", "status": "NEUTRAL"},
                {"symbol": "HDFCBANK", "current_price": 0, "change_pct": 0, "rsi": 50, "volatility": 0, "trading_style": "Intraday", "style_reason": "Loading...", "status": "NEUTRAL"},
                {"symbol": "INFY", "current_price": 0, "change_pct": 0, "rsi": 50, "volatility": 0, "trading_style": "Swing", "style_reason": "Loading...", "status": "NEUTRAL"},
            ]
    except Exception as e:
        print(f"❌ Watchlist Error: {e}")
        raise HTTPException(status_code=500, detail="Failed to sync watchlist telemetry matrix")

# ==========================================
# 🧠 PRIMARY AI PREDICTION ENDPOINT
# ==========================================
@app.get("/predict")
async def get_prediction(symbol: str = Query(...)):
    # Check broker connectivity first
    if not data_fetcher.api:
        raise HTTPException(status_code=503, detail="Broker session offline. Reconnecting...")
    
    # Check if symbol exists in the lookup table
    query = symbol.upper().strip()
    if not data_fetcher.symbols_lut.empty:
        match = data_fetcher.symbols_lut[
            (data_fetcher.symbols_lut['symbol'].str.upper() == query) | 
            (data_fetcher.symbols_lut['symbol'].str.upper() == f"{query}-EQ")
        ]
        if match.empty:
            raise HTTPException(status_code=404, detail=f"Symbol '{query}' not found in NSE listings")
    
    df = await asyncio.to_thread(data_fetcher.get_enriched_data, symbol)
    if df is None or df.empty: 
        raise HTTPException(status_code=404, detail="Market data unavailable. Markets may be closed or broker session expired.")
    
    current_price = float(df['close'].iloc[-1])
    
    # Pillar 2: Get pure math from the LSTM
    lstm_future = prediction_engine.generate_forecast(df)
    
    # Pillars 1 & 3: Pass the math to Groq to get Fundamentals & Patterns
    ai_analysis = get_hybrid_prediction(symbol, df, float(df['rsi'].iloc[-1]), lstm_future)

    # ⚡ FORCE LOWERCASE COLUMNS for Flutter rendering matrix mapping
    history_df = df.tail(60).copy()
    history_df.columns = [str(c).lower() for c in history_df.columns]

    response = {
        "symbol": symbol.upper(), 
        "current_price": current_price,
        "history": history_df.to_dict(orient="records"),
        "future_path": ai_analysis.get("future_path", lstm_future), 
        "action": ai_analysis.get("action", "HOLD"),
        "reasoning": ai_analysis.get("reasoning", "Analyzing..."),
        "target_price": ai_analysis.get("target_price", current_price * 1.02),
        "stop_loss": ai_analysis.get("stop_loss", current_price * 0.98),
        "buy_time": ai_analysis.get("buy_time", ""),
        "sell_time": ai_analysis.get("sell_time", ""),
        "trading_style": ai_analysis.get("trading_style", "Intraday"),
        "style_reason": ai_analysis.get("style_reason", "Default strategy."),
        "risk_level": ai_analysis.get("risk_level", "Medium"),
        "sentiment": 0.72
    }
    return response

# ==========================================
# 📰 REAL-TIME NEWS ENDPOINT
# ==========================================
from app.services.news_service import NewsService
news_engine = NewsService()

@app.get("/news")
async def get_market_news():
    try:
        news_items = await asyncio.to_thread(news_engine.get_market_news)
        return {"news": news_items, "timestamp": datetime.now().isoformat()}
    except Exception as e:
        print(f"[ERROR] News Error: {e}")
        return {"news": [], "timestamp": datetime.now().isoformat()}

# ==========================================
# 📊 MARKET MOMENTUM ENDPOINT
# ==========================================
@app.get("/market-momentum")
async def get_market_momentum():
    try:
        momentum = await asyncio.to_thread(news_engine.get_market_momentum)
        return momentum
    except Exception as e:
        print(f"[ERROR] Momentum Error: {e}")
        return {
            "state": "NEUTRAL",
            "momentum": "MODERATE",
            "nifty_change": 0.0,
            "summary": "Market data unavailable. Check back during trading hours.",
            "strategy": "Wait for market to open for accurate signals."
        }

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
        report = perform_strategy_simulation(df, prediction_engine)
        report["symbol"] = symbol.upper()
        return report
    except Exception as e:
        print(f"[ERROR] Backtest Engine Error: {e}")
        raise HTTPException(status_code=500, detail="Internal simulation error")

# ==========================================
# 🤖 AI CHAT TUTOR ENDPOINT
# ==========================================
from app.services.chat_agent import get_tutor_response

@app.post("/chat")
async def chat_endpoint(payload: dict):
    try:
        message = payload.get("message", "")
        context = payload.get("context", "General Market Watchlist")
        history = payload.get("history", [])
        prediction_data = payload.get("prediction_data", None)
        page_data = payload.get("page_data", None)
        reply = await asyncio.to_thread(
            get_tutor_response, message, context, history, prediction_data, page_data
        )
        return {"reply": reply}
    except Exception as e:
        print(f"[ERROR] Chat Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

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
                # ⚡ FORCE LOWERCASE COLUMNS for live websocket ticks mapping
                history_df = df.tail(60).copy()
                history_df.columns = [str(c).lower() for c in history_df.columns]

                await websocket.send_json({
                    "current_price": float(df['close'].iloc[-1]),
                    "history": history_df.to_dict(orient="records"),
                    "rsi": float(df['rsi'].iloc[-1])
                })
            await asyncio.sleep(5)
    except WebSocketDisconnect: 
        pass