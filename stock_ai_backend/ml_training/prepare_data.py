import sys
import os
import pandas as pd
import pandas_ta as ta
import joblib
from sklearn.preprocessing import MinMaxScaler
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.services.data_fetcher import DataFetcher
def prepare_professional_dataset():
    fetcher = DataFetcher()
    symbols = ["TCS", "SBIN", "RELIANCE", "INFY"]
    combined_data = []
    print(f" Starting Weekend Training Prep...")
    for symbol in symbols:
        try:
            print(f" Fetching historical data for {symbol}...")
            df = fetcher.get_enriched_data(symbol, mode="intraday")
            if df is not None and not df.empty:
                df['RSI'] = ta.rsi(df['close'], length=14)
                df['ATR'] = ta.atr(df['high'], df['low'], df['close'], length=14)
                df['EMA_20'] = ta.ema(df['close'], length=20)
                features = ['close', 'h_o', 'pct_chng', 'RSI', 'ATR', 'EMA_20']
                clean_df = df[features].dropna()
                combined_data.append(clean_df)
                print(f" {symbol} processed: {len(clean_df)} bars added.")
        except Exception as e:
            print(f" Error processing {symbol}: {e}")
    if not combined_data:
        print(" FAILED: No data was collected. Check your .env credentials.")
        return
    final_df = pd.concat(combined_data)
    scaler = MinMaxScaler(feature_range=(0, 1))
    scaler.fit(final_df)
    os.makedirs("../models", exist_ok=True)
    joblib.dump(scaler, "../models/scaler.pkl")
    final_df.to_csv("dataset_prepared.csv")
    print("-" * 30)
    print(f" SUCCESS: {len(final_df)} total bars prepared.")
    print(f" Dataset: ml_training/dataset_prepared.csv")
    print(f" Scaler: models/scaler.pkl")
if __name__ == "__main__":
    prepare_professional_dataset()
