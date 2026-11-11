"""
AI Söylemi ve Gerçeklik - İstatistik testleri (makine öğrenmesi YOK; tanımlayıcı istatistik + yeniden örnekleme)

Amaç: Bulguların "tesadüf" ya da "seçilen pencere" kaynaklı olup olmadığını sınamak.

1) Medyan farkı (AI sıkı vs AI değil): bootstrap %95 güven aralığı + Mann-Whitney U testi
2) Ana AI payı (%16,9): bootstrap %95 güven aralığı (dev satırlara ne kadar bağlı?)
3) Dönem ayrımı duyarlılığı: "önce yüksek, sonra düşük" bulgusu ayrım ayı Mayıs..Eylül
   arasında değiştirildiğinde de tutuyor mu? (Ağustos'u sonradan seçtiğimiz eleştirisine cevap)
4) Challenger korelasyonu: permütasyon testi (10 ay; tesadüfen bu kadar yüksek çıkma olasılığı)
5) Gözden kaçmış AI etiketi duyarlılığı: AI etiketsiz satırlar daha az kontrol edildi;
   kaçırılan AI satırları olsaydı ana rakam ne kadar değişirdi?

Çıktı: data/clean/istatistik_sonuclari.csv
"""
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats

VERI = Path(__file__).resolve().parent.parent / "data" / "clean"
RNG = np.random.default_rng(2026)   # sabit tohum -> her çalıştırmada aynı sonuç
B = 10_000                          # bootstrap / permütasyon tekrar sayısı

df = pd.read_csv(VERI / "layoffs_clean.csv")
ana = df[df["in_main_analysis"]].copy()
sonuclar = []


def kaydet(test, deger, alt=None, ust=None, p=None, yorum=""):
    sonuclar.append({"test": test, "deger": deger, "ci95_alt": alt, "ci95_ust": ust,
                     "p_degeri": p, "yorum": yorum})


# ---------------------------------------------------------------------------
# 1) Medyan farkı
# ---------------------------------------------------------------------------
ai = ana.loc[ana["is_ai_strict"], "people_cut"].to_numpy()
diger = ana.loc[~ana["is_ai_driven"], "people_cut"].to_numpy()
fark = np.median(ai) - np.median(diger)
boot = np.array([np.median(RNG.choice(ai, ai.size)) - np.median(RNG.choice(diger, diger.size))
                 for _ in range(B)])
alt, ust = np.percentile(boot, [2.5, 97.5])
mw = stats.mannwhitneyu(ai, diger, alternative="greater")
kaydet("1a_medyan_farki_ai_siki_eksi_diger", fark, alt, ust, None,
       f"AI sıkı medyan {np.median(ai):.0f} (n={ai.size}) vs diğer {np.median(diger):.0f} (n={diger.size}); "
       f"GA sıfırı {'içermiyor' if alt > 0 else 'İÇERİYOR'}")
kaydet("1b_mann_whitney_ai_buyuk_mu", mw.statistic, None, None, mw.pvalue,
       "Tek yönlü: AI duyuruları daha fazla kişi mi kapsıyor? (dağılım farkı, normal dağılım varsaymaz)")

# ---------------------------------------------------------------------------
# 2) Ana AI payının güven aralığı (satırları yeniden örnekle)
# ---------------------------------------------------------------------------
kisi = ana["people_cut"].to_numpy()
siki = ana["is_ai_strict"].to_numpy()
genis = ana["is_ai_driven"].to_numpy()
idx = RNG.integers(0, len(ana), size=(B, len(ana)))
pay_siki = (kisi[idx] * siki[idx]).sum(1) / kisi[idx].sum(1) * 100
pay_genis = (kisi[idx] * genis[idx]).sum(1) / kisi[idx].sum(1) * 100
kaydet("2a_ai_kisi_payi_siki_%", kisi[siki].sum() / kisi.sum() * 100,
       *np.percentile(pay_siki, [2.5, 97.5]), None, "Geniş GA = sonuç birkaç dev satıra bağlı")
kaydet("2b_ai_kisi_payi_genis_%", kisi[genis].sum() / kisi.sum() * 100,
       *np.percentile(pay_genis, [2.5, 97.5]), None, "Üst sınır")
pay_sayi = siki[idx].mean(1) * 100
kaydet("2c_ai_duyuru_payi_siki_%", siki.mean() * 100, *np.percentile(pay_sayi, [2.5, 97.5]), None,
       "Sayı payı dev satırlardan etkilenmez -> GA dar")

# ---------------------------------------------------------------------------
# 3) Dönem ayrımı duyarlılığı (Oca..Eki; Kasım kısmi ay hariç)
# ---------------------------------------------------------------------------
aylik = pd.read_csv(VERI / "layoffs_clean_monthly.csv")
aylik = aylik[aylik["month"] <= "2026-10"].set_index("month")
ch = pd.read_csv(VERI / "challenger_ai_monthly.csv").set_index("month")
for ayrim in ["2026-05", "2026-06", "2026-07", "2026-08", "2026-09"]:
    once, sonra = aylik.index < ayrim, aylik.index >= ayrim
    lh_o, lh_s = aylik.loc[once, "ai_strict_count_share_pct"].mean(), aylik.loc[sonra, "ai_strict_count_share_pct"].mean()
    ch_o, ch_s = ch.loc[ch.index < ayrim, "ai_share_pct"].mean(), ch.loc[ch.index >= ayrim, "ai_share_pct"].mean()
    kaydet(f"3_ayrim_{ayrim}_layoffhedge_sayi_payi", lh_o - lh_s, lh_o, lh_s, None,
           f"önce {lh_o:.1f} -> sonra {lh_s:.1f} (deger = fark; alt/ust = önce/sonra ort.) | "
           f"Challenger önce {ch_o:.1f} -> sonra {ch_s:.1f}")

# ---------------------------------------------------------------------------
# 4) Challenger korelasyonu: permütasyon testi
# ---------------------------------------------------------------------------
k = pd.read_csv(VERI / "challenger_vs_layoffhedge.csv")
x, y = k["challenger_ai_share_pct"].to_numpy(), k["lh_ai_strict_count_pct"].to_numpy()
r = np.corrcoef(x, y)[0, 1]
perm = np.array([np.corrcoef(x, RNG.permutation(y))[0, 1] for _ in range(B)])
p_perm = (np.sum(perm >= r) + 1) / (B + 1)
kaydet("4a_corr_challenger_vs_sayi_payi", r, None, None, p_perm,
       f"n={len(x)} ay; permütasyon p tek yönlü. Not: aylık seriler birbirine bağımlı (otokorelasyon), "
       "p iyimser olabilir -> yön teyidi olarak oku")
x2 = k["lh_ai_strict_people_pct"].to_numpy()
r2 = np.corrcoef(x, x2)[0, 1]
perm2 = np.array([np.corrcoef(x, RNG.permutation(x2))[0, 1] for _ in range(B)])
kaydet("4b_corr_challenger_vs_kisi_payi", r2, None, None, (np.sum(perm2 >= r2) + 1) / (B + 1),
       "Kişi payı Challenger ile örtüşmüyor")

# ---------------------------------------------------------------------------
# 5) Gözden kaçmış AI etiketi duyarlılığı
# ---------------------------------------------------------------------------
P = kisi.sum()
siki_kisi = kisi[siki].sum()
non_ai = ana[~ana["is_ai_driven"]]
bakilan = non_ai[non_ai["verification"] != "kontrol_edilmedi"]
bakilmayan = non_ai[non_ai["verification"] == "kontrol_edilmedi"]
eksik = non_ai[non_ai["ai_label_missing"]]
oran_satir = len(eksik) / len(bakilan)                       # elle bakılanlarda bulunan eksik etiket oranı
# Senaryo A: bulunan eksik etiketler (Envato, United Internet) AI sayılırsa
pay_a = (siki_kisi + eksik["people_cut"].sum()) / P * 100
# Senaryo B: aynı oran, elle bakılmamış satırlara da uygulanırsa (bakılmayanların medyan büyüklüğüyle)
tahmini_kisi = oran_satir * len(bakilmayan) * bakilmayan["people_cut"].median()
pay_b = (siki_kisi + eksik["people_cut"].sum() + tahmini_kisi) / P * 100
# Senaryo C (kötümser): aynı oran, bakılmayanların ORTALAMA büyüklüğüyle
pay_c = (siki_kisi + eksik["people_cut"].sum() + oran_satir * bakilmayan["people_cut"].sum()) / P * 100
kaydet("5a_eksik_etiket_orani_elle_bakilanlarda", oran_satir * 100, None, None, None,
       f"{len(eksik)} / {len(bakilan)} elle bakılan AI-etiketsiz satır")
kaydet("5b_ai_payi_siki_senaryo_A_bulunanlar_eklenirse_%", pay_a, None, None, None, "Envato + United Internet")
kaydet("5c_ai_payi_siki_senaryo_B_oran_bakilmayanlara_medyanla_%", pay_b, None, None, None,
       f"~{oran_satir * len(bakilmayan):.0f} satır x medyan {bakilmayan['people_cut'].median():.0f} kişi")
kaydet("5d_ai_payi_siki_senaryo_C_oran_bakilmayanlara_ortalamayla_%", pay_c, None, None, None, "Kötümser üst tahmin")

out = pd.DataFrame(sonuclar)
for kol in ["deger", "ci95_alt", "ci95_ust"]:
    out[kol] = out[kol].astype(float).round(2)
out["p_degeri"] = out["p_degeri"].astype(float).round(4)
out.to_csv(VERI / "istatistik_sonuclari.csv", index=False)
pd.set_option("display.width", 250)
pd.set_option("display.max_colwidth", 130)
print(out.to_string(index=False))
