import pandas as pd
import nselib
from nselib import capital_market
from datetime import datetime, timedelta
import os
import time

PARQUET_DIR = r'D:\prediction\stock_ai_backend\data\parquet_history'

def update_stock_memory():
    if not os.path.exists(PARQUET_DIR):
        print("❌ Parquet directory not found!")
        return

    symbols = [f.replace('.parquet', '') for f in os.listdir(PARQUET_DIR) if f.endswith('.parquet')]
    
    for symbol in symbols:
        try:
            file_path = os.path.join(PARQUET_DIR, f"{symbol}.parquet")
            df = pd.read_parquet(file_path)
            
            # Ensure existing data is clean and numeric
            df['Date'] = pd.to_datetime(df['Date'], errors='coerce')
            df = df.dropna(subset=['Date']).drop_duplicates(subset=['Date']).reset_index(drop=True)
            
            last_date = df['Date'].max()
            today = datetime.now()

            if last_date.date() >= today.date():
                print(f"✅ {symbol} is up to date.")
                continue

            current_start = last_date + timedelta(days=1)
            new_data_list = []

            while current_start <= today:
                current_end = min(current_start + timedelta(days=364), today)
                start_str = current_start.strftime('%d-%m-%Y')
                end_str = current_end.strftime('%d-%m-%Y')
                
                print(f"⏳ {symbol}: Fetching {start_str} to {end_str}...")
                
                try:
                    batch = capital_market.price_volume_and_deliverable_position_data(
                        symbol=symbol, from_date=start_str, to_date=end_str
                    )
                    
                    if batch is not None and not batch.empty:
                        # 1. Positional Renaming to stop indexing errors
                        batch.columns = [f"col_{i}_{str(name).upper()}" for i, name in enumerate(batch.columns)]
                        
                        col_map = {}
                        for col in batch.columns:
                            if 'SYMBOL' in col: col_map[col] = 'Symbol'
                            elif 'DATE' in col: col_map[col] = 'Date'
                            elif 'OPEN' in col: col_map[col] = 'Open'
                            elif 'HIGH' in col: col_map[col] = 'High'
                            elif 'LOW' in col: col_map[col] = 'Low'
                            elif 'CLOSE' in col: col_map[col] = 'Close'
                            elif 'QTY' in col or 'TRD' in col: col_map[col] = 'Volume'
                        
                        batch = batch.rename(columns=col_map)
                        needed = ['Symbol', 'Date', 'Open', 'High', 'Low', 'Close', 'Volume']
                        
                        # 2. Extract and sanitize each column
                        cleaned_cols = {}
                        for n in needed:
                            if n in batch.columns:
                                col_data = batch[n].iloc[:, 0] if isinstance(batch[n], pd.DataFrame) else batch[n]
                                
                                # FORCE NUMERIC: This fixes the 'str to double' error
                                if n in ['Open', 'High', 'Low', 'Close', 'Volume']:
                                    cleaned_cols[n] = pd.to_numeric(col_data.astype(str).str.replace(',', ''), errors='coerce')
                                else:
                                    cleaned_cols[n] = col_data
                        
                        batch_cleaned = pd.DataFrame(cleaned_cols)
                        batch_cleaned['Date'] = pd.to_datetime(batch_cleaned['Date'], errors='coerce')
                        batch_cleaned = batch_cleaned.dropna(subset=['Open', 'Close', 'Date'])
                        new_data_list.append(batch_cleaned)
                    
                    time.sleep(2) 
                except Exception as e:
                    print(f"⚠️ Batch skipped for {symbol}: {e}")
                
                current_start = current_end + timedelta(days=1)

            if new_data_list:
                new_combined = pd.concat(new_data_list, ignore_index=True)
                
                # Align types with original dataframe to prevent Parquet schema mismatch
                for col in ['Open', 'High', 'Low', 'Close', 'Volume']:
                    if col in new_combined.columns:
                        new_combined[col] = new_combined[col].astype(float)

                final_df = pd.concat([df, new_combined], ignore_index=True)
                final_df = final_df.drop_duplicates(subset=['Date'], keep='last').sort_values('Date').reset_index(drop=True)
                
                final_df.to_parquet(file_path, engine='pyarrow', index=False)
                print(f"🚀 {symbol} synchronized successfully.")

        except Exception as e:
            print(f"❌ Error processing {symbol}: {e}")

if __name__ == "__main__":
    print("🚀 Starting Numeric-Safe Gap-Filler...")
    update_stock_memory()