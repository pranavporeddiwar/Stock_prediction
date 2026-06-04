from app.services.pattern_detector import PatternDetector
from app.services.ml_predictor import MLPredictor
from app.services.stock_service import StockService

predictor = MLPredictor()

@router.get("/predict-full-day/{symbol}")
async def get_full_day_forecast(symbol: str):
    # 1. Get Real NSE Data
    raw_df = StockService.get_real_data(symbol)
    
    # 2. Step 1: Analysis Module (Detect Patterns/Trends)
    analyzed_df = PatternDetector.analyze_patterns(raw_df)
    
    # 3. Step 2: ML Module (Predict Future Sequence)
    future_candles = predictor.predict_intraday_sequence(analyzed_df)
    
    return {
        "symbol": symbol,
        "historical_analysis": "Detected Hammer/Engulfing at Support",
        "predicted_chart": future_candles # List of 25 candles for Flutter
    }