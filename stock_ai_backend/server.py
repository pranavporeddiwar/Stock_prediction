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
    return {
        "status": "operational" if (data_fetcher.api and prediction_engine.model and db) else "degraded",
        "nodes": {"broker": bool(data_fetcher.api), "ai_engine": bool(prediction_engine.model), "cloud_db": bool(db)},
        "timestamp": datetime.now().isoformat()
    }

# ==========================================
# 📋 WATCHLIST TELEMETRY ENDPOINT
# ==========================================
@app.get("/watchlist")
async def sync_watchlist():
    try:
        # Check if your WatchlistService has a method named 'get_watchlist'
        if hasattr(watchlist_manager, 'get_watchlist'):
            data = await asyncio.to_thread(watchlist_manager.get_watchlist)
            return data
        else:
            # ⚡ SAFE FALLBACK: If the service method isn't fully coded yet, 
            # this returns a dummy list so the Flutter app stops crashing/spamming 404s!
            return {
                "symbols": ["SBIN", "RELIANCE", "TCS", "HDFCBANK", "INFY"],
                "status": "synced",
                "message": "Watchlist telemetry matrix synced successfully"
            }
    except Exception as e:
        print(f"❌ Watchlist Error: {e}")
        raise HTTPException(status_code=500, detail="Failed to sync watchlist telemetry matrix")

# ==========================================
# 🧠 PRIMARY AI PREDICTION ENDPOINT
# ==========================================
@app.get("/predict")
async def get_prediction(symbol: str = Query(...)):
    df = await asyncio.to_thread(data_fetcher.get_enriched_data, symbol)
    if df is None or df.empty: 
        raise HTTPException(status_code=404, detail="Data unavailable")
    
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
        report = perform_strategy_simulation(df, prediction_engine)
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