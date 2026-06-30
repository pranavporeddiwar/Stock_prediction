import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense
import tensorflow as tf

# Suppress tf logs
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
tf.get_logger().setLevel('ERROR')

def run_experiment():
    df = pd.read_parquet('data/ai_ready/SBIN_ready.parquet')
    
    # We will pick a fixed test point near the end of the dataset
    features = ['Close', 'h_o', 'pct_chng', 'sma_5']
    target_col = 'target'
    
    # The last row is our test point
    test_idx = len(df) - 1
    actual_val = df.iloc[test_idx][target_col]
    
    # Different training sizes (in days)
    lookback = 10
    training_sizes = [30, 90, 180, 360, 720, 1440]
    
    predictions = []
    
    for size in training_sizes:
        print(f"Training on {size} days of real SBIN data...")
        start_idx = test_idx - size - lookback
        if start_idx < 0:
            start_idx = 0
            
        train_df = df.iloc[start_idx : test_idx].copy()
        
        scaler_x = MinMaxScaler()
        scaler_y = MinMaxScaler()
        
        scaled_x = scaler_x.fit_transform(train_df[features])
        scaled_y = scaler_y.fit_transform(train_df[[target_col]])
        
        X_train, y_train = [], []
        for i in range(lookback, len(scaled_x)):
            X_train.append(scaled_x[i-lookback:i])
            y_train.append(scaled_y[i])
            
        X_train, y_train = np.array(X_train), np.array(y_train)
        
        # Build a small fast LSTM
        model = Sequential([
            LSTM(32, input_shape=(lookback, len(features))),
            Dense(1)
        ])
        model.compile(optimizer='adam', loss='mse')
        
        if len(X_train) > 0:
            model.fit(X_train, y_train, epochs=10, batch_size=16, verbose=0)
            
            test_x_data = df.iloc[test_idx - lookback : test_idx][features]
            scaled_test_x = scaler_x.transform(test_x_data)
            
            pred_scaled = model.predict(np.array([scaled_test_x]), verbose=0)
            pred_val = scaler_y.inverse_transform(pred_scaled)[0][0]
        else:
            pred_val = 0
            
        predictions.append(pred_val)
        print(f" -> Size: {size}, Predicted: {pred_val:.2f}, Actual: {actual_val:.2f}")

    # Plotting
    plt.style.use('dark_background')
    fig, ax = plt.subplots(figsize=(12, 6))
    fig.patch.set_facecolor('#111317')
    ax.set_facecolor('#111317')

    x_labels = [str(s) for s in training_sizes]
    x = np.arange(len(x_labels))
    actual = [actual_val] * len(training_sizes)

    ax.plot(x, actual, color='#4ade80', marker='s', linestyle='-', linewidth=2, markersize=8, label='Actual Stock Price (SBIN)')
    ax.plot(x, predictions, color='#3b82f6', marker='o', linestyle=':', linewidth=3, markersize=8, label='NeuroTick AI Prediction')

    # Y-axis limits
    all_vals = actual + predictions
    margin = (max(all_vals) - min(all_vals)) * 0.2
    if margin == 0: margin = 10
    ax.set_ylim(min(all_vals) - margin, max(all_vals) + margin)

    ax.grid(color='#2d3748', linestyle='-', linewidth=0.5)

    ax.set_xticks(x)
    ax.set_xticklabels(x_labels)
    ax.set_xlabel('AMOUNT OF TRAINING DATA (Number of Days)', color='white')
    ax.set_ylabel('STOCK PRICE / PREDICTION VALUE (INR)', color='white')
    ax.set_title('REAL EXPERIMENTAL RESULTS (SBIN): DATA TRAINED vs PREDICTION vs ACTUAL\nProject Start Day: 11/07/2025', color='white', pad=20, fontsize=14, fontweight='bold')

    ax.legend(loc='upper left', facecolor='#111317', edgecolor='#4a5568', fontsize=11)

    for i, pred in enumerate(predictions):
        ax.text(i, pred, f' {pred:.2f}', color='#3b82f6', ha='left', va='bottom', fontsize=10, fontweight='bold')
    
    ax.text(len(predictions)-1, actual_val, f' Actual: {actual_val:.2f}', color='#4ade80', ha='left', va='top', fontsize=10, fontweight='bold')
        
    for spine in ax.spines.values():
        spine.set_color('#4a5568')

    plt.tight_layout()
    plt.savefig('real_experiment_results.png', dpi=300, bbox_inches='tight', facecolor=fig.get_facecolor())
    print("Graph generated successfully as real_experiment_results.png")

if __name__ == '__main__':
    run_experiment()
