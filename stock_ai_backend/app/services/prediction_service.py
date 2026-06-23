import os
import joblib
import numpy as np
import pandas as pd
import tensorflow as tf

class PredictionService:
    def __init__(self, model_path='models/stock_lstm_pro.h5', scaler_path='models/scaler.pkl'):
        self.model_path = model_path
        self.scaler_path = scaler_path
        self.window_size = 60
        self.forecast_steps = 25

        # 1. Load Pre-Trained Weights into Memory
        if os.path.exists(self.model_path):
            try:
                self.model = tf.keras.models.load_model(self.model_path)
                print(f"🧠 AI Inference Engine: Loaded Long Short-Term Memory Network ({self.model_path})")
            except Exception as e:
                print(f"❌ AI Inference Engine: Critical Error loading model: {e}")
                self.model = None
        else:
            print(f"⚠️ AI Inference Engine: Target model file not found at {self.model_path}")
            self.model = None

        # 2. Load Master Scaler Parameters
        if os.path.exists(self.scaler_path):
            try:
                self.scaler = joblib.load(self.scaler_path)
                print(f"📏 AI Inference Engine: Loaded Global Market Scaler Parameters ({self.scaler_path})")
            except Exception as e:
                print(f"❌ AI Inference Engine: Error loading scaler configuration: {e}")
                self.scaler = None
        else:
            print(f"⚠️ AI Inference Engine: Scaler file missing at {self.scaler_path}.")
            self.scaler = None

    def generate_forecast(self, df: pd.DataFrame):
        """
        Processes historical stock ticks into a unified 6-dimensional feature space,
        applies scaling transformations, and handles the LSTM recurrent matrix loop.
        """
        if self.model is None:
            print("❌ Inference Aborted: Deep Learning Model Weights are not allocated.")
            return []

        # Exact case-sensitive sequence matching global model metrics
        features = ['close', 'h_o', 'pct_chng', 'rsi', 'atr', 'ema_20']
        
        try:
            # Clean dataframe layout mapping to ensure exact string matching
            df_working = df.copy()
            df_working.columns = [x.lower() for x in df_working.columns]

            # Structural fallback logic if technical columns are missing or casing dropped
            if 'rsi' not in df_working.columns and 'rsi' in df:
                df_working['rsi'] = df['RSI']
            if 'atr' not in df_working.columns and 'atr' in df:
                df_working['atr'] = df['ATR']
            if 'ema_20' not in df_working.columns and 'ema_20' in df:
                df_working['ema_20'] = df['EMA_20']

            # Extract our targeted feature matrix slice
            df_slice = df_working[features].astype(float)
            
            if len(df_slice) < self.window_size:
                print(f"⚠️ Insufficient data points. Need {self.window_size}, got {len(df_slice)}.")
                return []

            # 3. Transform data using features mapped explicitly to clear Sklearn version warnings
            if self.scaler is not None:
                # Build an identical DataFrame layout to retain feature name integrity
                scaler_df = pd.DataFrame(df_slice.values, columns=['close', 'h_o', 'pct_chng', 'RSI', 'ATR', 'EMA_20'])
                scaled_matrix = self.scaler.transform(scaler_df.values)
            else:
                from sklearn.preprocessing import MinMaxScaler
                fallback_scaler = MinMaxScaler()
                scaled_matrix = fallback_scaler.fit_transform(df_slice.values)

            # Isolate lookback sliding frame memory
            current_window = scaled_matrix[-self.window_size:].tolist()
            predicted_sequences = []

            # 4. Asynchronous-safe Recursive Inference Loop (Generates 25 time-steps)
            for _ in range(self.forecast_steps):
                # Isolate the exact window frame and structure into a 3D tensor: (Batch, Timesteps, Features)
                input_tensor = np.array([current_window[-self.window_size:]])
                
                # Run math calculation across the 6 features
                raw_prediction = self.model.predict(input_tensor, verbose=0)[0][0]
                
                # Advance lookback window with target state injection, keeping trailing indicators stable
                next_step_vector = [
                    raw_prediction,           # close
                    0.0,                      # h_o
                    0.0,                      # pct_chng
                    current_window[-1][3],    # RSI
                    current_window[-1][4],    # ATR
                    current_window[-1][5]     # EMA_20
                ]
                
                current_window.append(next_step_vector)
                predicted_sequences.append(raw_prediction)

            # 5. Inverse Scaler Mapping Translation (Matrix reconstruction back to absolute values)
            inversion_matrix = np.zeros((len(predicted_sequences), 6))
            inversion_matrix[:, 0] = predicted_sequences  # Bind scaled sequences onto close index parameter channel
            
            if self.scaler is not None:
                real_world_prices = self.scaler.inverse_transform(inversion_matrix)[:, 0]
            else:
                max_p, min_p = df_slice['close'].max(), df_slice['close'].min()
                real_world_prices = [p * (max_p - min_p) + min_p for p in predicted_sequences]

            # 6. Parse prices to perfectly structured chronological JSON formats for Syncfusion Charts
            formatted_future_path = []
            base_price = float(df_working['close'].iloc[-1])
            
            for index, mapped_price in enumerate(real_world_prices):
                # Adaptive filter to handle potential anomalous drift variance
                if abs(mapped_price - base_price) / base_price > 0.12:
                    mapped_price = base_price * (1.0 + (index * 0.001) if mapped_price > base_price else 1.0 - (index * 0.001))
                
                formatted_future_path.append({
                    "open": round(base_price if index == 0 else real_world_prices[index - 1], 2),
                    "high": round(max(mapped_price, base_price) * 1.001, 2),
                    "low": round(min(mapped_price, base_price) * 0.999, 2),
                    "close": round(mapped_price, 2),
                    "volume": int(df_working['volume'].iloc[-1]) if 'volume' in df_working.columns else 10000,
                    "time": None  # Handled dynamically downstream inside ai_agent.py
                })
                base_price = mapped_price

            return formatted_future_path

        except Exception as err:
            print(f"❌ Inference matrix processing crash occurred: {err}")
            return []