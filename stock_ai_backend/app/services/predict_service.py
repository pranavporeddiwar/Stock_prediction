import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.preprocessing import MinMaxScaler
import os

class PredictionService:
    def __init__(self, model_path='models/stock_lstm_pro.h5'):
        self.model_path = model_path
        self.scaler = MinMaxScaler(feature_range=(0, 1))
        self.window_size = 60
        
        if os.path.exists(self.model_path):
            self.model = tf.keras.models.load_model(self.model_path)
            print(f"🧠 AI Brain: Stacked LSTM Loaded")
        else:
            print("⚠️ AI Brain: Model missing. Please run train_now.py first.")
            self.model = None

    def generate_forecast(self, df):
        """Generates 25 future steps based on the last 60 actual candles."""
        if self.model is None: return []
        
        # Exact feature set from your training scripts
        features = ['close', 'h_o', 'pct_chng', 'volume']
        
        try:
            # 1. Scale data
            numeric_data = df[features].astype(float).values
            scaled_data = self.scaler.fit_transform(numeric_data)
            
            current_window = scaled_data[-self.window_size:].tolist()
            preds_scaled = []

            # 2. Recursive Loop (25 steps)
            for _ in range(25):
                X_input = np.array([current_window[-self.window_size:]])
                p = self.model.predict(X_input, verbose=0)[0][0]
                
                # Append prediction, keeping other features neutral for future steps
                new_row = [p, 0.0, 0.0, current_window[-1][3]]
                current_window.append(new_row)
                preds_scaled.append(p)

            # 3. Inverse Scaling
            res_dummy = np.zeros((len(preds_scaled), 4))
            res_dummy[:, 0] = preds_scaled
            final_prices = self.scaler.inverse_transform(res_dummy)[:, 0]

            return [round(float(x), 2) for x in final_prices]
        except Exception as e:
            print(f"❌ Forecast Error: {e}")
            return []