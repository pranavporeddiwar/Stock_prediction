from fastapi import APIRouter, HTTPException
import firebase_admin
from firebase_admin import credentials, firestore
from app.services.pattern_detector import PatternDetector
from app.services.ml_predictor import MLPredictor
from app.services.stock_service import StockService

# Initialize your router as per your existing setup
router = APIRouter() 
predictor = MLPredictor()

# 1. INITIALIZE FIREBASE AT THE TOP OF THE FILE
try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
except ValueError:
    # Prevents crashes when FastAPI auto-reloads the server during changes
    pass

db = firestore.client()

@router.get("/predict-full-day/{symbol}")
async def get_full_day_forecast(symbol: str):
    try:
        # 2. Get Real NSE Data
        raw_df = StockService.get_real_data(symbol)
        
        # 3. Step 1: Analysis Module (Detect Patterns/Trends)
        analyzed_df = PatternDetector.analyze_patterns(raw_df)
        
        # 4. Step 2: ML Module (Predict Future Sequence)
        future_candles = predictor.predict_intraday_sequence(analyzed_df)
        
        # 5. Construct the final response payload dictionary
        response_data = {
            "symbol": symbol.upper(),
            "historical_analysis": "Detected Hammer/Engulfing at Support",
            "predicted_chart": future_candles # List of 25 candles for Flutter
        }
        
        # 6. INTERCEPT & MIRROR TO THE CLOUD
        # Pushes this exact clean dictionary to Firestore under 'predictions' collection
        db.collection("predictions").document(symbol.upper()).set(response_data)
        print(f"☁️ Cloud Sync: {symbol.upper()} full-day forecast successfully cached in Firestore.")
        
        return response_data

    except Exception as e:
        print(f"❌ Backend/Cloud Error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))