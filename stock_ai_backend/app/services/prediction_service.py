import os
import joblib
import numpy as np
import pandas as pd
import tensorflow as tf
class PredictionService:
    def __init__(self, model_path='models/stock_lstm_pro.h5', scaler_path='models/scaler.pkl'):
        self.model = self._load_model(model_path)
        self.scaler = self._load_scaler(scaler_path)
        self.window_size = 60
        self.forecast_steps = 25
    def _load_model(self, path):
        if not os.path.exists(path): return None
        try:
            return tf.keras.models.load_model(path, compile=False)
        except Exception as e:
            print(f" Model Load Error: {e}")
            return None
    def _load_scaler(self, path):
        return joblib.load(path) if os.path.exists(path) else None
    def generate_forecast(self, df: pd.DataFrame):
        if self.model is None: return []
        features = ['close', 'h_o', 'pct_chng', 'rsi', 'atr', 'ema_20']
        df_working = df.copy()
        try:
            df_slice = df_working[features].astype(float)
            if len(df_slice) < self.window_size: return []
            scaled_matrix = self.scaler.transform(df_slice.values) if self.scaler else df_slice.values
            current_window = scaled_matrix[-self.window_size:].tolist()
            predicted_prices = []
            for _ in range(self.forecast_steps):
                input_tensor = np.array([current_window[-self.window_size:]])
                pred = self.model.predict(input_tensor, verbose=0)[0][0]
                next_vec = [pred, 0.0, 0.0, current_window[-1][3], current_window[-1][4], current_window[-1][5]]
                current_window.append(next_vec)
                predicted_prices.append(pred)
            if self.scaler:
                inv_mat = np.zeros((len(predicted_prices), 6))
                inv_mat[:, 0] = predicted_prices
                real_prices = self.scaler.inverse_transform(inv_mat)[:, 0]
            else:
                real_prices = predicted_prices
            return [{"close": round(p, 2), "open": round(p, 2), "high": round(p*1.001, 2), "low": round(p*0.999, 2)} for p in real_prices]
        except Exception as e:
            print(f" Inference Matrix Error: {e}")
            return []
