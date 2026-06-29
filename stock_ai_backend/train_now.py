import os
import pyotp
import numpy as np
import pandas as pd
from dotenv import load_dotenv
from SmartApi import SmartConnect
from app.services.prediction_service import PredictionService
from app.services.data_fetcher import DataFetcher
import tensorflow as tf
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
load_dotenv()
API_KEY = os.getenv("API_KEY")
CLIENT_ID = os.getenv("CLIENT_ID")
PIN = os.getenv("PIN")
TOTP_SECRET = os.getenv("TOTP_SECRET")
if not all([API_KEY, CLIENT_ID, PIN, TOTP_SECRET]):
    print(" Critical Fault: Missing environment credentials in your local .env file.")
    exit()
obj = SmartConnect(api_key=API_KEY)
totp_token = pyotp.TOTP(TOTP_SECRET.replace(" ", "")).now()
session = obj.generateSession(CLIENT_ID, PIN, totp_token)
if not session.get('status'):
    print(f" Broker Session Refused: {session.get('message')}")
    exit()
print(f" Session Established Securely for Ticker Node: {CLIENT_ID}")
fetcher = DataFetcher()
fetcher.api = obj
print(" Fetching historical market architecture for training...")
df = fetcher.get_enriched_data("SBIN", mode="intraday")
if df is not None and len(df) > 120:
    features = ['close', 'h_o', 'pct_chng', 'rsi', 'atr', 'ema_20']
    df_numeric = df[features].astype(float)
    ps = PredictionService()
    print(" Recalibrating Global Scaler Matrix...")
    data_scaled = ps.scaler.fit_transform(df_numeric.values) if ps.scaler else df_numeric.values
    x_train, y_train = [], []
    for i in range(60, len(data_scaled)):
        x_train.append(data_scaled[i-60:i])
        y_train.append(data_scaled[i, 0])
    x_train, y_train = np.array(x_train), np.array(y_train)
    print(f" Training Stacked LSTM Network on {len(x_train)} live structural arrays...")
    if ps.model is not None:
        print(" Compiling neural network for weight adjustments...")
        ps.model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=0.001), loss='mean_squared_error')
        ps.model.fit(
            x_train,
            y_train,
            epochs=11,
            batch_size=32,
            shuffle=False
        )
        if not os.path.exists('models'):
            os.makedirs('models')
        ps.model.save('models/stock_lstm_pro.h5')
        import joblib
        if ps.scaler:
            joblib.dump(ps.scaler, 'models/scaler.pkl')
        print(" Weights and parameters updated successfully! Saved as models/stock_lstm_pro.h5")
    else:
        print(" System Abort: Unable to locate pre-compiled model architecture map.")
else:
    print(" Error: Not enough historical indicator data points available for calculation.")
