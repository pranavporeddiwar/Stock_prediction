import requests

class TruthVerifier:
    def __init__(self):
        # 2026 High-Authority Domains (Added moneycontrol as it's vital for Indian stocks)
        self.whitelist = [
            "reuters.com", 
            "bloomberg.com", 
            "economictimes.indiatimes.com", 
            "nseindia.com",
            "moneycontrol.com"
        ]

    def verify_news(self, news_items):
        """
        Safely filters news from verified domains.
        Handles variations in Yahoo Finance news keys (link vs url).
        """
        verified_titles = []
        
        for item in news_items:
            # Safe access: Yahoo news items usually use 'link', but we check 'url' too
            source_link = item.get('link', item.get('url', '')).lower()
            title = item.get('title', 'No Title Found')

            # Check if any trusted domain is a substring of the link
            if any(domain in source_link for domain in self.whitelist):
                verified_titles.append(title)
        
        return verified_titles

    def check_consensus(self, headline, all_verified_titles):
        """
        Verifies if a specific news event is being reported by 
        multiple trusted outlets (Consensus check).
        """
        if not all_verified_titles:
            return False
            
        # Count how many verified headlines contain similar keywords
        # This prevents acting on a single 'outlier' report
        keywords = headline.lower().split()[:3]  # Take first 3 words as a 'signature'
        match_count = 0
        
        for title in all_verified_titles:
            if all(word in title.lower() for word in keywords):
                match_count += 1
        
        # In real trading, consensus is reached if 2+ trusted sources agree
        return match_count >= 2