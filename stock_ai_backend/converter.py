import pandas as pd
import os

# Paths
INPUT_DIR = r'D:\prediction\stock_ai_backend\data\raw_csv'
OUTPUT_DIR = r'D:\prediction\stock_ai_backend\data\parquet_history'
os.makedirs(OUTPUT_DIR, exist_ok=True)

def process_and_convert():
    for filename in os.listdir(INPUT_DIR):
        if filename.endswith(".csv"):
            symbol = filename.replace(".csv", "")
            print(f"⚡ Optimizing {symbol} for 30-year memory...")
            
            # Load Kaggle CSV
            df = pd.read_csv(os.path.join(INPUT_DIR, filename))
            
            # Clean and match your AI requirements
            df.columns = [c.strip().capitalize() for c in df.columns]
            
            # Save as high-speed Parquet
            df.to_parquet(os.path.join(OUTPUT_DIR, f"{symbol}.parquet"), engine='pyarrow')

    print("✅ System Ready: 30-year database optimized for AI.")

if __name__ == "__main__":
    process_and_convert()