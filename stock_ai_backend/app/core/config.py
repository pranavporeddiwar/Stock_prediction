import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    ALPHA_VANTAGE_KEY = os.getenv("ALPHA_VANTAGE_KEY", "MISSING")
    BASE_URL = "https://www.alphavantage.co/query"
    
    # 2026 FIX: Alpha Vantage now maps the demerged entity to this exact string
    # Try TMCV.BSE first. If you want the Passenger/EV branch, use TMPV.BSE
    DEFAULT_SYMBOL = "TMCV.BSE" 
    
    DATA_FUNCTION = "TIME_SERIES_INTRADAY"
    INTERVAL = "15min"

settings = Config()