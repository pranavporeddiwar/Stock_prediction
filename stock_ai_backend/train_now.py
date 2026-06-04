# train_now.py
import os
import pyotp
import numpy as np
from dotenv import load_dotenv
from SmartApi import SmartConnect
from app.services.prediction_service import PredictionService
from app.services.data_fetcher import DataFetcher

# --- 1. LOAD CREDENTIALS FROM .ENV ---
load_dotenv()

API_KEY = os.getenv("API_KEY")
CLIENT_ID = os.getenv("CLIENT_ID")
PIN = os.getenv("PIN")
TOTP_SECRET = os.getenv("TOTP_SECRET")

# --- 2. SETUP BROKER SESSION ---
obj = SmartConnect(api_key=API_KEY)
# Ensure TOTP_SECRET is clean (no spaces)
totp_token = pyotp.TOTP(TOTP_SECRET.replace(" ", "")).now()
session = obj.generateSession(CLIENT_ID, PIN, totp_token)

if not session['status']:
    print(f"❌ Login Failed: {session.get('message')}")
    exit()

print(f"✅ Session Established for {CLIENT_ID}")

# --- 3. FETCH & PREPARE DATA ---
fetcher = DataFetcher(obj)
fetcher.symbol_token = "3045" # Using SBIN for high-volume training data
df = fetcher.get_enriched_data()

if df is not None and len(df) > 60:
    # FILTRATION: Using exact features from Iman Khamis notebook
    features = ['Close', 'h_o', 'pct_chng', 'Volume']
    df_numeric = df[features].astype(float)
    
    ps = PredictionService()
    data_scaled = ps.scaler.fit_transform(df_numeric.values)
    
    x_train, y_train = [], []
    for i in range(60, len(data_scaled)):
        x_train.append(data_scaled[i-60:i])
        y_train.append(data_scaled[i, 0]) # Target is Close price

    x_train, y_train = np.array(x_train), np.array(y_train)
    
    # --- 4. START TRAINING (11 Epochs) ---
    print(f"🚀 Training Stacked LSTM on {len(x_train)} samples...")
    ps.model.fit(x_train, y_train, epochs=11, batch_size=32)

    # --- 5. SAVE THE BRAIN ---
    if not os.path.exists('models'): os.makedirs('models')
    ps.model.save('models/stock_lstm_pro.h5')
    print("✅ Training Complete! Model saved as stock_lstm_pro.h5")
else:
    print("❌ Error: Not enough data points fetched for training.")