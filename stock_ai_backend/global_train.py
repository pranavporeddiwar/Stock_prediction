import pandas as pd
import numpy as np
import os
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.callbacks import EarlyStopping

# Configuration
AI_READY_DIR = r'D:\prediction\stock_ai_backend\data\ai_ready'
LOOKBACK = 60 
FEATURES = ['Close', 'h_o', 'pct_chng', 'sma_5']

def prepare_global_data():
    all_x, all_y = [], []
    # Using a single scaler for the entire market DNA
    scaler_x = MinMaxScaler(feature_range=(0, 1))
    scaler_y = MinMaxScaler(feature_range=(0, 1))
    
    files = [f for f in os.listdir(AI_READY_DIR) if f.endswith('_ready.parquet')]
    
    for file in files:
        df = pd.read_parquet(os.path.join(AI_READY_DIR, file))
        
        # SAFETY GATE: Skip files that are too small for the LOOKBACK
        if len(df) <= LOOKBACK:
            print(f"⏩ Skipping {file}: Not enough data points ({len(df)} rows).")
            continue
            
        print(f"📉 Loading {file} into training matrix...")
        
        # Scale the specific features
        scaled_x = scaler_x.fit_transform(df[FEATURES])
        scaled_y = scaler_y.fit_transform(df[['target']])
        
        for i in range(LOOKBACK, len(scaled_x)):
            all_x.append(scaled_x[i-LOOKBACK:i])
            all_y.append(scaled_y[i])
            
    return np.array(all_x), np.array(all_y), scaler_x, scaler_y

def build_and_train():
    X, y, scaler_x, scaler_y = prepare_global_data()
    
    if len(X) == 0:
        print("❌ No data was loaded. Check your ai_ready folder!")
        return

    print(f"🔥 Data Prepared. Training on {X.shape[0]} sequences...")

    model = Sequential([
        LSTM(units=128, return_sequences=True, input_shape=(X.shape[1], X.shape[2])),
        Dropout(0.2),
        LSTM(units=64, return_sequences=True),
        Dropout(0.2),
        LSTM(units=32),
        Dropout(0.2),
        Dense(units=1) 
    ])

    model.compile(optimizer='adam', loss='mean_squared_error')
    
    # Patience set to 5: if error doesn't drop for 5 epochs, stop and save
    early_stop = EarlyStopping(monitor='loss', patience=5, restore_best_weights=True)

    print("🧠 Starting Deep Market Learning. Monitor the 'loss' value...")
    model.fit(X, y, epochs=50, batch_size=128, callbacks=[early_stop])

    # Ensure models directory exists
    os.makedirs('models', exist_ok=True)
    model.save('models/global_market_dna.h5')
    print("✅ Global Model Saved! History has been memorized.")

if __name__ == "__main__":
    build_and_train()