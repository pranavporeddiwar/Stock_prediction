import sys
import os
import pandas as pd
from fastapi import FastAPI, HTTPException
import uvicorn
from fastapi.middleware.cors import CORSMiddleware
from main import get_prediction


# Add 'app' to system path for imports
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))


app = FastAPI()

# --- CORS SETUP ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- LOCAL CSV TOKEN LOOKUP ---
CSV_FILE_NAME = "NSE_Symbols.csv" 
token_df = None

def load_local_tokens():
    global token_df
    print(f"📂 Loading Local Token LUT: {CSV_FILE_NAME}...")
    try:
        token_df = pd.read_csv(CSV_FILE_NAME)
        token_df.columns = [c.strip() for c in token_df.columns]
        if 'exch_seg' in token_df.columns:
            token_df = token_df[token_df['exch_seg'] == 'NSE']
        print(f"✅ Successfully mapped {len(token_df)} NSE instruments.")
    except Exception as e:
        print(f"❌ Error reading CSV: {e}")

@app.on_event("startup")
async def startup_event():
    load_local_tokens()

def get_token_from_csv(user_input: str):
    if token_df is None: return None
    user_input = user_input.upper().strip()
    try:
        match = token_df[token_df['name'].str.upper() == user_input]
        if not match.empty:
            return str(match.iloc[0]['token'])
        match_alt = token_df[token_df['symbol'].str.upper() == user_input]
        if not match_alt.empty:
            return str(match_alt.iloc[0]['token'])
    except Exception as e:
        print(f"🔍 Search error: {e}")
    return None

# --- DYNAMIC API ROUTE ---
@app.get("/predict/{user_input}")
async def get_prediction(user_input: str):
    token = get_token_from_csv(user_input)
    
    if not token:
        return {"status": "error", "message": f"Symbol '{user_input}' not found."}

    print(f"🚀 Found Match: {user_input} -> Token {token}")

    # Pass the resolved token to the logic in main.py
    data = await get_prediction_data(symbol=user_input.upper(), token=token)
    
    if data:
        # We ensure 'status' is success because Flutter checks this
        return {**data, "status": "success"}
        
    return {
        "status": "offline", 
        "symbol": user_input.upper(),
        "current_price": 0.0, 
        "forecast": [], 
        "trend_percent": 0.0
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)