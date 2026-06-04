import pandas as pd
import numpy as np

class PatternDetector:
    @staticmethod
    def analyze_patterns(df):
        """
        Calculates Technical Indicators and Market Volatility (ATR).
        """
        # 1. Calculate RSI (Relative Strength Index)
        delta = df['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        df['RSI'] = 100 - (100 / (1 + rs))

        # 2. Calculate ATR (Average True Range) for Dynamic Risk
        # TR = Max[(High - Low), |High - Prev Close|, |Low - Prev Close|]
        high_low = df['high'] - df['low']
        high_cp = (df['high'] - df['close'].shift(1)).abs()
        low_cp = (df['low'] - df['close'].shift(1)).abs()
        
        tr = pd.concat([high_low, high_cp, low_cp], axis=1).max(axis=1)
        df['ATR'] = tr.rolling(window=14).mean()

        # 3. Moving Averages
        df['EMA_20'] = df['close'].ewm(span=20, adjust=False).mean()
        
        # Fill NaNs to avoid JSON errors
        df = df.fillna(method='bfill').fillna(0)
        
        return df