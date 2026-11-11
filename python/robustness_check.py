"""
Sağlamlık testi: Ana bulgular, verinin farklı güvenilirlik seviyelerinde aynı kalıyor mu?
- Tüm ana analiz (T1-T5)
- Doğrulanmış çekirdek (T1-T3: elle doğrulanan, kısmen doğrulanan, güçlü kaynaklı)
- Sadece elle doğrulanan (T1-T2)
AI payı her yerde iki tanımla verilir: sıkı (ANA RAKAM) ve geniş (üst sınır).
Zaman trendi iki ölçüyle verilir: kişi bazlı pay ve duyuru sayısı bazlı pay.
Çıktı: robustness_check.csv (girdi dosyasıyla aynı klasöre)
"""
import sys
from pathlib import Path

import pandas as pd

GIRDI = Path(sys.argv[1]) if len(sys.argv) > 1 else \
    Path(__file__).resolve().parent.parent / "data" / "clean" / "layoffs_clean.csv"
df = pd.read_csv(GIRDI)
ana = df[df["in_main_analysis"]]
setler = {
    "1_tum_veri": ana,
    "2_cekirdek_T1_T3": ana[ana["in_core_verified"]],
    "3_sadece_elle_T1_T2": ana[ana["reliability_tier"].isin(["T1_elle_dogrulandi", "T2_elle_kismen"])],
}


def aylik_pay(d, kolon, sayi=False):
    """Her ay için AI payı (%). sayi=True -> duyuru sayısı bazlı, değilse kişi bazlı."""
    d = d[d["month"].notna()]
    if sayi:
        return d.groupby("month")[kolon].mean() * 100
    return d.groupby("month").apply(
        lambda g: g.loc[g[kolon], "people_cut"].sum() / g["people_cut"].sum() * 100, include_groups=False)


def donem(seri, bas, son):
    return round(seri.loc[bas:son].mean(), 1)


def bulgular(d):
    ai, siki = d[d["is_ai_driven"]], d[d["is_ai_strict"]]
    sektor = d.groupby("industry")["people_cut"].sum().sort_values(ascending=False)
    kisi_siki, kisi_genis = aylik_pay(d, "is_ai_strict"), aylik_pay(d, "is_ai_driven")
    sayi_siki = aylik_pay(d, "is_ai_strict", sayi=True)
    return {
        "satir": len(d),
        "kisi": int(d["people_cut"].sum()),
        "kisi_payi_tum_veriye_gore_%": None,
        "sektor_1": sektor.index[0], "sektor_2": sektor.index[1], "sektor_3": sektor.index[2],
        "ai_kisi_payi_siki_%": round(siki["people_cut"].sum() / d["people_cut"].sum() * 100, 1),
        "ai_kisi_payi_genis_%": round(ai["people_cut"].sum() / d["people_cut"].sum() * 100, 1),
        "ai_duyuru_payi_siki_%": round(len(siki) / len(d) * 100, 1),
        "ai_duyuru_payi_genis_%": round(len(ai) / len(d) * 100, 1),
        "ai_siki_medyan_kisi": float(siki["people_cut"].median()),
        "ai_genis_medyan_kisi": float(ai["people_cut"].median()),
        "diger_medyan_kisi": float(d.loc[~d["is_ai_driven"], "people_cut"].median()),
        "ai_medyan_sirket_buyuklugu": float(ai["total_workforce"].median()),
        "diger_medyan_sirket_buyuklugu": float(d.loc[~d["is_ai_driven"], "total_workforce"].median()),
        "kisi_payi_siki_oca_nis_ort_%": donem(kisi_siki, "2026-01", "2026-04"),
        "kisi_payi_siki_haz_eyl_ort_%": donem(kisi_siki, "2026-06", "2026-09"),
        "kisi_payi_genis_oca_nis_ort_%": donem(kisi_genis, "2026-01", "2026-04"),
        "kisi_payi_genis_haz_eyl_ort_%": donem(kisi_genis, "2026-06", "2026-09"),
        "sayi_payi_siki_oca_nis_ort_%": donem(sayi_siki, "2026-01", "2026-04"),
        "sayi_payi_siki_haz_eyl_ort_%": donem(sayi_siki, "2026-06", "2026-09"),
    }


sonuc = pd.DataFrame({ad: bulgular(d) for ad, d in setler.items()})
toplam = sonuc.loc["kisi", "1_tum_veri"]
sonuc.loc["kisi_payi_tum_veriye_gore_%"] = [round(k / toplam * 100, 1) for k in sonuc.loc["kisi"]]
sonuc.to_csv(GIRDI.parent / "robustness_check.csv")
pd.set_option("display.width", 200)
print(sonuc)
