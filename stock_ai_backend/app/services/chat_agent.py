import os
from groq import Groq

client = Groq(api_key="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")

def get_tutor_response(user_message: str, app_context: str = "General Market Watchlist"):
    """
    Translates complex quantitative trading jargon into beginner-friendly advice,
    using the exact screen context the user is currently viewing.
    """
    system_prompt = f"""
    You are 'Neural Tutor', an empathetic AI assistant inside a stock trading app. 
    Your job is to explain trading concepts to absolute beginners.
    
    CRITICAL: The user is currently looking at this part of the app: 
    [{app_context}]
    
    Use this context to tailor your answers. If they ask "Why did it say buy?", refer to the stock and indicators in the context.
    
    RULES:
    1. Keep answers short and digestible (max 2-3 short paragraphs).
    2. Use simple analogies.
    3. Never give direct financial advice to risk real money.
    """

    try:
        chat_completion = client.chat.completions.create(
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_message}
            ],
            model="llama-3.1-8b-instant", 
            temperature=0.6, 
        )
        return chat_completion.choices[0].message.content
        
    except Exception as e:
        print(f"❌ Chat Engine Error: {e}")
        return "I'm having a little trouble connecting to my neural network right now. Give me a second and try again!"