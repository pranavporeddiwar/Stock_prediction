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
from firebase_admin import credentials, firestore

try:
    cred = credentials.Certificate("firebase-key.json")
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ Firebase Cloud Database Connected Successfully!")
except Exception as e:
    print(f"⚠️ Firebase Init Error: Please check your firebase-key.json file! Details: {e}")
    db = None

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

# Global instances
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
# 🌐 STANDARD HTTP ENDPOINTS (Initial Load)
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
        print(f"❌ API Watchlist Route Exception: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/chat")
async def chat_endpoint(payload: dict):
    try:
        message = payload.get("message", "")
        context = payload.get("context", "General Market Watchlist")
        reply = await asyncio.to_thread(get_tutor_response, message, context)
        return {"reply": reply}
    except Exception as e:
         raise HTTPException(status_code=500, detail=str(e))

# ==========================================
# ⚡ WEBSOCKET LIVE STREAM (Real-Time Ticks)
# ==========================================
@app.websocket("/ws/live/{symbol}")
async def live_stock_stream(websocket: WebSocket, symbol: str):
    """
    Maintains an open connection with Flutter.
    Pushes live Angel One ticks and fresh LSTM predictions every 5 seconds.
    """
    await websocket.accept()
    print(f"🟢 [WebSocket OPEN] Live Stream activated for {symbol.upper()}")
    
    try:
        while True:
            # 1. Fetch live tick data quietly in a background thread
            df = await asyncio.to_thread(data_fetcher.get_enriched_data, symbol, mode="intraday")
            
            if df is not None and not df.empty:
                current_price = float(df['close'].iloc[-1])
                
                # 2. Pure Math Inference (Lightning Fast, NO LLM)
                lstm_future = prediction_engine.generate_forecast(df)
                
                # 3. Build the Live Payload
                live_payload = {
                    "symbol": symbol.upper(),
                    "current_price": current_price,
                    "history": df.tail(60).to_dict(orient="records"),
                    "future_path": lstm_future,
                    "timestamp": datetime.now().isoformat()
                }
                
                # 4. Push directly to Flutter's open socket
                await websocket.send_json(live_payload)
                print(f"📡 [WebSocket] Pushed live tick for {symbol.upper()} -> ₹{current_price}")
            
            # Pause for 5 seconds to respect CPU and Broker rate limits
            await asyncio.sleep(5)
            
    except WebSocketDisconnect:
        print(f"🔴 [WebSocket CLOSED] Client disconnected from {symbol.upper()}")
    except Exception as e:
        print(f"❌ [WebSocket ERROR] {symbol.upper()}: {e}")
        try:
            await websocket.close()
        except:
            pass