import socket
import os
import re
FLUTTER_API_PATH = r"D:\prediction\prediction_application_1\lib\services\api_service.dart"
def get_current_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
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
        print(f" Error: File not found at {FLUTTER_API_PATH}")
        return
    try:
        with open(FLUTTER_API_PATH, 'r', encoding='utf-8') as f:
            content = f.read()
        pattern = r'static const String baseUrl = "http://.*:8000";'
        replacement = f'static const String baseUrl = "{new_url}";'
        if re.search(pattern, content):
            updated_content = re.sub(pattern, replacement, content)
            with open(FLUTTER_API_PATH, 'w', encoding='utf-8') as f:
                f.write(updated_content)
            print(f" SUCCESS: Flutter baseUrl is now {new_url}")
        else:
            print(" Warning: Could not find the 'baseUrl' variable in your Dart file.")
            print("Make sure it looks like: static const String baseUrl = \"http://...:8000\";")
    except Exception as e:
        print(f" Critical Error: {e}")
if __name__ == "__main__":
    sync_ip()
