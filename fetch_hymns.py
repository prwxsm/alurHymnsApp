import requests
import json
import os

url = "https://jnshortxtmxlfzoeqcqo.supabase.co/rest/v1/hymns?select=*"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impuc2hvcnR4dG14bGZ6b2VxY3FvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQxNDcyODgsImV4cCI6MjA1OTcyMzI4OH0.XD4vQPoEmOhYFy-SWbOmHN7jpzqJx-0IvngJaBLwKSU",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impuc2hvcnR4dG14bGZ6b2VxY3FvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQxNDcyODgsImV4cCI6MjA1OTcyMzI4OH0.XD4vQPoEmOhYFy-SWbOmHN7jpzqJx-0IvngJaBLwKSU"
}

print("Fetching hymns from Supabase...")
response = requests.get(url, headers=headers)
if response.status_code == 200:
    data = response.json()
    os.makedirs("assets", exist_ok=True)
    with open("assets/hymns.json", "w", encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Successfully saved {len(data)} hymns to assets/hymns.json")
else:
    print(f"Failed to fetch: {response.status_code}")
    print(response.text)
