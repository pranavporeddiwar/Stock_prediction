import socket
import os
import re

# --- CONFIGURATION ---
# Path to your Flutter API service file (Double-check this path is correct)
FLUTTER_API_PATH = r"D:\prediction\prediction_application_1\lib\services\api_service.dart"

def get_current_ip():
    """Detects the current local IP address of the PC on the active network."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # We use a public IP to trigger the routing table (doesn't actually send data)
        s.connect(('8.8.8.8', 80))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

def sync_ip():
    current_ip = get_current_ip()
    new_url = f"http://{current_ip}:8000"
    
    if not os.path.exists(FLUTTER_API_PATH):
        print(f"❌ Error: File not found at {FLUTTER_API_PATH}")
        return

    try:
        with open(FLUTTER_API_PATH, 'r', encoding='utf-8') as f:
            content = f.read()

        # Regex: finds the line regardless of what the old IP was
        pattern = r'static const String baseUrl = "http://.*:8000";'
        replacement = f'static const String baseUrl = "{new_url}";'
        
        if re.search(pattern, content):
            updated_content = re.sub(pattern, replacement, content)
            
            with open(FLUTTER_API_PATH, 'w', encoding='utf-8') as f:
                f.write(updated_content)
                
            print(f"✅ SUCCESS: Flutter baseUrl is now {new_url}")
        else:
            print("⚠️ Warning: Could not find the 'baseUrl' variable in your Dart file.")
            print("Make sure it looks like: static const String baseUrl = \"http://...:8000\";")

    except Exception as e:
        print(f"❌ Critical Error: {e}")

if __name__ == "__main__":
    sync_ip()