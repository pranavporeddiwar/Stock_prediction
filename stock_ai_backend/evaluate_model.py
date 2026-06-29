import os
import numpy as np
import pandas as pd
from dotenv import load_dotenv
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
from app.services.data_fetcher import DataFetcher
from app.services.prediction_service import PredictionService

# --- 1. LOAD SECURE CREDENTIALS ---
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

load_dotenv()
API_KEY = os.getenv("API_KEY")
CLIENT_ID = os.getenv("CLIENT_ID")
PIN = os.getenv("PIN")
TOTP_SECRET = os.getenv("TOTP_SECRET")

print("🔍 Initializing Neural Evaluation Protocol...")

if not all([API_KEY, CLIENT_ID, PIN, TOTP_SECRET]):
    print("❌ Missing broker credentials in .env")
    exit()

# --- 2. INITIALIZE SERVICES ---
fetcher = DataFetcher()
fetcher.api = fetcher._init_session()

if not fetcher.api:
    print("❌ Broker Session Refused")
    exit()

ps = PredictionService()
if ps.model is None or ps.scaler is None:
    print("❌ Could not load the trained model or scaler. Run train_now.py first.")
    exit()

print("📥 Fetching historical test data for SBIN...")
df = fetcher.get_enriched_data("SBIN", mode="intraday")

if df is not None and len(df) > 120:
    features = ['close', 'h_o', 'pct_chng', 'rsi', 'atr', 'ema_20']
    df_numeric = df[features].astype(float)
    data_scaled = ps.scaler.transform(df_numeric.values)
    
    # We will test on the last 100 available data points
    test_size = 100
    x_test, actual_prices = [], []
    
    for i in range(len(data_scaled) - test_size, len(data_scaled)):
        x_test.append(data_scaled[i-60:i])
        actual_prices.append(df_numeric['close'].iloc[i])
        
    x_test = np.array(x_test)
    
    print(f"🤖 Running predictions on {test_size} recent data points...")
    predictions_scaled = ps.model.predict(x_test, verbose=0)
    
    # Unscale predictions to get actual price forecasts
    # We create a dummy matrix to unscale properly because the scaler expects 6 columns
    dummy_matrix = np.zeros((len(predictions_scaled), 6))
    dummy_matrix[:, 0] = predictions_scaled[:, 0]
    predicted_prices = ps.scaler.inverse_transform(dummy_matrix)[:, 0]
    
    # --- 3. CONVERT REGRESSION TO CLASSIFICATION ---
    # We compare the prediction to the PREVIOUS day's actual close to see if we predicted UP or DOWN
    actual_directions = []
    predicted_directions = []
    
    for i in range(1, len(actual_prices)):
        prev_close = actual_prices[i-1]
        
        # Did it actually go up? (1 for UP, 0 for DOWN)
        actual_directions.append(1 if actual_prices[i] > prev_close else 0)
        
        # Did the model predict it would go up?
        predicted_directions.append(1 if predicted_prices[i] > prev_close else 0)
        
    # --- 4. CALCULATE METRICS ---
    acc = accuracy_score(actual_directions, predicted_directions)
    prec = precision_score(actual_directions, predicted_directions, zero_division=0)
    rec = recall_score(actual_directions, predicted_directions, zero_division=0)
    f1 = f1_score(actual_directions, predicted_directions, zero_division=0)
    
    print("\n================================================================================")
    print("🧠 NEURAL NETWORK CLASSIFICATION METRICS (DIRECTIONAL FORECASTING)")
    print("================================================================================")
    print(f"| {'Metric':<12} | {'Score':<8} | {'Description':<50} |")
    print("|--------------|----------|----------------------------------------------------|")
    print(f"| 🎯 Accuracy  | {acc*100:>6.2f}% | Total correct UP/DOWN predictions                  |")
    print(f"| 🔎 Precision | {prec*100:>6.2f}% | When model predicted UP, how often was it right?   |")
    print(f"| 🎣 Recall    | {rec*100:>6.2f}% | Out of all actual UP moves, how many did we catch? |")
    print(f"| ⚖️ F1 Score  | {f1*100:>6.2f}% | Balanced average of Precision & Recall             |")
    print("================================================================================\n")
    
else:
    print("❌ Error: Not enough data points available.")
