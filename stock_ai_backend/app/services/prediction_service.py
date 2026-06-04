import numpy as np
import pandas as pd
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout

class PredictionService:
    def __init__(self):
        # We scale data between 0 and 1 for accurate LSTM weight distribution
        self.scaler = MinMaxScaler(feature_range=(0, 1))
        self.lookback = 60 # Look at the last 60 candles to predict the next trend

    def build_model(self, input_shape):
        """Builds a robust, dropout-protected LSTM."""
        model = Sequential()
        
        # Layer 1: 50 Neurons, return sequences for the next LSTM layer
        model.add(LSTM(units=50, return_sequences=True, input_shape=input_shape))
        model.add(Dropout(0.2)) # Randomly turns off 20% of neurons to prevent overfitting
        
        # Layer 2: 50 Neurons
        model.add(LSTM(units=50, return_sequences=False))
        model.add(Dropout(0.2))
        
        # Output Layer: Predicts the next scaled numerical value
        model.add(Dense(units=1))
        
        model.compile(optimizer='adam', loss='mean_squared_error')
        return model

    def predict(self, df):
        """
        Trains a quick lightweight model on the current stock's recent history
        and predicts the baseline trend.
        """
        try:
            # 1. Feature Selection (Multi-variate is more accurate)
            # Ensure your data_fetcher provides these columns
            features = ['close'] 
            data = df[features].values
            
            if len(data) < self.lookback + 10:
                print("⚠️ Not enough data for accurate LSTM sequence. Need at least 70 candles.")
                # Return a simple moving average as a fallback
                return [float(df['close'].iloc[-1])] * 5

            # 2. Scale the data
            scaled_data = self.scaler.fit_transform(data)

            # 3. Create sequences (X) and targets (y)
            X_train, y_train = [], []
            for i in range(self.lookback, len(scaled_data)):
                X_train.append(scaled_data[i-self.lookback:i, 0])
                y_train.append(scaled_data[i, 0])
                
            X_train, y_train = np.array(X_train), np.array(y_train)
            X_train = np.reshape(X_train, (X_train.shape[0], X_train.shape[1], 1))

            # 4. Train the model quickly (Epochs kept low for speed during your live demo)
            model = self.build_model((X_train.shape[1], 1))
            model.fit(X_train, y_train, epochs=3, batch_size=32, verbose=0)

            # 5. Predict the future trend
            last_60_days = scaled_data[-self.lookback:]
            X_test = np.array([last_60_days])
            X_test = np.reshape(X_test, (X_test.shape[0], X_test.shape[1], 1))
            
            predicted_scaled_price = model.predict(X_test, verbose=0)
            
            # 6. Inverse scale back to real Rupee values
            predicted_price = self.scaler.inverse_transform(predicted_scaled_price)
            
            # Return the predicted trend (we send the numerical base to Groq)
            base_prediction = float(predicted_price[0][0])
            
            # Create a simple 5-step mathematical slope to pass to Llama-3
            current_price = float(df['close'].iloc[-1])
            step = (base_prediction - current_price) / 5
            lstm_trend = [current_price + (step * i) for i in range(1, 6)]
            
            return lstm_trend

        except Exception as e:
            print(f"❌ LSTM Math Error: {e}")
            return [float(df['close'].iloc[-1])] * 5