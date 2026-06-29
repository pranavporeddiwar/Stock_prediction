import os
from fastapi import FastAPI, Query, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from app.services.data_fetcher import DataFetcher
from app.services.prediction_service import PredictionService
from app.services.watchlist_service import WatchlistService
from app.services.ai_agent import get_hybrid_prediction
import asyncio
from app.services.chat_agent import get_tutor_response
from datetime import datetime

# ==========================================
# 🔥 FIREBASE CLOUD DATABASE SETUP
# ==========================================
import firebase_admin
from firebase_admin import credentials, firestore, get_app

db = None  # Global database instance

def init_firebase():
    global db
    try:
        # Check if Firebase is already initialized
        get_app()
        print("🔥 Firebase already initialized.")
        db = firestore.client()
        return
    except ValueError:
        pass 

    # Dynamic Path Routing
    render_path = "/etc/secrets/serviceAccountKey.json"
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    local_path = os.path.join(base_dir, "serviceAccountKey.json")

    try:
        if os.path.exists(render_path):
            print("☁️ SYSTEM: Loading Firebase from Render Secrets Vault...")
            cred = credentials.Certificate(render_path)
        elif os.path.exists(local_path):
            print("💻 SYSTEM: Loading Firebase from Local Laptop...")
            cred = credentials.Certificate(local_path)
        elif os.path.exists("serviceAccountKey.json"):
            print("💻 SYSTEM: Loading Firebase from relative local path...")
            cred = credentials.Certificate("serviceAccountKey.json")
        elif os.path.exists("firebase-key.json"): 
            print("💻 SYSTEM: Loading Firebase from legacy firebase-key.json...")
            cred = credentials.Certificate("firebase-key.json")
        else:
            print("❌ CRITICAL: Firebase Secret Key not found!")
            return 

        firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("✅ Firebase Cloud Database Connected Successfully!")
    except Exception as e:
        print(f"⚠️ Firebase Init Error: {e}")

init_firebase()


# ==========================================
# 🚀 FASTAPI INITIALIZATION
# ==========================================
app = FastAPI(title="Neural Stream Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

data_fetcher = None
prediction_engine = None
watchlist_manager = None

@app.on_event("startup")
async def startup_event():
    global data_fetcher, prediction_engine, watchlist_manager
    print("⚙️ Initializing AI & Broker Services...")
    data_fetcher = DataFetcher()
    prediction_engine = PredictionService()
    watchlist_manager = WatchlistService(fetcher_instance=data_fetcher)
    print("✅ All Neural Services Online!")

# ==========================================
# 🩺 CLOUD HEALTH CHECK (The Heartbeat)
# ==========================================
@app.get("/")
async def root_health_check():
    return {
        "status": "online",
        "message": "Neural Stream AI Engine is permanently live! 🚀",
        "firebase": "Connected",
        "port": 10000
    }

# ==========================================
# 🌐 STANDARD HTTP ENDPOINTS 
# ==========================================
@app.get("/predict")
async def get_prediction(symbol: str = Query(..., description="NSE Stock Symbol")):
    global data_fetcher, prediction_engine, db
    
    try:
        df = await asyncio.to_thread(data_fetcher.get_enriched_data, symbol, mode="intraday")
        if df is None or df.empty:
            raise HTTPException(status_code=404, detail="Failed to fetch market data.")

        current_price = float(df['close'].iloc[-1])
        rsi_val = float(df['rsi'].iloc[-1]) if 'rsi' in df.columns else 50.0

        lstm_future = prediction_engine.generate_forecast(df)
        ai_analysis = get_hybrid_prediction(symbol, df, rsi_val, lstm_future)

        final_response = {
            "symbol": symbol.upper(),
            "current_price": current_price,
            "history": df.tail(60).to_dict(orient="records"),
            "future_path": lstm_future,
            "action": ai_analysis.get("action", "HOLD"),
            "reasoning": ai_analysis.get("reasoning", "Awaiting neural synthesis..."),
            "target_price": ai_analysis.get("target_price", current_price * 1.02),
            "stop_loss": ai_analysis.get("stop_loss", current_price * 0.98),
            "sentiment": 0.72,
        }

        if db is not None:
            try:
                db.collection("predictions").document(symbol.upper()).set(final_response)
            except Exception as fb_err:
                print(f"❌ Firebase Upload Error: {fb_err}")

        return final_response
    except Exception as e:
        print(f"❌ API Error for {symbol}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/watchlist")
async def get_watchlist():
    global watchlist_manager
    try:
        return await watchlist_manager.get_market_overview()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

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
         raise HTTPException(status_code=500, detail=str(e))

# ==========================================
# ⚡ WEBSOCKET LIVE STREAM 
# ==========================================
@app.websocket("/ws/live/{symbol}")
async def live_stock_stream(websocket: WebSocket, symbol: str):
    await websocket.accept()
    print(f"🟢 [WebSocket OPEN] Live Stream activated for {symbol.upper()}")
    try:
        while True:
            df = await asyncio.to_thread(data_fetcher.get_enriched_data, symbol, mode="intraday")
            if df is not None and not df.empty:
                current_price = float(df['close'].iloc[-1])
                lstm_future = prediction_engine.generate_forecast(df)
                
                live_payload = {
                    "symbol": symbol.upper(),
                    "current_price": current_price,
                    "history": df.tail(60).to_dict(orient="records"),
                    "future_path": lstm_future,
                    "timestamp": datetime.now().isoformat()
                }
                await websocket.send_json(live_payload)
            await asyncio.sleep(5)
    except WebSocketDisconnect:
        print(f"🔴 [WebSocket CLOSED] Client disconnected from {symbol.upper()}")
    except Exception as e:
        print(f"❌ [WebSocket ERROR] {symbol.upper()}: {e}")
        try:
            await websocket.close()
        except:
            pass