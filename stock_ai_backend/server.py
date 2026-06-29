import os
import asyncio
import subprocess
from fastapi import FastAPI, Query, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime, time as dtime, timedelta
import firebase_admin
from firebase_admin import credentials, firestore
from contextlib import asynccontextmanager
from app.services.data_fetcher import DataFetcher
from app.services.prediction_service import PredictionService
from app.services.watchlist_service import WatchlistService
from app.services.ai_agent import get_hybrid_prediction
from app.services.backtest_service import perform_strategy_simulation
from apscheduler.schedulers.background import BackgroundScheduler
from pytz import timezone
def init_firebase():
    try:
        cred = credentials.Certificate("/etc/secrets/serviceAccountKey.json") if os.path.exists("/etc/secrets/serviceAccountKey.json") else credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
        return firestore.client()
    except Exception as e:
        print(f" Firebase Init Error: {e}")
        return None
def run_daily_ml_training():
    print(f"[{datetime.now()}] CRON: Starting pre-market ML training with live broker data...")
    try:
        subprocess.Popen(["python", "train_now.py"])
        print("Pre-market training initiated via train_now.py. Model will be ready before 9:15 AM.")
    except Exception as e:
        print(f"Automated Training Failed: {e}")
def is_market_open():
    ist_tz = timezone('Asia/Kolkata')
    now_ist = datetime.now(ist_tz)
    if now_ist.weekday() >= 5:
        return False
    market_open = dtime(9, 15)
    market_close = dtime(15, 30)
    return market_open <= now_ist.time() <= market_close
@asynccontextmanager
async def lifespan(app: FastAPI):
    print(" Initializing Pre-Market Scheduler (IST Timezone)...")
    ist_tz = timezone('Asia/Kolkata')
    scheduler = BackgroundScheduler(timezone=ist_tz)
    scheduler.add_job(
        run_daily_ml_training,
        'cron',
        day_of_week='mon-fri',
        hour=8,
        minute=45,
        id='premarket_training'
    )
    scheduler.start()
    print("Pre-Market AI Scheduler Online (08:45 AM Mon-Fri)")
    asyncio.create_task(init_services())
    yield
    scheduler.shutdown()
    print(" Pre-Market AI Scheduler Safely Offline.")
app = FastAPI(title="Neural Stream Backend", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"]
)
db = init_firebase()
data_fetcher = None
prediction_engine = None
watchlist_manager = None
news_engine = None
async def init_services():
    global data_fetcher, prediction_engine, watchlist_manager, news_engine
    print(" Starting background initialization of neural services...")
    try:
        data_fetcher = await asyncio.to_thread(DataFetcher)
        prediction_engine = await asyncio.to_thread(PredictionService)
        watchlist_manager = await asyncio.to_thread(WatchlistService, data_fetcher)
        from app.services.news_service import NewsService
        news_engine = await asyncio.to_thread(NewsService)
        print(" Neural Services Online!")
    except Exception as e:
        print(f" Background Initialization Error: {e}")
@app.get("/")
@app.head("/")
@app.get("/health-check")
async def health_check():
    if not data_fetcher or not prediction_engine:
        return {
            "status": "warming_up",
            "message": "Neural engines are loading into memory...",
            "timestamp": datetime.now().isoformat()
        }
    broker_alive = await asyncio.to_thread(data_fetcher.is_session_alive)
    return {
        "status": "operational" if (broker_alive and prediction_engine.model and db) else "degraded",
        "nodes": {"broker": broker_alive, "ai_engine": bool(prediction_engine.model), "cloud_db": bool(db)},
        "timestamp": datetime.now().isoformat()
    }
@app.get("/market-status")
async def market_status():
    ist_tz = timezone('Asia/Kolkata')
    now_ist = datetime.now(ist_tz)
    open_flag = is_market_open()
    if now_ist.weekday() >= 5:
        days_until_monday = 7 - now_ist.weekday()
        next_open = (now_ist + timedelta(days=days_until_monday)).replace(hour=9, minute=15, second=0, microsecond=0)
    elif now_ist.time() > dtime(15, 30):
        if now_ist.weekday() == 4:
            next_open = (now_ist + timedelta(days=3)).replace(hour=9, minute=15, second=0, microsecond=0)
        else:
            next_open = (now_ist + timedelta(days=1)).replace(hour=9, minute=15, second=0, microsecond=0)
    elif now_ist.time() < dtime(9, 15):
        next_open = now_ist.replace(hour=9, minute=15, second=0, microsecond=0)
    else:
        next_open = now_ist
    return {
        "is_open": open_flag,
        "current_time_ist": now_ist.strftime("%I:%M %p"),
        "next_open": next_open.strftime("%A, %I:%M %p") if not open_flag else "Now",
        "day": now_ist.strftime("%A")
    }
@app.get("/watchlist")
async def sync_watchlist():
    if not watchlist_manager:
        raise HTTPException(status_code=503, detail="AI engine warming up. Please wait...")
    try:
        data = await watchlist_manager.get_market_overview()
        if data:
            return data
        else:
            return [
                {"symbol": "SBIN", "current_price": 0, "change_pct": 0, "rsi": 50, "volatility": 0, "trading_style": "Intraday", "style_reason": "Loading...", "status": "NEUTRAL"},
                {"symbol": "RELIANCE", "current_price": 0, "change_pct": 0, "rsi": 50, "volatility": 0, "trading_style": "Swing", "style_reason": "Loading...", "status": "NEUTRAL"},
                {"symbol": "TCS", "current_price": 0, "change_pct": 0, "rsi": 50, "volatility": 0, "trading_style": "Positional", "style_reason": "Loading...", "status": "NEUTRAL"},
                {"symbol": "HDFCBANK", "current_price": 0, "change_pct": 0, "rsi": 50, "volatility": 0, "trading_style": "Intraday", "style_reason": "Loading...", "status": "NEUTRAL"},
                {"symbol": "INFY", "current_price": 0, "change_pct": 0, "rsi": 50, "volatility": 0, "trading_style": "Swing", "style_reason": "Loading...", "status": "NEUTRAL"},
            ]
    except Exception as e:
        print(f" Watchlist Error: {e}")
        raise HTTPException(status_code=500, detail="Failed to sync watchlist telemetry matrix")
@app.get("/predict")
async def get_prediction(symbol: str = Query(...)):
    if not data_fetcher or not prediction_engine:
        raise HTTPException(status_code=503, detail="AI engine warming up. Please wait...")
    if not data_fetcher.api:
        raise HTTPException(status_code=503, detail="Broker session offline. Reconnecting...")
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
    lstm_future = prediction_engine.generate_forecast(df)
    ai_analysis = get_hybrid_prediction(symbol, df, float(df['rsi'].iloc[-1]), lstm_future)
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
@app.get("/news")
async def get_market_news():
    if not news_engine:
        return {"news": [], "timestamp": datetime.now().isoformat(), "status": "warming_up"}
    try:
        news_items = await asyncio.to_thread(news_engine.get_market_news)
        return {"news": news_items, "timestamp": datetime.now().isoformat()}
    except Exception as e:
        print(f"[ERROR] News Error: {e}")
        return {"news": [], "timestamp": datetime.now().isoformat()}
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
@app.get("/backtest/{symbol}")
async def run_backtest(symbol: str):
    print(f" Running Strategy Simulation for {symbol.upper()}...")
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
@app.websocket("/ws/live/{symbol}")
async def live_stock_stream(websocket: WebSocket, symbol: str):
    await websocket.accept()
    try:
        while True:
            df = await asyncio.to_thread(data_fetcher.get_enriched_data, symbol)
            if df is not None:
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
