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
                
                # Standardize column names to capitalize first letter (Open, High, Close, Date)
                df.columns = [str(c).strip().capitalize() for c in df.columns]
                
                # Check if essential columns exist
                required = ['Date', 'Close', 'High', 'Open']
                if not all(col in df.columns for col in required):
                    print(f"⏩ Skipping {symbol}: Missing required price columns.")
                    continue
                
                print(f"🛠️ Engineering features for {symbol}...")
                
                # Ensure Date is datetime and sort
                df['Date'] = pd.to_datetime(df['Date'], errors='coerce')
                df = df.dropna(subset=['Date']).sort_values('Date')
                
                # 1. Intraday Volatility (h_o) - Mathematical Factor
                df['h_o'] = ((df['High'] - df['Close']) / df['Close']) * 100
                
                # 2. Price Momentum (pct_chng)
                df['pct_chng'] = ((df['Close'] - df['Open']) / df['Open']) * 100
                
                # 3. Simple Moving Average (5-day window)
                df['sma_5'] = df['Close'].rolling(window=5).mean()
                
                # 4. Target: Tomorrow's Close (Label for supervised learning)
                df['target'] = df['Close'].shift(-1)
                
                # Final Clean: Drop rows with NaN values created by rolling/shifting
                df = df.dropna()
                
                if not df.empty:
                    df.to_parquet(os.path.join(FEATURE_DIR, f"{symbol}_ready.parquet"), index=False)
                    processed_count += 1
                
            except Exception as e:
                print(f"❌ Error in {symbol}: {e}")

    print(f"\n✅ Success! {processed_count} stocks engineered and ready for Global Training.")

if __name__ == "__main__":
    engineer_history()