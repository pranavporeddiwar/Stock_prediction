from app.core.data_fetcher import DataFetcher
def main():
    print("---  2026 LIVE MARKET TEST (YAHOO) ---")
    fetcher = DataFetcher()
    df = fetcher.fetch_tata_motors_data()
    if df is not None:
        print("\n--- TATA MOTORS (TMPV) LIVE PREVIEW ---")
        print(df.tail())
        print("\n DATA ACQUIRED! Your LSTM is ready to predict.")
    else:
        print("\n FAILED: Check your internet connection.")
if __name__ == "__main__":
    main()
