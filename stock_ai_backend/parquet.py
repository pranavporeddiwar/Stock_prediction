import pandas as pd
import os
PARQUET_DIR = r'D:\prediction\stock_ai_backend\data\parquet_history'
FEATURE_DIR = r'D:\prediction\stock_ai_backend\data\ai_ready'
os.makedirs(FEATURE_DIR, exist_ok=True)
def engineer_history():
    processed_count = 0
    for filename in os.listdir(PARQUET_DIR):
        if filename.endswith('.parquet'):
            symbol = filename.replace('.parquet', '')
            try:
                df = pd.read_parquet(os.path.join(PARQUET_DIR, filename))
                df.columns = [str(c).strip().capitalize() for c in df.columns]
                required = ['Date', 'Close', 'High', 'Open']
                if not all(col in df.columns for col in required):
                    print(f" Skipping {symbol}: Missing required price columns.")
                    continue
                print(f" Engineering features for {symbol}...")
                df['Date'] = pd.to_datetime(df['Date'], errors='coerce')
                df = df.dropna(subset=['Date']).sort_values('Date')
                df['h_o'] = ((df['High'] - df['Close']) / df['Close']) * 100
                df['pct_chng'] = ((df['Close'] - df['Open']) / df['Open']) * 100
                df['sma_5'] = df['Close'].rolling(window=5).mean()
                df['target'] = df['Close'].shift(-1)
                df = df.dropna()
                if not df.empty:
                    df.to_parquet(os.path.join(FEATURE_DIR, f"{symbol}_ready.parquet"), index=False)
                    processed_count += 1
            except Exception as e:
                print(f" Error in {symbol}: {e}")
    print(f"\n Success! {processed_count} stocks engineered and ready for Global Training.")
if __name__ == "__main__":
    engineer_history()
