import os
import yfinance as yf
from google import genai

class NewsService:
    def __init__(self):
        self.api_key = os.getenv("GEMINI_API_KEY")
        self.has_ai = False
        if self.api_key and self.api_key != "MISSING":
            try:
                self.client = genai.Client(api_key=self.api_key)
                self.has_ai = True
            except: pass

    def get_verified_sentiment(self, symbol):
        """Returns a tuple of (sentiment_score, list_of_headlines)"""
        try:
            stock = yf.Ticker(f"{symbol}.NS")
            news_list = stock.news[:4] # Take top 4 headlines
            
            if not news_list:
                return 0.5, ["No recent news found for this symbol."]
            
            # Extract headlines for the UI and the AI
            headlines = [item.get('title', '') for item in news_list]
            
            if not self.has_ai:
                return 0.5, headlines

            prompt = f"Analyze market sentiment (0.0 to 1.0) for {symbol} based on these headlines: {headlines}. Return ONLY the number."
            res = self.client.models.generate_content(model="gemini-2.0-flash", contents=prompt)
            
            try:
                score = float(res.text.strip())
            except:
                score = 0.5
                
            return score, headlines
        except Exception as e:
            print(f"News Error: {e}")
            return 0.5, ["Error fetching news data."]