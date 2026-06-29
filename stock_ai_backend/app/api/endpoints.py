from fastapi import APIRouter, HTTPException
import firebase_admin
from firebase_admin import credentials, firestore
from app.services.pattern_detector import PatternDetector
from app.services.ml_predictor import MLPredictor
from app.services.stock_service import StockService
router = APIRouter()
predictor = MLPredictor()
try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
except ValueError:
    pass
db = firestore.client()
@router.get("/predict-full-day/{symbol}")
async def get_full_day_forecast(symbol: str):
    try:
        raw_df = StockService.get_real_data(symbol)
        analyzed_df = PatternDetector.analyze_patterns(raw_df)
        future_candles = predictor.predict_intraday_sequence(analyzed_df)
        response_data = {
            "symbol": symbol.upper(),
            "historical_analysis": "Detected Hammer/Engulfing at Support",
            "predicted_chart": future_candles
        }
        db.collection("predictions").document(symbol.upper()).set(response_data)
        print(f" Cloud Sync: {symbol.upper()} full-day forecast successfully cached in Firestore.")
        return response_data
    except Exception as e:
        print(f" Backend/Cloud Error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
