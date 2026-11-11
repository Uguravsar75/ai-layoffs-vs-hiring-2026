# Veri Kalitesi ve Doğrulama

Bu projenin ana veri seti, layoffhedge.com'un 2026 işten çıkarma listesidir (653 satır, 8 Kasım 2026 sürümü). Kaynak az bilinen bir site olduğu ve yöntemini açıklamadığı için veriyi analizden önce üç adımda kontrol ettim: **önemliliğe göre doğrulama, örnekleme ve sağlamlık testi.**

## 1. Otomatik kontroller (653 satırın tamamı)
- Boş hücre, tekrar eden satır ve mantık hatası (çıkarılan kişi > toplam çalışan) yok.
- "Workforce %" kolonu, kişi sayısı / toplam çalışan hesabıyla birebir tutuyor.
- Tarih kolonunda yıl yok ("Oct 13"); hepsi 2026 olarak işlendi. 6 satırda ay bilinmiyor: 3'ünde yıl aralığı var ("2025-30", yıllara yayılan plan), 3'ünde sadece "2026" yazıyor. Bu 6 satır ana analizden çıkarıldı.
- Her satırın kaynak linki tarandı: link şirket adını ve kişi sayısını içeriyor mu, resmi WARN bildirimi mi, genel bir derleme sayfası mı?
- Linkteki rakam veriden farklı olan satırlar tarandı; anlamlı fark çıkan 2 satır (Gilead, Capital One) elle kontrol edildi ve veri doğru çıktı (linkler eski başlık / birikimli toplam içeriyordu).

## 2. Elle doğrulama (146 satır)
Beş grup satır haber kaynaklarıyla tek tek karşılaştırıldı:
1. **3.000 kişiden büyük satırların tamamı** (sonuçları en çok etkileyen satırlar),
2. **"AI-DRIVEN" etiketli satırların tamamı** (projenin ana sorusu bu etikete dayanıyor),
3. **3.000'in altındaki diğer satırlardan 20'lik rastgele (tabakalı) örneklem,**
4. **Linkteki rakamı veriden farklı çıkan 2 satır,**
5. **AI etiketsiz olup linkinde AI kelimesi geçen 1 satır** (Comcast; gerekçe AI değil çıktı).

| Sonuç | Satır |
|---|---|
| Doğrulandı | 104 |
| Kaynağa göre düzeltildi | 2 (Verizon 3.000 → 500, Commerzbank 6.900 → 3.000) |
| Kısmen doğrulandı (plan, "...kadar", gönüllü emeklilik, rakam teyit edilemedi vb.) | 27 |
| Hatalı, analizden çıkarıldı (önceki yılların duyuruları) | 4 (Intel 2024, Nestlé 2025, Nokia 2023, CrowdStrike 2025) |
| Rakam uyuşmazlığı | 1 (Apple 147) |
| Doğrulanamadı | 8 |

Her satırın bulgusu ve kaynağı `verification_log.csv` dosyasındadır.

**AI satırlarının sonucu:** Ana analizdeki 92 AI-DRIVEN satırın **90'ı tamamen veya kısmen doğrulandı**, 2'si (Skai, Rapyd) bulunamadı. Bir satır (CrowdStrike) 2025 duyurusu çıktı ve çıkarıldı. Yani AI payının **pay kısmı (AI'a bağlanan kesintiler) satır satır doğrulanmış** durumdadır.

**Gözlemler**
- Hatalı satırların çoğu "2026'nın büyük işten çıkarmaları" türünden derleme sitelerinden geliyor. Doğrudan habere bağlanan linklerde yıl hatası nadir.
- Rastgele örneklemde (20 küçük satır) hatalı satır çıkmadı; 16'sı tamamen ya da kısmen doğrulandı, 4'ü küçük yerel olaylar olduğu için bulunamadı.
- Büyük rakamların önemli bir kısmı gerçekleşmiş işten çıkarma değil, yıllara yayılan **planlardır**. Bu nedenle projede "kaybedilen işler" değil, **"duyurulan kesintiler"** ifadesi kullanılmıştır.
- "AI-DRIVEN" etiketi sitenin kendi sınıflandırmasıdır. 7 satırda tartışmalıdır (UPS, Dell, HDFC Bank, HubSpot, Uber, Southern Cross Media, Wells Fargo); 2 satırda haberde AI geçtiği hâlde etiket eksiktir (Envato, United Internet). 13 satırdaki rakam bir üst sınırdır ("...kadar").

## 3. İki AI tanımı
| Tanım | Kural | Kullanım |
|---|---|---|
| **Sıkı** (`is_ai_strict`) | AI-DRIVEN etiketli **ve** etiketi tartışmalı değil **ve** rakamı "…'e kadar" değil (74 satır) | **Ana rakam — her yerde bu** |
| Geniş (`is_ai_driven`) | Tüm AI-DRIVEN etiketleri (92 satır) | Yalnızca üst sınır |

Neden önemli: Geniş tanımdaki fark büyük ölçüde birkaç dev satırdan geliyor (UPS 30.000, Oracle 30.000, HSBC 20.000, Meta 16.000, Cognizant 15.000, Dell 11.000, Microsoft 8.750). Bu satırların ya AI gerekçesi tartışmalı ya da rakamı bir üst sınır.

## 4. Güvenilirlik katmanları
Her satır tek bir güvenilirlik etiketi taşır (`reliability_tier`). Ana analiz: 643 satır, 653.456 kişi.

| Katman | Anlamı | Satır | Kişi payı |
|---|---|---|---|
| T1 | Elle doğrulandı / düzeltildi | 106 | %47,2 |
| T2 | Elle kısmen doğrulandı | 27 | %25,0 |
| T3 | Güçlü kaynak (link şirketi ve rakamı içeriyor ya da satıra özel resmi WARN sayfası) | 180 | %9,3 |
| T4 | Orta kaynak (link şirketi içeriyor) | 186 | %11,1 |
| T5 | Zayıf kaynak (genel sayfa / derleme sitesi / WARN listesinin ana sayfası) | 144 | %7,3 |

Ana analizdeki kişi sayısının **%72'si elle kontrol edildi**, **%81,6'sı** T1–T3 "doğrulanmış çekirdek" içindedir.

## 5. Sağlamlık testi
Ana bulgular üç farklı veri seviyesinde yeniden hesaplandı (`robustness_check.csv`). AI payları **sıkı tanımla**, parantez içinde geniş tanım:

| Bulgu | Tüm veri | Çekirdek (T1–T3) | Sadece elle (T1–T2) | Sonuç |
|---|---|---|---|---|
| En çok etkilenen 3 sektör | Otomotiv, Teknoloji, Finans | Aynı | Aynı | ✅ Sağlam |
| AI kişi payı Ocak–Nisan ortalaması | %18,2 (%57,3) | %22,3 (%69,9) | %23,4 (%74,1) | ✅ Her seviyede daha yüksek |
| AI kişi payı Haziran–Eylül ortalaması | %5,2 (%8,0) | %6,6 (%9,9) | %13,0 (%16,8) | ✅ Her seviyede daha düşük — düşüş sağlam |
| AI duyuruları daha fazla kişiyi kapsıyor (medyan) | 295 vs 180 | 320 vs 200 | — | ✅ Yön aynı |
| AI'ı gerekçe gösterenler daha büyük şirketler | Hayır | Hayır | Hayır | ❌ Kullanılmamalı |

**Ana AI payı rakamı tüm veriden raporlanır:** kesinti duyurularının kişi bazında **%16,9'u** AI'a bağlanıyor (sıkı tanım). Tüm etiketlerle bu oran %38,4'tür ve birkaç dev plana bağlı olduğu için yalnızca üst sınır olarak verilir.

**Duyuru sayısı bazlı ikinci ölçü:** Kişi payı tek bir dev duyuruyla sıçrayabilir (Ekim'de Hollanda Hükümeti'nin 25.000'lik planı kişi payını tek başına %50,5'e çıkarıyor). Bu yüzden aylık trend duyuru sayısıyla da verilir. Sıkı tanımla AI duyurularının payı Ocak–Temmuz arasında %8–20 bandında (zirve **Mayıs %40,3**), Ağustos'tan itibaren **%3–6**'ya iniyor.

> Not: Elle doğrulama AI satırlarının tamamını kapsadığı için T1–T2 seviyesinde AI satırları fazla temsil edilir; bu seviyedeki AI payı seçim etkisi taşır ve ana rakam olarak kullanılmaz. Sağlamlık testinin amacı burada oranın kendisi değil, **zaman içindeki yönün ve sektör sıralamasının** her seviyede aynı kalmasıdır.

## 6. Bağımsız teyit (Challenger, Gray & Christmas)
AI payının zaman içindeki seyri, Challenger, Gray & Christmas'ın Ocak–Ekim 2026 aylık ABD raporlarıyla karşılaştırıldı (`challenger_ai_monthly.csv`, `challenger_vs_layoffhedge.csv`). Aylık rakamların toplamı, Challenger'ın raporlarında verdiği yılbaşından bugüne toplamlarla 11 kontrol noktasında birebir tutuyor; Eylül için bir haberde geçen "7.000" bu zincirle tutmadığı için kullanılmadı (doğrusu 3.961).

| | Oca–Tem ort. | Ağu–Eki ort. | Challenger ile korelasyon |
|---|---|---|---|
| Challenger AI payı (ABD, kişi) | %24,4 | %6,2 | — |
| layoffhedge AI **duyuru sayısı** payı (sıkı) | %19,5 | %3,6 | **0,72** |
| layoffhedge AI **kişi** payı (sıkı) | %18,4 | %17,5 | −0,20 |

İki bağımsız kaynak aynı hikâyeyi anlatıyor: AI gerekçesi ilkbahar–yaz boyunca yüksek (Challenger'da Mart–Temmuz arası 1. sırada, zirve Mayıs %39,8), Ağustos'tan itibaren belirgin şekilde düşüyor (Ekim %2,9). Bu örtüşme layoffhedge'in **duyuru sayısı** payında görülüyor; kişi payı ise birkaç dev duyurunun (Mart'ta üst sınır rakamlar, Ekim'de ABD dışındaki Hollanda Hükümeti planı) etkisiyle bozuluyor. Dönem ayrımı Ağustos olarak seçildi, çünkü bağımsız kaynakta AI tam o ay 1. sıradan düşüyor.

> Not: 10 aylık bir seride korelasyon güçlü bir kanıt değildir; burada yalnızca yönün teyidi olarak kullanılır. Challenger yalnızca ABD'yi, layoffhedge dünyayı kapsar. Challenger'daki AI rakamı da işverenin beyan ettiği gerekçedir.

## 7. İstatistik testleri (`istatistik_testleri.py`, `istatistik_sonuclari.csv`)
Makine öğrenmesi yok; yeniden örnekleme (bootstrap, 10.000 tekrar, sabit tohum) ve klasik testler. Amaç: bulguların tesadüf ya da seçilen pencere kaynaklı olup olmadığını sınamak.

| Test | Sonuç | Anlamı |
|---|---|---|
| Medyan farkı (AI sıkı − diğer) | 115 kişi, %95 GA 50–421 | GA sıfırı içermiyor → fark tesadüf değil |
| Mann-Whitney U (tek yönlü) | p < 0,001 | AI duyuruları daha fazla kişi kapsıyor |
| Ana AI payı (sıkı, kişi) | %16,9, GA %8,8–27,5 | Geniş aralık: rakam birkaç dev satıra bağlı → "yaklaşık altıda bir" diye sunulmalı |
| AI payı (sıkı, duyuru sayısı) | %11,5, GA %9,0–14,0 | Dar aralık: daha kararlı ölçü |
| Dönem ayrımı duyarlılığı | Ayrım Haziran, Temmuz, Ağustos ya da Eylül seçilse de "önce yüksek → sonra düşük" (her iki kaynakta) | Ağustos'u sonradan seçmemiz sonucu belirlemiyor. Mayıs seçilirse fark yok, çünkü Mayıs zirve ayı "sonra" grubuna düşüyor |
| Challenger ~ sayı payı | r = 0,72, permütasyon p ≈ 0,006 | Aylık seriler bağımlı olduğu için p iyimser olabilir; yön teyidi |
| Challenger ~ kişi payı | r = −0,20, p ≈ 0,72 | Örtüşme yok |
| Kaçırılmış AI etiketi | Sıkı AI payı en kötü senaryoda %16,9 → ~%18,1 | Asimetrik doğrulama sonucu değiştirmiyor |

## Sınırlılıklar
- Veri yalnızca kamuoyuna duyurulmuş ve haberlere yansımış kesintileri içerir; küçük şirketler eksik temsil edilir.
- Ülke kolonu yoktur; ülke bazında analiz yapılamaz.
- **Kapsamlar farklı:** layoffhedge = dünya geneli (ülke kolonu yok) · Indeed = 9 ülke (Türkiye yok) · Challenger = sadece ABD. Bu yüzden kaynaklar arası karşılaştırmalar **yön teyidi**dir; aynı nüfusu ölçtükleri iddia edilmez. Sunumda bu cümle açıkça söylenir.
- **Kıdem bilgisi yok:** Hiçbir veri setinde junior/senior ayrımı yoktur. Junior adaylarla ilgili bölüm bir **yorumdur**, bulgu değildir.
- **Doğrulama asimetrik:** AI etiketli satırların hepsi, AI etiketsiz satırların ise 50'si elle kontrol edildi. Kaçırılmış AI etiketleri ana rakamı düşük gösterebilir. Ölçüldü (`istatistik_testleri.py`, test 5): elle bakılanlarda eksik etiket oranı %4 (2/50); bu oran bakılmayan 502 satıra uygulansa sıkı AI payı %16,9 → en fazla ~%18,1 olur. Ek olarak tüm AI-etiketsiz satırların linkleri AI kelimeleri için tarandı; yeni eksik etiket çıkmadı (Comcast adayı kontrol edildi, gerekçe AI değil).
- **Indeed metriği dar:** "İlanda AI geçmesi" ≠ AI becerisi talebi. AI ürünü satan şirketlerin ilanları ve "işe alımda AI kullanıyoruz" beyanları da sayılır (Kanada'daki yasa etkisi bunun kanıtı). Doğru ifade: "AI'dan bahseden ilanların payı".
- **İstatistiksel güç sınırlı:** Zaman serisi 10 ay; korelasyonlar yön teyididir. Ana AI payı (%16,9) birkaç dev satıra bağlıdır: %95 güven aralığı %8,8–27,5. Duyuru sayısı payı daha kararlıdır (%11,5; GA %9,0–14,0).
- `total_workforce` sitenin tahminidir ve aynı şirkette satırdan satıra farklı olabilir (ör. Amazon 350 bin / 1,55 milyon); bu yüzden sektör bazında toplam çalışan üzerinden oran hesaplanmamış, satır bazlı iş gücü yüzdesinin medyanı kullanılmıştır.
- Son aylarda sitenin daha fazla küçük duyuru topladığı görülmektedir; aylık duyuru sayısı karşılaştırmaları dikkatle yorumlanmalıdır.
- Kasım 2026 kısmi aydır (6 Kasım'a kadar).
