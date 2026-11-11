# PROJE PLANI — Yapay Zekânın İş Piyasasına Gerçek Etkisi
**Uğur Avşar · Softito Veri Analitiği-2 bitirme projesi · Teslim: 13 Kasım 2026**

> Bu dosya, projeye devam edecek kişi (ben ya da VS Code'daki Claude) için tek kaynaktır.
> Claude'a not: Kullanıcıyla Türkçe konuş, kısa ve net ol. Aşağıdaki kararlar KESİNDİR; yeniden tartışma, uygula.

---

## 1. Proje özeti
**Soru:** Şirketler 2026'da işten çıkarmalarda yapay zekâyı ne kadar gerekçe gösteriyor, bu zamanla nasıl değişiyor ve aynı dönemde iş ilanlarında AI'dan bahsedenlerin payı ne yönde gidiyor?

**Ana fikir:** "Şirketlerin söylediği" (AI gerekçeli kesinti duyuruları) ile "verinin gösterdiği" (kesintilerin gerçek dağılımı + işe alım tarafı) arasındaki farkı göstermek.

**Kapsam:** Saf veri analitiği. Makine öğrenmesi YOK. Araçlar: Python (pandas) → PostgreSQL → Power BI.

**Dil kuralı:** "Kaybedilen işler" DEĞİL, **"duyurulan kesintiler"**. Neden-sonuç iddiası YOK; iki trend yan yana konur.

---

## 2. Klasör yapısı (Masaüstü)
```
Masaustu/ai-is-piyasasi/
├── data/
│   ├── raw/              ← proje_veri.zip > 1_ham içindekiler (DOKUNULMAZ)
│   └── clean/            ← proje_veri.zip > 2_temiz içindekiler
├── python/               ← clean_layoffs.py, clean_ai_posting.py, robustness_check.py
├── sql/                  ← 01_schema.sql, 02_load.sql, 03_analysis.sql
├── powerbi/              ← dashboard.pbix + ekran görüntüleri (png)
├── docs/                 ← PROJE_SURECI.md, VERI_KALITESI.md, medium_yazisi.md
├── PROJE_PLANI.md        ← bu dosya
└── README.md             ← en son yazılacak (vitrin)
```

---

## 3. Veri setleri (KESİN — toplam 3)

| # | Veri | Dosya | Rolü | Durum |
|---|---|---|---|---|
| 1 | layoffhedge.com 2026 işten çıkarmalar (8 Kas 2026) | raw/layoffs_2026.csv → clean/layoffs_clean.csv | Ana veri (küresel) | ✅ Temiz, doğrulandı |
| 2 | Indeed Hiring Lab AI Tracker (CC-BY-4.0) | raw/indeed_ai_posting.csv → clean/ai_posting_monthly.csv | Ana veri (işe alım tarafı) | ✅ Temiz |
| 3 | Challenger, Gray & Christmas aylık raporları | clean/challenger_ai_monthly.csv | ABD için bağımsız teyit | ✅ Hazır (11 Kas 2026) |

Yardımcı (veri seti sayılmaz): raw/layoffs_monthly_2026.csv, raw/layoffs_industries_2026.csv → sadece kendi hesaplarımızla karşılaştırma.

**Kurgu:**
- layoffhedge = dünya geneli, şirketlerin AI'ı gerekçe gösterme oranı
- Indeed = ABD ana seri + GB, DE, FR, NL, IE, IT, AU karşılaştırma. Kanada `comparable=False` (Ontario ilan yasası). Türkiye yok → sınırlılık.
- Challenger = ABD AI gerekçeli kesintiler; layoffhedge'deki AI payının **yönünü** teyit eder.
- Ortak dönem: **Ocak–Eylül 2026** (Indeed Eylül'de bitiyor). Birleştirme **ay** bazında.

---

## 4. Tamamlananlar ✅
- Ham veri incelendi (CSV `#` satırları, virgül ayırıcı → `pd.read_csv(..., comment="#")`).
- Otomatik kontroller 653 satırda: boş/tekrar/mantık hatası yok, yılsız tarihler 2026'ya çevrildi, 6 tarihsiz satır (3 çok yıllı plan + 3 sadece "2026") dışarıda.
- 146 satır elle doğrulandı (tüm 3.000+ satırlar, tüm AI satırları, 20'lik rastgele örneklem, linkteki rakamı farklı 2 satır, AI kelimesi geçen 1 link):
  - 4 yanlış yıl çıkarıldı (Intel, Nestlé, Nokia, CrowdStrike)
  - 2 rakam düzeltildi (Verizon 3000→500, Commerzbank 6900→3000)
- Güvenilirlik katmanları T1–T5, X. Kişilerin %72'si elle kontrollü, %81,6'sı T1–T3.
- Sağlamlık testi: sektör sıralaması ve AI payının zaman içindeki düşüşü her seviyede aynı.
- Indeed aylık tabloya çevrildi.
- Dokümanlar: PROJE_SURECI.md, VERI_KALITESI.md.
- **11 Kas 2026 denetimi** (bkz. PROJE_SURECI.md Bölüm 13): AI payı her yerde sıkı tanıma çekildi (`is_ai_strict`), duyuru sayısı bazlı AI payı eklendi, sektör tablosundaki hatalı "ağırlıklı iş gücü %" kaldırıldı, genel WARN sayfası linkleri T5'e alındı, Gilead ve Capital One doğrulandı.

**Analizde kullanılacak filtre:** `in_main_analysis = True` (643 satır, 653.456 kişi)

---

## 5. Kesinleşmiş bulgular (rakamlar bunlar, değiştirme — 11 Kas 2026 denetimiyle güncellendi)
**Kural:** AI payı her yerde **sıkı tanımla** (`is_ai_strict`) verilir; geniş tanım yalnızca "üst sınır" olarak yanına yazılır. İki tanım asla karıştırılmaz.

| Bulgu | Sıkı (ANA) | Geniş (üst sınır) |
|---|---|---|
| En çok etkilenen 3 sektör (kişi) | Otomotiv & Ulaşım, Teknoloji, Finans & Bankacılık | — |
| AI payı – kişi bazında, tüm yıl | **%16,9** (%95 GA 8,8–27,5) | %38,4 (GA 24,0–52,0) |
| AI payı – duyuru sayısı bazında, tüm yıl | **%11,5** (GA 9,0–14,0) | %14,3 |
| AI kişi payı Oca–Nis ortalaması | **%18,2** | %57,3 |
| AI kişi payı Haz–Eyl ortalaması | **%5,2** | %8,0 |
| AI duyuru sayısı payı (aylık) | Oca–Tem ~%15–20 (zirve **Mayıs %40**), Ağu–Kas **%3–6** | — |
| AI duyurularının medyan kişi sayısı | **295** vs diğerleri 180 (fark 115, GA 50–421; Mann-Whitney p < 0,001) | 375 vs 180 |
| Challenger (ABD) teyidi | Sayı payıyla aynı yön, Pearson **0,72** (permütasyon p ≈ 0,006; ayrım Haziran–Eylül arası hangi ay seçilse düşüş görülüyor) (Oca–Tem → Ağu–Eki: Challenger %24,4 → %6,2; layoffhedge sayı payı %19,5 → %3,6) | Kişi payıyla örtüşmüyor (−0,20) |
| Sektöre göre AI kişi payı | Finans %32,7 · Teknoloji %21,0 · Otomotiv %1,0 | Teknoloji %75,3 · Finans %65,7 |

| Diğer | Değer |
|---|---|
| Indeed AI ilan payı (Eyl 2025→Eyl 2026) | ABD %3,6→%7,2 · GB %5,0→%9,8 |
| KULLANILMAYACAK iddia | "AI'ı gerekçe gösterenler büyük şirketler" (sağlam değil) |

Uyarı: Ekim 2026 AI **kişi** payı (%50,5) tek bir plana bağlı (Hollanda Hükümeti 25.000, 2035'e kadar; ABD dışı). Aynı ayın **duyuru sayısı** payı %5,3. Bu yüzden aylık trendde kişi payı ve sayı payı birlikte gösterilir; Challenger (ABD) ile karşılaştırmada sayı payı daha uygun.

---

## 6. Cevaplanacak 5 soru
1. 2026'da en çok hangi sektörler işten çıkarma duyurdu?
2. Hangi sektörlerde AI daha sık gerekçe gösterildi?
3. AI gerekçesinin payı aydan aya nasıl değişti? (+ Challenger teyidi)
4. AI gerekçeli duyurular daha fazla kişiyi mi kapsıyor?
5. Aynı dönemde iş ilanlarında AI'dan bahsedenlerin payı nasıl değişti?

**Sonuç — "verinin junior adaylar için düşündürdükleri" (YORUM, bulgu değil):** Kesinti gerekçesi olarak AI yıl içinde azalırken, AI'dan bahseden ilanların payı bir yılda ikiye katlandı. Bu iki trend, iş arayanlar için AI'ın bir *kesinti tehdidi*nden çok bir *ilan gereksinimi* olarak öne çıktığını **düşündürüyor**. Veride kıdem bilgisi yok; junior pozisyonlar ayrıca ölçülmedi. Bu bölüm bu uyarıyla sunulur.

**Kullanılmayacak ifadeler:** "AI becerisi talebi" (doğrusu: "AI'dan bahseden ilanların payı"), "junior işler azalıyor", "AI işleri götürüyor".

---

## 7. YAPILACAKLAR (sırayla)

### Adım 1 — Challenger teyit tablosu ✅ (11 Kas 2026)
- Script: `python/build_challenger.py` (rakamlar + kaynaklar script içinde; aylık toplamlar Challenger'ın kendi YTD rakamlarıyla 11 noktada otomatik kontrol ediliyor).
- Çıktılar: `data/clean/challenger_ai_monthly.csv` (10 satır, her satırın kaynağı ve notu var), `data/clean/challenger_vs_layoffhedge.csv`.
- Challenger AI payı: Oca %7,0 · Şub %9,7 · Mar %25,3 · Nis %25,8 · **May %39,8** · Haz %30,6 · Tem %32,8 · Ağu %6,5 · Eyl %9,2 · **Eki %2,9**. Toplam: 121.401 / 617.189 = %19,7.
- **Sonuç:** Challenger, layoffhedge'in **duyuru sayısı payıyla** örtüşüyor (Pearson 0,72; Oca–Tem ort. %19,5 → Ağu–Eki %3,6; Challenger %24,4 → %6,2). **Kişi payıyla örtüşmüyor** (Pearson −0,20), çünkü kişi payı dev duyurulara bağlı (Mart: Oracle/Meta/HSBC üst sınır; Ekim: Hollanda Hükümeti, ABD dışı).
- Dönem ayrımı Ağustos: Challenger'da AI Ağustos'ta 5 aylık 1.'liği kaybediyor (bağımsız kaynağın kırılma noktası).
- Uyarı: n = 10 ay; korelasyon yön teyidi olarak kullanılır, kanıt olarak değil. Challenger = ABD, layoffhedge = dünya.

### Adım 2 — PostgreSQL 🗄️
`sql/01_schema.sql` — yıldız şema:
- `dim_company(company_id, company_name)` — `total_workforce` burada DEĞİL: 21 şirkette satırdan satıra farklı (ör. Amazon 350 bin / 1,55 milyon)
- `dim_industry(industry_id, industry_name)`
- `dim_date(date_key, date, month, quarter, month_name_tr)`
- `fact_layoffs(layoff_id, company_id, industry_id, date_key, people_cut, people_cut_original, total_workforce, workforce_pct, category, is_ai_driven, is_ai_strict, reliability_tier, is_upper_bound, ai_label_questionable, in_main_analysis, source_url)`
- `fact_ai_postings(country_code, country_name, month, ai_share_pct, yoy_change_pt, comparable)`
- `fact_challenger(month, total_us_cuts, ai_attributed_cuts, ai_share_pct)`

`sql/02_load.sql` — `\copy` ile clean CSV'leri yükle.

`sql/03_analysis.sql` — her soru için en az bir sorgu, yorum satırıyla:
- Q1: sektör toplamı + `RANK()`
- Q2: sektör bazında AI payı (sıkı tanım, `is_ai_strict`)
- Q3: aylık AI payı (kişi payı + duyuru sayısı payı, sıkı tanım) + `LAG()` ile aydan aya değişim + 3 aylık hareketli ortalama (`AVG() OVER (ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)`)
- Q4: AI (sıkı) vs diğer medyan (`PERCENTILE_CONT(0.5)`)
- Q5: Indeed ABD aylık seri, yıllık değişim
- Birleşik: CTE ile layoffhedge aylık AI payı + Indeed ABD + Challenger aynı tabloda (Oca–Eyl 2026), `corr()`
- Veri kalitesi: katman bazında satır ve kişi payı
- Her sorgunun sonucunu Python'daki rakamlarla karşılaştır (Bölüm 5 ile tutmalı).

**✅ Tamamlandı (11 Kas 2026)** — veritabanı: `ai_is_piyasasi` (PostgreSQL 18, localhost)
- `01_schema.sql`: 3 staging + 4 boyut (`dim_company`, `dim_industry` [TR etiketli], `dim_date` [2019–2026, günlük, `date_key`=YYYYMMDD], `dim_country`) + 3 olay tablosu. CHECK kuralları (ör. `is_ai_strict` ⇒ `is_ai_driven`, kişi ≤ toplam çalışan) hatalı satırı reddediyor (test edildi).
- `02_load.sql`: CSV → staging → boyut/olay; satır kaybı kontrolü. Tekrar çalıştırılabilir.
- `03_analysis.sql`: Power BI'ın okuyacağı view'ler: `v_kpi`, `v_q1_sector_totals`, `v_q2_sector_ai`, `v_q3_monthly_ai`, `v_q4_median`, `v_q5_indeed`, `v_combined_monthly`, `v_combined_corr`, `v_quality_tiers`.
- `04_checks.sql`: 41 rakam Python ile karşılaştırılıyor → **41/41 TAMAM**; fark olursa hata verir.
- Yeni bulgular: ana analizde 561 şirket; "sadece geniş" AI satırlarının (tartışmalı / üst sınır, 18 satır) medyanı 1.750 kişi → geniş tanımı şişiren dev satırlar. Indeed ABD ile layoffhedge sayı payı Oca–Eyl'de ters yönde (−0,38): ilanlarda AI artarken kesinti gerekçesinde AI azalıyor. İki trend yan yana konur, neden-sonuç iddia edilmez.
- Çalıştırma (proje kökünden): `for f in sql/0*.sql; do psql -U postgres -d ai_is_piyasasi -v ON_ERROR_STOP=1 -f $f; done`

### Adım 3 — Power BI 📊 (4 sayfa)
- Power BI → *Veri al → PostgreSQL* → sunucu `localhost`, veritabanı `ai_is_piyasasi`. Tabloları (`fact_*`, `dim_*`) ve `v_*` view'lerini al; ilişkiler `date_key`, `company_id`, `industry_id`, `country_code` üzerinden.
1. **Genel Bakış:** KPI kartları (toplam duyuru, kişi, şirket, AI payı %16,9), aylık trend, sektör bar grafiği
2. **AI Söylemi:** aylık AI payı çizgisi (layoffhedge kişi payı + sayı payı vs Challenger), sektöre göre AI payı, AI vs diğer medyan
3. **İşe Alım Tarafı:** Indeed AI ilan payı (ABD vurgulu, diğer ülkeler gri), yıllık değişim; Kanada notlu
4. **Veri Güvenilirliği:** katman dağılımı (T1–T5), doğrulama sonuçları, "AI payı sıkı vs geniş" karşılaştırması
- Filtreler: ay, sektör, güvenilirlik katmanı, "sadece sıkı AI tanımı"
- Her sayfada kaynak notu. Ekran görüntülerini `powerbi/` klasörüne kaydet.

### Adım 4 — README + Medium 📝
- `README.md`: başlık, tek cümlelik soru, 3–4 ana bulgu, dashboard görseli, veri kaynakları, yöntem, Veri Kalitesi bölümü (VERI_KALITESI.md'den), sınırlılıklar, nasıl çalıştırılır.
- `docs/medium_yazisi.md`: "Yapay Zekâ İşleri mi Götürüyor, Yoksa Sadece Söylem mi Değişti?" — kısa, 3–4 grafik, öğrenci dili.
- LinkedIn paylaşımı: 4–5 cümle + dashboard görseli.

### Adım 5 — Son kontrol ✔️
- Tüm rakamlar SQL, Power BI ve README'de aynı mı?
- Kaynak atıfları (layoffhedge, Indeed CC-BY, Challenger) var mı?
- Ham veri değişmeden duruyor mu?
- "Kaybedilen iş" ifadesi hiçbir yerde geçmiyor mu?

---

## 8. Sınırlılıklar (README'de yazılacak)
- Sadece duyurulmuş ve habere yansımış kesintiler; küçük şirketler eksik.
- layoffhedge'de ülke kolonu yok; ülke bazında analiz yapılamaz.
- Aylık AI payı tek dev duyuruyla sıçrayabilir.
- Kasım 2026 kısmi ay.
- Indeed verisi "AI geçen ilan payı"dır, iş yaratıldığı anlamına gelmez.
- İki trend yan yana konur; neden-sonuç iddia edilmez.
- **Kapsamlar farklı:** layoffhedge = dünya geneli (ülke kolonu yok) · Indeed = 9 ülke (Türkiye yok) · Challenger = sadece ABD. Bu yüzden kaynaklar arası karşılaştırmalar **yön teyidi**dir; aynı nüfusu ölçtükleri iddia edilmez. Sunumda bu cümle açıkça söylenir.
- **Kıdem bilgisi yok:** Hiçbir veri setinde junior/senior ayrımı yoktur. Junior adaylarla ilgili bölüm bir **yorumdur**, bulgu değildir.
- **Doğrulama asimetrik:** AI etiketli satırların hepsi, AI etiketsiz satırların ise 50'si elle kontrol edildi. Kaçırılmış AI etiketleri ana rakamı düşük gösterebilir. Ölçüldü (`istatistik_testleri.py`, test 5): elle bakılanlarda eksik etiket oranı %4 (2/50); bu oran bakılmayan 502 satıra uygulansa sıkı AI payı %16,9 → en fazla ~%18,1 olur. Ek olarak tüm AI-etiketsiz satırların linkleri AI kelimeleri için tarandı; yeni eksik etiket çıkmadı (Comcast adayı kontrol edildi, gerekçe AI değil).
- **Indeed metriği dar:** "İlanda AI geçmesi" ≠ AI becerisi talebi. AI ürünü satan şirketlerin ilanları ve "işe alımda AI kullanıyoruz" beyanları da sayılır (Kanada'daki yasa etkisi bunun kanıtı). Doğru ifade: "AI'dan bahseden ilanların payı".
- **İstatistiksel güç sınırlı:** Zaman serisi 10 ay; korelasyonlar yön teyididir. Ana AI payı (%16,9) birkaç dev satıra bağlıdır: %95 güven aralığı %8,8–27,5. Duyuru sayısı payı daha kararlıdır (%11,5; GA %9,0–14,0).

---

## 9. Mülakat cümlesi
> "Az bilinen bir kaynaktan gelen veriyi önemliliğe göre doğruladım: sonucu en çok etkileyen tüm büyük satırları ve AI etiketli tüm satırları haber kaynaklarıyla karşılaştırdım, küçük satırlardan rastgele örneklem aldım, 4 hatalı ve 2 yanlış rakamlı satırı buldum, sonra bulgularımın şüpheli satırlar çıkarıldığında da değişmediğini sağlamlık testiyle gösterdim."
