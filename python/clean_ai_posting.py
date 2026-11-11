"""
Step 2 - Indeed Hiring Lab AI Tracker: daily data -> monthly table.
Source: Indeed Hiring Lab AI Tracker (CC-BY-4.0). Values are 7-day moving averages (%).
Metric: share of job postings that mention AI (NOT a direct measure of AI-skill demand).
Output: data/clean/ai_posting_monthly.csv (country x month, monthly mean)
"""
import sys
from pathlib import Path

import pandas as pd

DATA = Path(__file__).resolve().parent.parent / "data"
INPUT = sys.argv[1] if len(sys.argv) > 1 else str(DATA / "raw" / "indeed_ai_posting.csv")
OUTPUT = sys.argv[2] if len(sys.argv) > 2 else str(DATA / "clean" / "ai_posting_monthly.csv")
COUNTRY = {"AU": "Australia", "CA": "Canada", "DE": "Germany", "FR": "France", "GB": "United Kingdom",
           "IE": "Ireland", "IT": "Italy", "NL": "Netherlands", "US": "United States"}

df = pd.read_csv(INPUT, parse_dates=["date"])
df["month"] = df["date"].dt.to_period("M").astype(str)
m = (df.groupby(["jobcountry", "month"])["AI_share_postings"].mean().round(3)
     .reset_index().rename(columns={"jobcountry": "country_code", "AI_share_postings": "ai_share_pct"}))
m["country_name"] = m["country_code"].map(COUNTRY)
# Year-over-year change in percentage points (same month one year earlier)
m["yoy_change_pt"] = m.groupby("country_code")["ai_share_pct"].diff(12).round(3)
# Canada: from 1 Jan 2026 Ontario requires job postings to disclose the use of AI in hiring
m["note"] = ""
m.loc[(m.country_code == "CA") & (m.month >= "2025-10"), "note"] = \
    "Ontario AI-disclosure requirement; not interpretable as AI-skill demand"
m["comparable"] = m["note"].eq("")
m.to_csv(OUTPUT, index=False)
print(m.shape, m.month.min(), "->", m.month.max())
