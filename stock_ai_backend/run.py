import sys
import os

# Ensure the app folder is visible to Python
project_root = os.path.dirname(os.path.abspath(__file__))
app_path = os.path.join(project_root, "app")

sys.path.insert(0, project_root)
sys.path.insert(0, app_path)

try:
    from app.main import main
except ImportError as e:
    print(f"❌ Initialization Error: {e}")
    sys.exit(1)

if __name__ == "__main__":
    print("🔧 System Initialized. Starting AI Agent...")
    main()