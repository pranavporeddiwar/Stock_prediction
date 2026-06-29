import requests
class TruthVerifier:
    def __init__(self):
        self.whitelist = [
            "reuters.com",
            "bloomberg.com",
            "economictimes.indiatimes.com",
            "nseindia.com",
            "moneycontrol.com"
        ]
    def verify_news(self, news_items):
        verified_titles = []
        for item in news_items:
            source_link = item.get('link', item.get('url', '')).lower()
            title = item.get('title', 'No Title Found')
            if any(domain in source_link for domain in self.whitelist):
                verified_titles.append(title)
        return verified_titles
    def check_consensus(self, headline, all_verified_titles):
        if not all_verified_titles:
            return False
        keywords = headline.lower().split()[:3]
        match_count = 0
        for title in all_verified_titles:
            if all(word in title.lower() for word in keywords):
                match_count += 1
        return match_count >= 2
