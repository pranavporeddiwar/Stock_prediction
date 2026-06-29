import os
from dotenv import load_dotenv
load_dotenv()
class Config:
    ALPHA_VANTAGE_KEY = os.getenv("ALPHA_VANTAGE_KEY", "MISSING")
    BASE_URL = "https://www.alphavantage.co/query"
    DEFAULT_SYMBOL = "TMCV.BSE"
    DATA_FUNCTION = "TIME_SERIES_INTRADAY"
    INTERVAL = "15min"
settings = Config()
