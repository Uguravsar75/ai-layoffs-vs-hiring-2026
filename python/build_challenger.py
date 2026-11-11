"""
AI Söylemi ve Gerçeklik - Adım 3: Challenger, Gray & Christmas aylık tablosu (ABD, Oca-Eki 2026)
Kaynak: Challenger aylık raporları (challengergray.com) ve raporu aktaran haberler. Rakamlar 2026-11-11'de toplandı.

Challenger rakamları "duyurulan" kesinti planlarıdır (ABD merkezli işverenler) ve
AI rakamı işverenin BEYAN ETTİĞİ gerekçedir; doğrulanmış neden değildir.

Kontrol: Aylık rakamların toplamı, Challenger'ın kendi raporlarında verdiği yılbaşından bugüne
(YTD) toplamlarla birebir tutmalı. Tutmazsa script hata verir.

Çıktılar:
- data/clean/challenger_ai_monthly.csv   : 10 satır, her satırın kaynağı ile
- data/clean/challenger_vs_layoffhedge.csv : aynı ayda layoffhedge AI payları ile yan yana
"""
from pathlib import Path

import pandas as pd

VERI = Path(__file__).resolve().parent.parent / "data" / "clean"

# ay: (toplam ABD kesintisi, AI gerekçeli kesinti, kaynak, not)
CHALLENGER = {
    "2026-01": (108435, 7624,
                "https://www.challengergray.com/blog/challenger-report-february-cuts-plunge-hiring-falls-56-percent/",
                "Toplam Şubat raporundan; AI = Şubat YTD 12.304 - Şubat 4.680 (türetildi)"),
    "2026-02": (48307, 4680,
                "https://www.challengergray.com/blog/challenger-report-february-cuts-plunge-hiring-falls-56-percent/",
                "AI YTD 12.304 (%8)"),
    "2026-03": (60620, 15341,
                "https://searchenginejournal.com/ai-leads-all-reasons-for-u-s-job-cuts-in-march-report-says/571065",
                "AI ilk kez 1. sırada; ikincil kaynak, YTD zinciriyle teyit edildi"),
    "2026-04": (83387, 21490,
                "https://www.cbsnews.com/news/ai-layoffs-job-cuts-challenger-report-april-2026/",
                "Toplam YTD 300.749"),
    "2026-05": (97006, 38579,
                "https://foxbusiness.com/economy/ai-remains-top-reason-us-job-cuts-third-straight-month-employers-axed-97000-workers-may",
                "AI için rekor ay; AI YTD 87.714 (%22)"),
    "2026-06": (45849, 14029,
                "https://www.challengergray.com/?p=28455",
                "AI YTD 101.743 (%23)"),
    "2026-07": (33429, 10970,
                "https://www.challengergray.com/?p=28706",
                "AI 5. ay üst üste 1. sırada; AI YTD 112.713, toplam YTD 477.033"),
    "2026-08": (52881, 3462,
                "https://www.challengergray.com/?p=28858",
                "AI 4. sıraya düştü (1. yeniden yapılanma 16.173); AI YTD 116.175"),
    "2026-09": (43281, 3961,
                "https://www.cpapracticeadvisor.com/2026/10/01/u-s-companies-announce-fewest-job-cuts-for-a-september-since-2022/190969",
                "AI 5. sırada; AI YTD 120.136, toplam YTD 573.195. Bir haberdeki '7.000' YTD zinciriyle tutmuyor, kullanılmadı"),
    "2026-10": (43994, 1265,
                "https://tradingeconomics.com/united-states/challenger-job-cuts/news/598602",
                "Yılın en düşük AI ayı; AI YTD 121.401, toplam YTD 617.189 (yıllık -%44)"),
}

# Challenger'ın raporlarında yazan YTD toplamlar (kontrol için)
YTD_AI = {"2026-02": 12304, "2026-05": 87714, "2026-06": 101743, "2026-07": 112713,
          "2026-08": 116175, "2026-09": 120136, "2026-10": 121401}
YTD_TOPLAM = {"2026-04": 300749, "2026-07": 477033, "2026-09": 573195, "2026-10": 617189}


def main():
    ch = pd.DataFrame([{"month": ay, "total_us_cuts": t, "ai_attributed_cuts": a,
                        "source_url": url, "note": not_}
                       for ay, (t, a, url, not_) in CHALLENGER.items()])
    ch["ai_share_pct"] = (ch["ai_attributed_cuts"] / ch["total_us_cuts"] * 100).round(1)
    ch["ai_ytd_cuts"] = ch["ai_attributed_cuts"].cumsum()
    ch["total_ytd_cuts"] = ch["total_us_cuts"].cumsum()

    # Tutarlılık kontrolü: aylıkların toplamı = raporlardaki YTD
    for ay, beklenen in YTD_AI.items():
        bulunan = ch.loc[ch["month"] == ay, "ai_ytd_cuts"].item()
        assert bulunan == beklenen, f"AI YTD tutmuyor {ay}: {bulunan} != {beklenen}"
    for ay, beklenen in YTD_TOPLAM.items():
        bulunan = ch.loc[ch["month"] == ay, "total_ytd_cuts"].item()
        assert bulunan == beklenen, f"Toplam YTD tutmuyor {ay}: {bulunan} != {beklenen}"
    print(f"YTD kontrolü: {len(YTD_AI)} AI + {len(YTD_TOPLAM)} toplam kontrol noktası tuttu")

    kolonlar = ["month", "total_us_cuts", "ai_attributed_cuts", "ai_share_pct",
                "ai_ytd_cuts", "total_ytd_cuts", "source_url", "note"]
    ch[kolonlar].to_csv(VERI / "challenger_ai_monthly.csv", index=False)

    # layoffhedge ile karşılaştırma (aynı aylar)
    lh = pd.read_csv(VERI / "layoffs_clean_monthly.csv")[
        ["month", "ai_strict_share_pct", "ai_share_pct_upper", "ai_strict_count_share_pct"]]
    kar = ch[["month", "ai_share_pct"]].rename(columns={"ai_share_pct": "challenger_ai_share_pct"}) \
        .merge(lh.rename(columns={"ai_strict_share_pct": "lh_ai_strict_people_pct",
                                  "ai_share_pct_upper": "lh_ai_upper_people_pct",
                                  "ai_strict_count_share_pct": "lh_ai_strict_count_pct"}), on="month")
    kar.to_csv(VERI / "challenger_vs_layoffhedge.csv", index=False)

    pd.set_option("display.width", 200)
    print(ch[["month", "total_us_cuts", "ai_attributed_cuts", "ai_share_pct"]].to_string(index=False))
    print()
    print(kar.to_string(index=False))
    print()
    for kol in ["lh_ai_strict_people_pct", "lh_ai_upper_people_pct", "lh_ai_strict_count_pct"]:
        print(f"Challenger ile korelasyon ({kol}): Pearson {kar['challenger_ai_share_pct'].corr(kar[kol]):.2f}"
              f" | Spearman {kar['challenger_ai_share_pct'].corr(kar[kol], method='spearman'):.2f}")
    ilk, son = kar[kar.month <= "2026-07"], kar[kar.month >= "2026-08"]
    print("\nDönem ortalaması (Oca-Tem | Ağu-Eki):")
    for kol in ["challenger_ai_share_pct", "lh_ai_strict_people_pct", "lh_ai_strict_count_pct"]:
        print(f"  {kol}: {ilk[kol].mean():.1f} | {son[kol].mean():.1f}")


if __name__ == "__main__":
    main()
