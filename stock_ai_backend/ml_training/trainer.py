import pandas as pd
import numpy as np
import os
import sys

# --- SYSTEM PATH FIX ---
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.callbacks import EarlyStopping

def train_professional_model():
    file_path = "dataset_prepared.csv"
    
    if not os.path.exists(file_path):
        print(f"❌ Error: {file_path} not found! Run prepare_data.py first.")
        return

    # 1. Load the prepared multi-ticker data
    df = pd.read_csv(file_path, index_col=0)
    data_values = df.values
    
    # 2. Sequence Creation (Look back 60 time steps to predict the next 1)
    X, y = [], []
    for i in range(60, len(data_values)):
        X.append(data_values[i-60:i])
        y.append(data_values[i, 0]) # Target is the 'close' price
    
    X, y = np.array(X), np.array(y)
    
    # 3. Build High-Accuracy LSTM Architecture
    model = Sequential([
        LSTM(128, return_sequences=True, input_shape=(X.shape[1], X.shape[2])),
        Dropout(0.2),
        LSTM(64, return_sequences=False),
        Dropout(0.2),
        Dense(32, activation='relu'),
        Dense(1)
    ])
    
    # Huber loss is more robust to market gaps/outliers than MSE
    model.compile(optimizer='adam', loss='huber')
    
    # 4. Early Stopping (Stop training when accuracy peaks)
    early_stop = EarlyStopping(
        monitor='val_loss', 
        patience=5, 
        restore_best_weights=True
    )

    print(f"🚀 Training Professional Brain on {len(X)} sequences...")
    
    model.fit(
        X, y, 
        epochs=50, 
        batch_size=32, 
        validation_split=0.2, # Uses 20% of data to verify accuracy
        callbacks=[early_stop],
        verbose=1
    )
    
    # 5. Save the finalized Model
    save_path = os.path.join("..", "models", "stock_lstm_pro.h5")
    os.makedirs(os.path.dirname(save_path), exist_ok=True)
    model.save(save_path)
    
    print("-" * 30)
    print(f"✅ SUCCESS: High-Accuracy Model saved to {save_path}")

if __name__ == "__main__":
    train_professional_model()