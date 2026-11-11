"""
AI Söylemi ve Gerçeklik - Adım 2: Indeed AI_posting.csv -> aylık tablo
Kaynak: Indeed Hiring Lab AI Tracker (CC-BY-4.0). Değerler 7 günlük hareketli ortalama (%).
Çıktı: ai_posting_monthly.csv (ülke x ay, aylık ortalama)
"""
import sys
from pathlib import Path

import pandas as pd

VERI = Path(__file__).resolve().parent.parent / "data"
GIRDI = sys.argv[1] if len(sys.argv) > 1 else str(VERI / "raw" / "indeed_ai_posting.csv")
CIKTI = sys.argv[2] if len(sys.argv) > 2 else str(VERI / "clean" / "ai_posting_monthly.csv")
ULKE = {"AU": "Avustralya", "CA": "Kanada", "DE": "Almanya", "FR": "Fransa", "GB": "Birleşik Krallık",
        "IE": "İrlanda", "IT": "İtalya", "NL": "Hollanda", "US": "ABD"}

df = pd.read_csv(GIRDI, parse_dates=["date"])
df["month"] = df["date"].dt.to_period("M").astype(str)
m = (df.groupby(["jobcountry", "month"])["AI_share_postings"].mean().round(3)
     .reset_index().rename(columns={"jobcountry": "country_code", "AI_share_postings": "ai_share_pct"}))
m["country_name"] = m["country_code"].map(ULKE)
m["yoy_change_pt"] = m.groupby("country_code")["ai_share_pct"].diff(12).round(3)
# Kanada: Ontario'da 1 Ocak 2026'dan itibaren ilanlarda işe alımda AI kullanımını açıklama zorunluluğu
m["note"] = ""
m.loc[(m.country_code == "CA") & (m.month >= "2025-10"), "note"] = \
    "Ontario AI açıklama zorunluluğu etkisi; AI becerisi talebi olarak yorumlanmamalı"
m["comparable"] = m["note"].eq("")
m.to_csv(CIKTI, index=False)
print(m.shape, m.month.min(), "->", m.month.max())
