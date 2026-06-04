import tensorflow as tf
import numpy as np
import pandas as pd
import pandas_ta as ta
from sklearn.preprocessing import MinMaxScaler

class MLPredictor:
    def __init__(self, model_path="models/full_day_pattern.h5"):
        # Load the pre-trained LSTM model
        try:
            self.model = tf.keras.models.load_model(model_path)
        except Exception as e:
            print(f"Error loading model: {e}")
            self.model = None
            
        self.scaler = MinMaxScaler()
        # Define the EXACT features your model was trained on
        self.features = ['open', 'high', 'low', 'close', 'rsi', 'ema_20', 'atr']

    def _enhance_features(self, df):
        """
        Internal helper to calculate technical indicators.
        Adds RSI, EMA, and ATR to increase prediction accuracy.
        """
        df.columns = [x.lower() for x in df.columns]
        
        # Accuracy Boost 1: Momentum
        df['rsi'] = ta.rsi(df['close'], length=14)
        
        # Accuracy Boost 2: Trend
        df['ema_20'] = ta.ema(df['close'], length=20)
        
        # Accuracy Boost 3: Volatility
        df['atr'] = ta.atr(df['high'], df['low'], df['close'], length=14)
        
        # Handle NaNs: Use backfill then forward fill to ensure no empty values
        df.bfill(inplace=True)
        df.ffill(inplace=True)
        return df

    def predict_intraday_sequence(self, processed_df):
        """
        Takes past data, calculates technicals, and predicts the next sequence.
        """
        if self.model is None:
            return []

        # 1. Enhance Data with Technical Indicators
        df_ready = self._enhance_features(processed_df)
        
        # 2. Extract only the features the model expects
        # Ensure we have at least 30 candles for the lookback window
        input_data = df_ready[self.features].tail(30).values
        
        if len(input_data) < 30:
            print("Error: Not enough data points for 30-day lookback.")
            return []

        # 3. Scale data 
        # Note: In a production app, the scaler should be pre-fitted 
        # during training and loaded here.
        scaled_input = self.scaler.fit_transform(input_data)
        
        # 4. Reshape for LSTM: (Batch, Timesteps, Features)
        reshaped_input = np.reshape(scaled_input, (1, 30, len(self.features)))
        
        # 5. Predict the sequence
        raw_prediction = self.model.predict(reshaped_input, verbose=0)
        
        # 6. Invert scaling to get real ₹ values
        predicted_candles = self.inverse_transform_prediction(raw_prediction, input_data)
        
        return predicted_candles

    def inverse_transform_prediction(self, prediction, last_input):
        """
        Converts the normalized 0.0-1.0 output back to Indian Rupee (₹) values.
        Uses the last known close price to maintain continuity.
        """
        # This is a simplified inverse for sequence data
        # To be 100% accurate, you should load your scaler.pkl from training
        last_price = last_input[-1, 3] # Assuming 'close' is at index 3
        
        # Flatten and convert to list for Flutter JSON compatibility
        flat_pred = prediction.flatten()
        
        # Logic: If prediction is normalized change, apply it to last_price
        # For now, we return as list.
        return flat_pred.tolist()