import pyotp
from SmartApi import SmartConnect

# --- ENTER YOUR KEYS HERE ---
API_KEY = "Ecjx5XVO"
CLIENT_ID = "AACG809670"
PIN = "2506"
TOTP_SECRET = "OXF4PBD7WHFG43JPXOS7WC5ISU"

# 1. Initialize
obj = SmartConnect(api_key=API_KEY)

# 2. Generate TOTP
totp = pyotp.TOTP(TOTP_SECRET).now()

# 3. Login
data = obj.generateSession(CLIENT_ID, PIN, totp)

if data['status']:
    print("✅ CONNECTION SUCCESS!")
    print(f"Logged in as: {data['data']['name']}")
    
    # Optional: Get your balance
    balance = obj.rmsLimit()
    print(f"Current Balance: ₹{balance['data']['net']}")
else:
    print(f"❌ LOGIN FAILED: {data['message']}")