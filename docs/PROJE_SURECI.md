# AI Söylemi ve Gerçeklik: Teknoloji İş Piyasası 2026
## Proje Süreci — Sıfırdan Yapılan Her Adım

Bu dosya, projenin veri hazırlık aşamasında yapılan tüm işlemleri, sırasıyla ve gerekçeleriyle anlatır.
Amaç: Projeyi inceleyen birinin "bu veri nereden geldi, nasıl temizlendi, neden güvenilir?" sorularına bu dosyadan cevap bulabilmesi.

---

## 0. Projenin amacı

**Soru:** 2026'da şirketler işten çıkarmaları açıklarken yapay zekâyı (AI) ne kadar gerekçe gösteriyor, bu zamanla nasıl değişiyor ve aynı dönemde iş ilanlarında AI'dan bahsedenlerin payı ne yönde gidiyor?

**Cevaplanacak 5 soru:**
1. 2026'da en çok hangi sektörler işten çıkarma duyurdu?
2. Hangi sektörlerde AI daha sık gerekçe olarak gösterildi?
3. AI gerekçesinin payı aydan aya nasıl değişti? (Challenger raporlarıyla bağımsız teyit)
4. AI gerekçeli duyurular daha fazla kişiyi mi kapsıyor?
5. Aynı dönemde iş ilanlarında AI'dan bahsedenlerin payı nasıl değişti?

**Sonuç bölümü:** Bu tablonun junior (yeni başlayan) adaylar için **düşündürdükleri**. Bu bölüm bir yorumdur: veride kıdem bilgisi yoktur.

**Kullanılan araçlar:** Python (pandas) → PostgreSQL → Power BI. Makine öğrenmesi yok; saf veri analitiği.

**Önemli dil kararı:** Projede "kaybedilen işler" değil, **"duyurulan kesintiler"** ifadesi kullanılır. Çünkü büyük rakamların bir kısmı yıllara yayılan planlar veya "…'e kadar" ifadeleridir (bkz. Adım 6).

---

## 1. Veri kaynakları

| # | Dosya | Kaynak | İçerik | Lisans |
|---|---|---|---|---|
| 1 | `raw/layoffs_2026.csv` | layoffhedge.com (8 Kasım 2026 sürümü) | 2026'da duyurulan 653 işten çıkarma: şirket, sektör, kişi sayısı, iş gücü %, toplam çalışan, tarih, kategori, kaynak linki | Atıf vererek serbest |
| 2 | `raw/layoffs_monthly_2026.csv`, `raw/layoffs_industries_2026.csv` | layoffhedge.com | Sitenin kendi aylık ve sektör özetleri (sadece karşılaştırma için) | Atıf vererek serbest |
| 3 | `raw/indeed_ai_posting.csv` | Indeed Hiring Lab – AI Tracker | 9 ülkede, günlük olarak, iş ilanlarının yüzde kaçında AI geçtiği (7 günlük ortalama). 25.470 satır | CC-BY-4.0 |
| 4 | `clean/challenger_ai_monthly.csv` (`build_challenger.py`) | Challenger, Gray & Christmas aylık raporları | Ocak–Ekim 2026, ABD'de aylık toplam ve AI gerekçeli kesintiler (bağımsız teyit kaynağı) | Kamuya açık rapor |

**Neden bu kaynaklar?**
- layoffhedge, 2026 verisini en güncel ve her satır için kaynak linkiyle veren ücretsiz kaynak. Ama az bilinen bir site olduğu için **her şeye rağmen doğrulama gerekti** (Adım 4–7).
- Indeed, iş ilanlarında AI'dan bahsedenlerin payını ölçen en bilinen açık veri (AI becerisi talebinin birebir ölçüsü değildir; bkz. Bölüm 11).
- Challenger, ABD'de işten çıkarma gerekçelerini aylık raporlayan, medyada sürekli alıntılanan kurum. AI payını bağımsız olarak kontrol etmek için kullanılır.

---

## 2. İlk inceleme: dosya neden Excel'de tek kolonda açıldı?

`layoffs_2026.csv` Excel'de açıldığında bütün veri A kolonunda göründü. Sebepler:
- Dosya **virgülle ayrılmış**; Türkçe Excel ise varsayılan olarak **noktalı virgül** bekliyor.
- Dosyanın ilk 3 satırı veri değil, `#` ile başlayan açıklama satırları:
  ```
  # Source: layoffhedge.com
  # License: Free to use with attribution
  # Generated: 2026-11-08
  ```

**Çözüm:**
- Excel'de: *Veri → Metinden/CSV'den* → ayırıcı olarak "Virgül" seç.
- Python'da: `pd.read_csv("layoffs_2026.csv", comment="#")` → `#` ile başlayan satırlar atlanır.

Veri bozuk değil; sadece okuma ayarı yanlıştı.

---

## 3. Otomatik kontroller (653 satırın tamamı)

Hiçbir satır elle bakılmadan önce, tüm veri kod ile kontrol edildi:

| Kontrol | Sonuç |
|---|---|
| Boş hücre var mı? | Yok |
| Tekrar eden satır var mı? | Yok |
| Mantık hatası (çıkarılan kişi > toplam çalışan) | Yok |
| `Workforce %` = kişi / toplam çalışan × 100 tutuyor mu? | Birebir tutuyor |
| Tarih formatı | **Sorunlu** → Adım 3.1 |
| Kaynak linkleri | Her biri otomatik puanlandı → Adım 3.2 |

### 3.1 Tarih sorunu ve çözümü
Tarih kolonunda yıl yok ve üç farklı format var:

| Ham değer | Anlamı | Ne yapıldı | `date_precision` |
|---|---|---|---|
| `Oct 13` | 13 Ekim (yıl yazmıyor) | 2026-10-13 olarak işlendi (dosya 2026 listesi) | `day` |
| `Jan 2026` | Sadece ay belli | 2026-01-01 olarak işlendi | `month` |
| `2026` | Sadece yıl belli, ay yok | Tarih boş bırakıldı, **ana analizden çıkarıldı** | `year_only` |
| `2025-30`, `2025-26` vb. | Yıllara yayılan plan, tarih yok | Tarih boş bırakıldı, **ana analizden çıkarıldı** | `multi_year` |

6 satırda ay bilinmiyor (`is_undated = True`): 3'ü `multi_year` (Citigroup 20.000, P&G 7.000, Bosch 13.000), 3'ü `year_only` (Chevron 7.820, Telefonica 6.000, Accenture 11.000). Aylık analize konamadıkları için ana analizden çıkarıldılar. Bunlar silinmedi, sadece işaretlendi.

### 3.2 Kaynak linki puanlaması (`auto_source_level`)
Her satırın kaynak linki kodla incelendi:

| Seviye | Kural |
|---|---|
| `A_sirket_ve_rakam` | Link hem şirket adını hem kişi sayısını içeriyor (ör. `.../visa-to-cut-2-600-jobs...`) |
| `B_resmi_warn` | Link resmi bir devlet / WARN bildirimi sayfası |
| `C_sadece_sirket` | Link şirket adını içeriyor ama rakamı içermiyor |
| `D_belirsiz` | Link ne şirketi ne rakamı içeriyor |

Ayrıca genel derleme sayfalarına giden linkler (`layoff-tracker`, `major-employers-job-cuts`, `intellizence` vb.) `generic_source = True` olarak işaretlendi. **Sonradan görüldü ki hatalı satırların çoğu bu tür derleme sayfalarından geliyor.** Eyalet WARN listelerinin ana sayfası (ör. `edd.ca.gov/.../Layoff_Services_WARN`) da satıra özel olmadığı için genel sayfa sayılır; elle bakılmamış genel sayfa satırları T5'e gider (bkz. Bölüm 13).

---

## 4. Elle doğrulama: hangi satırlara, neden bakıldı?

653 satırın hepsini tek tek kontrol etmek yerine profesyonel dünyada kullanılan **önemliliğe göre doğrulama (materiality)** yaklaşımı uygulandı: sonucu en çok etkileyen satırlar mutlaka, geri kalanlar örneklemle.

Toplam **146 satır** haber kaynaklarıyla tek tek karşılaştırıldı:

| Grup | Neden? | Satır |
|---|---|---|
| 1. 3.000 kişiden büyük **tüm** satırlar | Az sayıda dev satır toplamın çoğunu oluşturuyor; biri yanlışsa sonuç değişir | ~50 |
| 2. "AI-DRIVEN" etiketli **tüm** satırlar | Projenin ana sorusu bu etikete dayanıyor | ~90 |
| 3. Diğer küçük satırlardan **20'lik rastgele (tabakalı) örneklem** | Küçük satırlarda sistematik bir hata var mı, görmek için | 20 |
| 4. Linkteki rakamı veriden farklı çıkan satırlar (11 Kas denetimi) | Otomatik taramada anlamlı fark çıktı | 2 |
| 5. AI etiketsiz ama linkinde AI kelimesi geçen satırlar (11 Kas) | Kaçırılmış AI etiketi var mı? | 1 (Comcast; AI değil) |

(Gruplar kesişiyor; ör. Barclays hem büyük hem AI satırı.)

**Yöntem:** Her satır için şirket + rakam + ay ile haber araması yapıldı; haberdeki rakam, tarih ve gerekçe veriyle karşılaştırıldı. Her bulgu ve kaynak linki `verification_log.csv` dosyasına yazıldı.

### 4.1 Doğrulama sonuçları

| Durum | Anlamı | Satır |
|---|---|---|
| `dogrulandi` | Rakam, tarih ve gerekçe haberle uyuşuyor | 104 |
| `duzeltildi` | Haber farklı rakam veriyor; kaynağa göre düzeltildi | 2 |
| `kismen` | Olay doğru ama rakam "…'e kadar", plan, gönüllü emeklilik, ya da rakam teyit edilemedi | 27 |
| `hatali` | Duyuru 2026'ya ait değil (eski yıl) → analizden çıkarıldı | 4 |
| `uyusmazlik` | Haberdeki rakam veriyle çelişiyor | 1 |
| `dogrulanamadi` | Aramada hiçbir kaynak bulunamadı | 8 |

### 4.2 Bulunan hatalar ve yapılan işlem

**Yanlış yıl (analizden çıkarıldı):**
| Şirket | Veride | Gerçekte |
|---|---|---|
| Intel | 15.000 | Ağustos 2024 duyurusu |
| Nestlé | 16.000 | Ekim 2025 duyurusu |
| Nokia | 14.000 | Ekim 2023 duyurusu |
| CrowdStrike | 500 | Mayıs 2025 duyurusu |

**Kaynağa göre düzeltilen rakamlar** (orijinal değer `people_cut_original` kolonunda saklandı):
| Şirket | Veride | Düzeltilen | Gerekçe |
|---|---|---|---|
| Verizon | 3.000 | 500 | Haberler 500 kurumsal işten çıkarma diyor; ~2.500 mağaza çalışanı satışla başka şirkete devrediliyor |
| Commerzbank | 6.900 | 3.000 | Mayıs 2026 haberleri 3.000 diyor |

**Rakam uyuşmazlığı:** Apple 147 → haber "400+ pozisyon" diyor. Satır tutuldu, işaretlendi.

### 4.3 AI satırlarının sonucu
- Ana analizdeki **92 AI satırının 90'ı** tamamen veya kısmen doğrulandı.
- 2'si (Skai, Rapyd) bulunamadı.
- Yani AI payı hesabının **pay kısmı (AI'a bağlanan kesintiler) satır satır doğrulanmış** durumda.

### 4.4 Rastgele örneklem sonucu
20 küçük satırdan **hiçbiri hatalı çıkmadı**; 16'sı tam veya kısmen doğrulandı, 4'ü küçük yerel olaylar olduğu için bulunamadı. Bu, küçük satırlarda sistematik bir sorun olmadığını gösteriyor.

### 4.5 Benim yaptığım ve düzelttiğim hatalar (şeffaflık için)
- **Volkswagen:** İlk başta 31.000 ve 19.000'lik iki satırı "tekrar eden satır" sandım. Kontrol edince Mart 2026'daki 50.000'lik planın iki parçası oldukları, Eylül'deki 50.000'in ise ayrı ve yeni bir duyuru olduğu çıktı. İşaret geri alındı.
- **"AI'ı gerekçe gösterenler büyük şirketler" iddiası:** Önceden bu sonuca varmıştım; sağlamlık testinde (Adım 7) tutmadığı görüldü. Bu iddia projeden çıkarıldı.

---

## 5. Etiket sorunları: AI etiketi her zaman doğru mu?

"AI-DRIVEN" etiketi layoffhedge'in kendi sınıflandırması. Doğrulama sırasında iki tür sorun bulundu:

**AI etiketi tartışmalı** (`ai_label_questionable = True`) — haberde ana gerekçe başka:
| Şirket | Neden tartışmalı |
|---|---|
| UPS 30.000 | Ana gerekçe Amazon hacminin azaltılması |
| Dell 11.000 | Duyuru değil; yıllık raporda çalışan sayısının düşmesi |
| HDFC Bank 3.343 | Duyuru değil; mali yılda çalışan sayısının düşmesi |
| HubSpot 660 | CEO, kesintinin AI kaynaklı olduğunu açıkça reddediyor |
| Uber 340 | İK biriminde kesinti; AI gerekçesi haberde yok |
| Southern Cross Media 200 | Ana gerekçe TV reklam gelirlerinin düşmesi |
| Wells Fargo 112 | WARN bildirimi; AI gerekçesi yok |

**AI etiketi eksik** (`ai_label_missing = True`) — haberde AI geçiyor ama etiket "RESTRUCTURE":
Envato 200, United Internet 800.

**Rakam bir üst sınır** (`is_upper_bound = True`) — "…'e kadar" ya da kesinleşmemiş plan:
Oracle 30.000, HSBC 20.000, Meta 16.000, Cognizant 15.000, Microsoft 8.750 (gönüllü emeklilik), Heineken 6.000, Amdocs 2.500, Wix 1.000, Thomson Reuters 500, Groupon 400, Gemini 200, Southern Cross Media 200, The Telegraph 100.

**Karar:** Bu satırlar silinmedi. AI payı iki şekilde raporlanır:
- **Sıkı tanım** (tartışmalı ve üst sınır satırlar hariç) → ana rakam
- **Geniş tanım** (tüm AI etiketleri) → sadece üst sınır olarak

---

## 6. Temizleme prensibi: "Silme, işaretle"

Hiçbir satır veri setinden silinmedi. Bunun yerine her satıra kalite kolonları eklendi. Böylece:
- Analizi yapan kişi hangi satırı neden dışarıda bıraktığını gösterebilir.
- Farklı filtrelerle sonuçlar yeniden hesaplanabilir (sağlamlık testi bunu kullanır).

**Ana analiz filtresi:**
```python
in_main_analysis = ~is_undated & ~is_invalid
```
→ 653 satırdan **643 satır, 653.456 kişi** ana analize girer (ayı bilinmeyen 6 satır + 4 hatalı satır dışarıda).

### 6.1 Güvenilirlik katmanları (`reliability_tier`)
Her satır tek bir güvenilirlik etiketi alır:

| Katman | Anlamı | Satır | Kişi payı |
|---|---|---|---|
| `T1_elle_dogrulandi` | Elle doğrulandı / düzeltildi | 106 | %47,2 |
| `T2_elle_kismen` | Elle kısmen doğrulandı | 27 | %25,0 |
| `T3_guclu_kaynak` | Elle bakılmadı ama link şirketi+rakamı içeriyor veya satıra özel resmi WARN | 180 | %9,3 |
| `T4_orta_kaynak` | Link sadece şirketi içeriyor | 186 | %11,1 |
| `T5_zayif_kaynak` | Genel sayfa / derleme sitesi / WARN ana sayfası | 144 | %7,3 |
| `X_hatali` | Yanlış yıl | 4 | analiz dışı |
| `X_tarihsiz_plan` | Yıllara yayılan plan | 3 | analiz dışı |
| `X_ay_belirsiz` | Sadece "2026" yazıyor, ay yok | 3 | analiz dışı |

**Özet:** Ana analizdeki kişi sayısının **%72'si elle kontrol edildi**, **%81,6'sı** T1–T3 "doğrulanmış çekirdek" içinde.

---

## 7. Sağlamlık testi (robustness check)

**Soru:** Bulgularım, verinin şüpheli kısmını atarsam da aynı kalıyor mu?

Ana bulgular üç farklı veri seviyesinde yeniden hesaplandı:
1. Tüm ana analiz (T1–T5)
2. Doğrulanmış çekirdek (T1–T3)
3. Sadece elle doğrulanan (T1–T2)

| Bulgu | Tüm veri | Çekirdek (T1–T3) | Sadece elle (T1–T2) | Sonuç |
|---|---|---|---|---|
| En çok etkilenen 3 sektör | Otomotiv & Ulaşım, Teknoloji, Finans & Bankacılık | Aynı | Aynı | ✅ Sağlam |
| AI kişi payı Ocak–Nisan ort. — sıkı (geniş) | %18,2 (%57,3) | %22,3 (%69,9) | %23,4 (%74,1) | ✅ Her seviyede daha yüksek |
| AI kişi payı Haziran–Eylül ort. — sıkı (geniş) | %5,2 (%8,0) | %6,6 (%9,9) | %13,0 (%16,8) | ✅ Her seviyede daha düşük |
| AI duyuruları daha fazla kişiyi kapsıyor (medyan kişi, sıkı) | 295 vs 180 | 320 vs 200 | — | ✅ Yön aynı |
| AI'ı gerekçe gösterenler daha büyük şirketler | Hayır | — | — | ❌ Tutmuyor, kullanılmayacak |

**Ana AI payı rakamı (tüm veriden):**
- Sıkı tanım: kesinti duyurularının kişi bazında **%16,9'u** AI'a bağlanıyor.
- Geniş tanım: %38,4 (birkaç dev plana bağlı → sadece üst sınır).

**Dikkat:** Elle doğrulama AI satırlarının hepsini kapsadığı için T1–T2 seviyesinde AI satırları fazla temsil ediliyor (seçim etkisi). Bu yüzden bu seviyedeki AI oranı ana rakam olarak kullanılmaz. Sağlamlık testinin amacı oranın kendisi değil, **yönün ve sıralamanın** her seviyede aynı kalmasıdır.

---

## 8. Indeed AI ilan verisinin hazırlanması

`AI_posting.csv` (25.470 satır) kontrol edildi:
- Kolonlar: `date`, `jobcountry`, `AI_share_postings`
- Ülkeler: Avustralya, Kanada, Almanya, Fransa, Birleşik Krallık, İrlanda, İtalya, Hollanda, ABD. **Türkiye yok.**
- Eksik gün yok.

**Yapılanlar (`clean_ai_posting.py`):**
1. Günlük veri → ülke × ay ortalamasına çevrildi.
2. Bir önceki yılın aynı ayına göre değişim hesaplandı (`yoy_change_pt`, yüzde puan).
3. **Kanada uyarısı:** Ontario'da 1 Ocak 2026'dan itibaren iş ilanlarında "işe alımda AI kullanıyoruz" açıklaması yasal zorunluluk oldu. Bu, Kanada'daki ani artışı AI becerisi talebinden değil, yasadan kaynaklı yapıyor. Ekim 2025'ten itibaren Kanada satırları `comparable = False` olarak işaretlendi.

**Öne çıkan trend (Eylül 2025 → Eylül 2026):**
- ABD: %3,6 → %7,2
- Birleşik Krallık: %5,0 → %9,8

**İki veri setinin birleştirilmesi:** layoffhedge verisinde ülke kolonu yok, Indeed'de Türkiye yok. Bu yüzden iki veri **ay bazında** birleştirilir; ilan tarafında ABD serisi kullanılır, ortak pencere Ocak–Eylül 2026'dır.

---

## 9. Çıktı dosyaları

| Dosya | İçerik |
|---|---|
| `layoffs_clean.csv` | 653 satır, tüm kalite kolonlarıyla temiz veri |
| `layoffs_clean_monthly.csv` | Ana analizden aylık özet (duyuru sayısı, kişi, medyan; AI kişi payı ve duyuru sayısı payı, sıkı + geniş) |
| `layoffs_clean_industries.csv` | Sektör özeti (medyan iş gücü %, AI payı sıkı + geniş, medyan kişi) |
| `verification_log.csv` | Elle doğrulanan 146 satır: durum, bulgu, kaynak linki |
| `robustness_check.csv` | Sağlamlık testi tablosu |
| `ai_posting_monthly.csv` | Indeed verisinin ülke × ay tablosu |
| `challenger_ai_monthly.csv` | Challenger Oca–Eki 2026: aylık toplam, AI kesintisi, AI payı, YTD, kaynak, not |
| `challenger_vs_layoffhedge.csv` | Challenger AI payı ile layoffhedge AI payları aynı ayda yan yana |
| `istatistik_sonuclari.csv` | Bootstrap güven aralıkları, Mann-Whitney, permütasyon, dönem ayrımı ve eksik etiket duyarlılığı |
| `VERI_KALITESI.md` | README'ye konacak "Veri Kalitesi ve Doğrulama" bölümü |

### 9.1 `layoffs_clean.csv` kolon sözlüğü

| Kolon | Açıklama |
|---|---|
| `company`, `industry` | Şirket, sektör |
| `people_cut` | Duyurulan kişi sayısı (düzeltilmiş hâli) |
| `people_cut_original` | Kaynaktaki orijinal rakam |
| `is_corrected` | Rakam kaynağa göre düzeltildi mi? |
| `workforce_pct`, `total_workforce` | İş gücü yüzdesi, toplam çalışan |
| `announce_date`, `month` | Duyuru tarihi (2026), ay (YYYY-MM) |
| `date_precision` | `day` / `month` / `year_only` / `multi_year` |
| `category`, `is_ai_driven` | Sitenin gerekçe kategorisi; AI-DRIVEN mi? (geniş tanım) |
| `is_ai_strict` | Sıkı AI tanımı: AI-DRIVEN, etiketi tartışmalı değil, rakamı üst sınır değil (**ana rakam**) |
| `source_url` | Kaynak linki |
| `in_main_analysis` | Ana analize giriyor mu? |
| `in_core_verified` | T1–T3 çekirdeğinde mi? |
| `reliability_tier` | Güvenilirlik katmanı (T1–T5, X) |
| `verification`, `verification_note` | Elle doğrulama durumu ve notu |
| `auto_source_level` | Otomatik link puanı (A/B/C/D) |
| `is_invalid` | Hatalı (yanlış yıl) mı? |
| `is_multi_year` | Tarihsiz, yıllara yayılan plan mı? |
| `is_undated` | Ayı bilinmiyor mu? (`multi_year` veya `year_only`) |
| `is_upper_bound` | Rakam "…'e kadar" mı? |
| `ai_label_questionable` | AI etiketi tartışmalı mı? |
| `ai_label_missing` | AI etiketi eksik mi? |
| `generic_source` | Link genel derleme sayfası mı? |
| `needs_check` | Elle bakılmamış ve zayıf sinyalli mi? |
| `date_mismatch` | Linkteki tarih ile veri tarihi 2+ ay farklı mı? |
| `is_partial_month` | Kasım 2026 (eksik ay) mı? |
| `date_raw` | Orijinal tarih metni |

---

## 10. Nasıl çalıştırılır?

```bash
# Argümansız çalışır: data/raw'dan okur, data/clean'e yazar (hangi klasörden çalıştırılırsa çalıştırılsın)
# 1) İşten çıkarma verisini temizle ve doğrula
python3 python/clean_layoffs.py

# 2) Sağlamlık testini çalıştır
python3 python/robustness_check.py

# 3) Indeed verisini aylık tabloya çevir
python3 python/clean_ai_posting.py

# 4) Challenger tablosunu üret ve layoffhedge ile karşılaştır (1. adımdan sonra)
python3 python/build_challenger.py

# 4b) İstatistik testleri (bootstrap, Mann-Whitney, permütasyon, duyarlılık)
python3 python/istatistik_testleri.py
```

```bash
# 5) PostgreSQL: veritabanını bir kez oluştur, sonra 4 dosyayı sırayla çalıştır (proje kökünden)
createdb -U postgres ai_is_piyasasi
for f in sql/0*.sql; do psql -U postgres -d ai_is_piyasasi -v ON_ERROR_STOP=1 -f "$f"; done
```

Gerekli kütüphane: `pandas`

Elle doğrulama sonuçları `clean_layoffs.py` içindeki sözlüklerde tutulur. Yeni bir satır doğrulandığında sadece bu sözlüklere eklenir ve script tekrar çalıştırılır:
- `DOGRULAMA` → (şirket, kişi) : (durum, not, kaynak)
- `DUZELTME` → (şirket, eski rakam) : yeni rakam
- `UST_SINIR`, `AI_TARTISMALI`, `AI_ETIKET_EKSIK` → işaret listeleri

---

## 11. Sınırlılıklar

- Veri yalnızca kamuoyuna duyurulmuş ve haberlere yansımış kesintileri içerir; küçük şirketler eksik temsil edilir.
- Ülke kolonu yoktur; ülke bazında analiz yapılamaz.
- `total_workforce` sitenin tahminidir ve aynı şirkette satırdan satıra farklı olabilir; sektör bazında toplanmaz.
- Aylık AI kişi payı tek bir dev duyuruyla sıçrayabilir. Ör. Ekim 2026'daki %50,5'te Hollanda Hükümeti'nin 2035'e kadar yayılan 25.000'lik planı belirleyici (aynı ayın duyuru sayısı payı %5,3). Bu yüzden aylık değerler yanında **duyuru sayısı payı, dönem ortalamaları ve medyan** kullanılır.
- Sitenin son aylarda daha fazla küçük duyuru topladığı görülüyor; aylık duyuru **sayısı** karşılaştırmaları dikkatle yorumlanmalı.
- Kasım 2026 kısmi aydır (6 Kasım'a kadar).
- Indeed verisi "AI geçen ilan payı"dır; AI'ın iş yarattığı veya yok ettiği anlamına gelmez.
- **Kapsamlar farklı:** layoffhedge = dünya geneli (ülke kolonu yok) · Indeed = 9 ülke (Türkiye yok) · Challenger = sadece ABD. Bu yüzden kaynaklar arası karşılaştırmalar **yön teyidi**dir; aynı nüfusu ölçtükleri iddia edilmez. Sunumda bu cümle açıkça söylenir.
- **Kıdem bilgisi yok:** Hiçbir veri setinde junior/senior ayrımı yoktur. Junior adaylarla ilgili bölüm bir **yorumdur**, bulgu değildir.
- **Doğrulama asimetrik:** AI etiketli satırların hepsi, AI etiketsiz satırların ise 50'si elle kontrol edildi. Kaçırılmış AI etiketleri ana rakamı düşük gösterebilir. Ölçüldü (`istatistik_testleri.py`, test 5): elle bakılanlarda eksik etiket oranı %4 (2/50); bu oran bakılmayan 502 satıra uygulansa sıkı AI payı %16,9 → en fazla ~%18,1 olur. Ek olarak tüm AI-etiketsiz satırların linkleri AI kelimeleri için tarandı; yeni eksik etiket çıkmadı (Comcast adayı kontrol edildi, gerekçe AI değil).
- **Indeed metriği dar:** "İlanda AI geçmesi" ≠ AI becerisi talebi. AI ürünü satan şirketlerin ilanları ve "işe alımda AI kullanıyoruz" beyanları da sayılır (Kanada'daki yasa etkisi bunun kanıtı). Doğru ifade: "AI'dan bahseden ilanların payı".
- **İstatistiksel güç sınırlı:** Zaman serisi 10 ay; korelasyonlar yön teyididir. Ana AI payı (%16,9) birkaç dev satıra bağlıdır: %95 güven aralığı %8,8–27,5. Duyuru sayısı payı daha kararlıdır (%11,5; GA %9,0–14,0).

---

## 12. Sıradaki adımlar

1. ~~Challenger tablosu~~ ✅ (Bölüm 14)
2. ~~PostgreSQL~~ ✅ (Bölüm 15)
3. **Power BI (4 sayfa):** Genel tablo · AI söylemi · İşe alım tarafı · Veri güvenilirliği.
4. **README + Medium yazısı:** Bulgular, grafikler ve "Veri Kalitesi" bölümü.

---

## 13. Ek denetim (11 Kasım 2026) — bulunan sorunlar ve düzeltmeler

Analize geçmeden önce tüm rakamlar sıfırdan yeniden hesaplandı ve script mantığı satır satır kontrol edildi.

**Doğru çıkanlar:** 643 satır / 653.456 kişi, %16,9 ve %38,4, katman payları; doğrulama sözlüklerindeki tüm (şirket, kişi) anahtarları veriye eşleşiyor; sitenin aylık özetiyle farklar tam olarak bizim düzeltmelerimizden geliyor (Ocak −15.000 Intel, Şubat −16.500 Nestlé+CrowdStrike, Mart −14.000 Nokia, Mayıs −3.900 Commerzbank, Temmuz −2.500 Verizon); Indeed verisinde eksik gün yok.

| # | Sorun | Neden önemli | Düzeltme |
|---|---|---|---|
| 1 | Ana AI payı (%16,9) sıkı tanımla, ama dönem ortalamaları (%57 / %8) ve sektör AI payları geniş tanımla hesaplanmıştı | İki tanım karışıyordu; %57'yi büyük ölçüde tartışmalı / üst sınır dev satırlar oluşturuyordu (sıkı tanımla Mart %61,5 → %1,5) | `is_ai_strict` kolonu eklendi; tüm çıktılarda sıkı tanım ana, geniş tanım `_upper` olarak yanında |
| 2 | Aylık AI payı sadece kişi bazlıydı | Tek bir dev duyuru ayı belirliyor (Ekim: Hollanda Hükümeti) | Duyuru sayısı bazlı pay eklendi (`ai_strict_count_share_pct`); Challenger ile karşılaştırmada daha uygun |
| 3 | Sektör tablosundaki "ağırlıklı iş gücü %" `total_workforce`'u satır satır topluyordu | Aynı şirket birden çok sayılıyordu (Amazon 7 kez); 21 şirkette toplam çalışan satırdan satıra farklı | Metrik kaldırıldı, yerine `median_workforce_pct` |
| 4 | Linkteki rakam veriden farklı: Gilead 192 (link "108"), Capital One 1.100 (link "1.700") | Olası yanlış rakam | Elle doğrulandı, veri doğru: Gilead 108+84=192 (haber başlığı güncellenmiş); Capital One WARN 1.139, 1.700 birikimli toplam |
| 5 | Genel WARN ana sayfasına giden 42 satır T3'teydi | Katman kuralı `generic_source` işaretini kullanmıyordu; dokümandaki "T5 = genel sayfa" tanımıyla çelişiyordu | Elle bakılmamış genel sayfa satırları T5'e alındı (T1–T3 payı %82,5 → %81,6) |
| 6 | "2026" yazan 3 satır "çok yıllı plan" olarak etiketlenmişti | Etiket yanlış (yıl belli, ay belli değil) | Yeni `year_only` / `X_ay_belirsiz` etiketi; `is_undated` filtresi. Ana analiz değişmedi |
| 7 | Script'ler eski dosya adlarını bekliyordu, çıktıyı çalışılan klasöre yazıyordu | Yeniden üretilebilirlik | Varsayılan yollar `data/raw` → `data/clean` |

Indeed çıktısı bu denetimden sonra birebir aynı kaldı. Ham veriye dokunulmadı.

---

## 14. Challenger teyit tablosu (11 Kasım 2026)

**Neden:** layoffhedge az bilinen bir kaynak. AI payının zaman içindeki seyrini, medyada en çok alıntılanan bağımsız kaynakla (Challenger, Gray & Christmas) karşılaştırmak istedik.

**Nasıl toplandı:** Ocak–Ekim 2026 için her ayın raporundan (ya da raporu aktaran haberden) iki rakam alındı: ABD toplam duyurulan kesinti ve AI gerekçeli kesinti. Rakamlar ve kaynak linkleri `build_challenger.py` içindedir.

**Nasıl doğrulandı:** Challenger her raporda yılbaşından bugüne (YTD) toplamları da veriyor. Script, aylık rakamları toplayıp bu YTD değerleriyle karşılaştırıyor (7 AI + 4 toplam kontrol noktası); biri tutmazsa hata veriyor. Hepsi tuttu.
- Ocak AI rakamı doğrudan bulunamadı; Şubat YTD (12.304) − Şubat (4.680) = 7.624 olarak türetildi.
- Eylül için bir haberde "7.000" geçiyor; YTD zinciriyle tutmadığı için kullanılmadı, doğru değer 3.961.

| Ay | Toplam | AI | AI payı |
|---|---|---|---|
| Oca | 108.435 | 7.624 | %7,0 |
| Şub | 48.307 | 4.680 | %9,7 |
| Mar | 60.620 | 15.341 | %25,3 |
| Nis | 83.387 | 21.490 | %25,8 |
| May | 97.006 | 38.579 | **%39,8** |
| Haz | 45.849 | 14.029 | %30,6 |
| Tem | 33.429 | 10.970 | %32,8 |
| Ağu | 52.881 | 3.462 | %6,5 |
| Eyl | 43.281 | 3.961 | %9,2 |
| Eki | 43.994 | 1.265 | **%2,9** |
| **Toplam** | **617.189** | **121.401** | **%19,7** |

**Sonuç:** Challenger'ın aylık AI payı, layoffhedge'in AI **duyuru sayısı** payıyla aynı yönde (Pearson 0,72; Oca–Tem → Ağu–Eki: Challenger %24,4 → %6,2, layoffhedge %19,5 → %3,6). layoffhedge **kişi** payıyla örtüşmüyor (−0,20), çünkü kişi payı birkaç dev duyuruya bağlı. Bu, Bölüm 13'te sayı payını eklemenin neden gerekli olduğunu da gösteriyor. 10 aylık seride korelasyon yalnızca yön teyididir.

---

## 15. PostgreSQL katmanı (11 Kasım 2026)

**Neden:** Veri küçük, pandas yeterdi; SQL katmanı hesapları şeffaf ve tekrar edilebilir yapmak, Power BI'a düzgün bir yıldız şema vermek ve iki bağımsız yoldan (Python + SQL) aynı rakamlara ulaşıldığını göstermek için eklendi.

**Veritabanı:** `ai_is_piyasasi` (PostgreSQL 18). Projeye özel; başka veritabanlarına dokunulmadı.

| Dosya | Ne yapıyor | Neden |
|---|---|---|
| `01_schema.sql` | Staging (CSV'nin birebir kopyası), boyut (`dim_company`, `dim_industry`, `dim_date`, `dim_country`) ve olay (`fact_layoffs`, `fact_ai_postings`, `fact_challenger`) tablolarını kurar | Ham yükleme ile analiz yapısı ayrılır; yıldız şema Power BI filtrelerini doğru çalıştırır |
| `02_load.sql` | `\copy` ile CSV → staging, sonra staging → boyut/olay; satır kaybı kontrolü | Dönüşüm SQL içinde görünür; dosya tekrar çalıştırılabilir |
| `03_analysis.sql` | 5 soru + birleşik tablo + veri kalitesi için view'ler | Power BI aynı view'leri okur → rakamlar tek yerde hesaplanır |
| `04_checks.sql` | 41 rakamı Python sonuçlarıyla karşılaştırır | Python ve SQL aynı sonucu vermeli; fark olursa hata verir |

**Tasarım kararları:**
- `date_key` = YYYYMMDD. Aylık veriler (Indeed, Challenger) ayın 1. gününe bağlanır; üç veri seti tek `dim_date` üzerinden ay bazında birleşir. `dim_date` 2019'dan başlar çünkü Indeed 2019'dan başlıyor.
- `total_workforce` şirket tablosunda değil olay tablosunda: 21 şirkette satırdan satıra farklı.
- Ayı bilinmeyen 6 satırın `date_key` değeri NULL; silinmediler, `in_main_analysis = FALSE`.
- Sektörlerin Türkçe adları `dim_industry.industry_tr` kolonunda (Power BI etiketleri için).
- CHECK kuralları veri kurallarını kalıcı yapar: sıkı AI ⇒ AI etiketli; sıkı AI satırı tartışmalı / üst sınır olamaz; ana analiz satırının tarihi olmalı; kişi ≤ toplam çalışan; yüzdeler 0–100. Kasıtlı hatalı satırla test edildi, reddedildi.

**Sonuç:** 653 / 837 / 10 satır kayıpsız yüklendi; 41/41 kontrol Python ile aynı.

**SQL'den çıkan ek gözlemler:**
- "Sadece geniş" AI satırları (tartışmalı etiket ya da üst sınır, 18 satır) çok büyük: medyan 1.750 kişi (sıkı AI 295, AI değil 180). Geniş tanımı şişiren şey bu dev satırlar.
- Sektör AI payında Kamu & STK (7 duyuru) ve Enerji (2 duyuru) `small_sample` olarak işaretli; tek bir duyuru oranı belirliyor.
- Oca–Eyl 2026'da Indeed ABD AI ilan payı sürekli artarken (%4,6 → %7,2) layoffhedge AI duyuru payı düşüyor (korelasyon −0,38). İki trend yan yana gösterilir; neden-sonuç iddia edilmez.

---

## 16. Dış göz değerlendirmesine göre düzeltmeler (11 Kasım 2026)

Proje bir işe alım yöneticisi gözüyle incelendi; bulunan 7 zayıf nokta ve yapılanlar:

| # | Zayıf nokta | Yapılan |
|---|---|---|
| 1 | Junior sonucu veriye dayanmıyor (kıdem bilgisi yok) | Sonuç "verinin düşündürdükleri" olarak yeniden yazıldı, yorum olduğu açıkça belirtildi; sınırlılık eklendi |
| 2 | Kaynakların kapsamı farklı (dünya / 9 ülke / ABD) | Sınırlılık olarak açıkça yazıldı; karşılaştırmalar "yön teyidi" olarak adlandırıldı |
| 3 | Doğrulama asimetrik | Ölçüldü: AI-etiketsiz satırların linkleri tarandı (yeni eksik etiket yok, Comcast kontrol edildi); duyarlılık analizi: en kötü senaryoda %16,9 → ~%18,1 |
| 4 | İstatistiksel ağırlık az | `istatistik_testleri.py`: bootstrap GA, Mann-Whitney, permütasyon testi, dönem ayrımı duyarlılığı (bkz. VERI_KALITESI.md Bölüm 7) |
| 5 | Indeed metriği dar okunmalı | "AI talebi / AI becerisi talebi" ifadeleri "AI'dan bahseden ilanların payı" olarak değiştirildi; sınırlılık eklendi |
| 6 | Git/GitHub yok | Git deposu kuruldu, ilk commit yapıldı |
| 7 | Projeyi savunabilmek | `docs/MULAKAT_HAZIRLIK.md`: muhtemel sorular, cevaplar ve kendini test etme listesi |

---

## Mülakatta tek cümleyle

> "Az bilinen bir kaynaktan gelen veriyi önemliliğe göre doğruladım: sonucu en çok etkileyen tüm büyük satırları ve AI etiketli tüm satırları haber kaynaklarıyla tek tek karşılaştırdım, küçük satırlardan rastgele örneklem aldım, 4 hatalı ve 2 yanlış rakamlı satırı buldum, sonra bulgularımın şüpheli satırlar çıkarıldığında da değişmediğini sağlamlık testiyle gösterdim."
