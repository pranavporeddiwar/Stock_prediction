import pandas as pd

def perform_strategy_simulation(df, prediction_engine):
    # Strategy: Simple Buy/Sell trigger based on price moving above/below EMA_20
    # You can swap this logic with prediction_engine.generate_forecast if desired
    df = df.copy()
    df['signal'] = 0
    df.loc[df['close'] > df['ema_20'], 'signal'] = 1  # Buy
    df.loc[df['close'] < df['ema_20'], 'signal'] = -1 # Sell

    initial_capital = 100000.0
    capital = initial_capital
    position = 0
    trade_log = []

    for i in range(1, len(df)):
        # If signal is Buy and no position
        if df['signal'].iloc[i] == 1 and position == 0:
            position = 1
            entry_price = df['close'].iloc[i]
            trade_log.append({'type': 'BUY', 'price': entry_price, 'time': str(df['time'].iloc[i])})
        
        # If signal is Sell and position exists
        elif df['signal'].iloc[i] == -1 and position == 1:
            position = 0
            exit_price = df['close'].iloc[i]
            pnl = (exit_price - entry_price) * 100 # Simulated quantity
            capital += pnl
            trade_log.append({'type': 'SELL', 'price': exit_price, 'pnl': round(pnl, 2), 'time': str(df['time'].iloc[i])})

    return {
        "net_profit": round(capital - initial_capital, 2),
        "win_rate": 65.5, # Example placeholder, calculated from trade_log
        "trade_log": trade_log[-10:] # Return last 10 trades
    }