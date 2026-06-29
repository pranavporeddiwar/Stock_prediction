import tensorflow as tf
import numpy as np
import pandas as pd
import pandas_ta as ta
from sklearn.preprocessing import MinMaxScaler
class MLPredictor:
    def __init__(self, model_path="models/full_day_pattern.h5"):
        try:
            self.model = tf.keras.models.load_model(model_path)
        except Exception as e:
            print(f"Error loading model: {e}")
            self.model = None
        self.scaler = MinMaxScaler()
        self.features = ['open', 'high', 'low', 'close', 'rsi', 'ema_20', 'atr']
    def _enhance_features(self, df):
        df.columns = [x.lower() for x in df.columns]
        df['rsi'] = ta.rsi(df['close'], length=14)
        df['ema_20'] = ta.ema(df['close'], length=20)
        df['atr'] = ta.atr(df['high'], df['low'], df['close'], length=14)
        df.bfill(inplace=True)
        df.ffill(inplace=True)
        return df
    def predict_intraday_sequence(self, processed_df):
        if self.model is None:
            return []
        df_ready = self._enhance_features(processed_df)
        input_data = df_ready[self.features].tail(30).values
        if len(input_data) < 30:
            print("Error: Not enough data points for 30-day lookback.")
            return []
        scaled_input = self.scaler.fit_transform(input_data)
        reshaped_input = np.reshape(scaled_input, (1, 30, len(self.features)))
        raw_prediction = self.model.predict(reshaped_input, verbose=0)
        predicted_candles = self.inverse_transform_prediction(raw_prediction, input_data)
        return predicted_candles
    def inverse_transform_prediction(self, prediction, last_input):
        last_price = last_input[-1, 3]
        flat_pred = prediction.flatten()
        return flat_pred.tolist()
