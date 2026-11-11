# Mülakat ve Sunum Hazırlığı

Bu dosya projeyi **kendi cümlelerinle** savunabilmen için. Her soruda önce kısa cevap (ezberleme, anla), sonra "derine inerlerse" kısmı var. Rakamlar `docs/PROJECT_PLAN.md` Bölüm 5 ile aynıdır. Not: GitHub tarafı İngilizce; veri etiketleri de İngilizce (ör. `T1_manual_verified`, `verified`, `is_ai_strict`).

---

## 0. İki dakikalık proje anlatımı

> "2026'da şirketlerin işten çıkarmalarda yapay zekâyı ne kadar gerekçe gösterdiğine ve bunun iş ilanlarındaki AI'la nasıl yan yana durduğuna baktım. Ana verim layoffhedge adlı az bilinen bir siteden geliyordu, o yüzden önce veriye güvenmedim: sonucu en çok etkileyen büyük satırları ve AI etiketli bütün satırları haberlerle tek tek karşılaştırdım; 4 yanlış yıllı ve 2 yanlış rakamlı satır buldum. AI etiketinin bazen tartışmalı, bazı rakamların da '…'e kadar' olduğunu gördüm; bu yüzden iki tanım kullandım ve sıkı olanı ana rakam yaptım: duyurulan kesintilerin yaklaşık altıda biri AI'a bağlanıyor. AI gerekçesi ilkbahar–yazda yüksek, Ağustos'tan sonra çok düşük; bunu ABD'de bağımsız bir kaynak olan Challenger raporlarıyla teyit ettim. Aynı dönemde AI'dan bahseden iş ilanlarının payı ise bir yılda ikiye katlandı. Neden-sonuç iddia etmiyorum; iki trendi yan yana koyuyorum. Araçlar: Python/pandas ile temizlik ve doğrulama, PostgreSQL'de yıldız şema ve analiz, Power BI'da dashboard."

---

## 1. Veri ve doğrulama

**S: Neden bu veri kaynağına güvendin?**
Güvenmedim, doğruladım. layoffhedge her satır için kaynak linki veriyor ama yöntemini açıklamıyor. Bu yüzden *önemliliğe göre doğrulama* yaptım: sonucu en çok etkileyen satırlara mutlaka baktım (3.000+ kişilik bütün satırlar, AI etiketli bütün satırlar), geri kalanlardan rastgele örneklem aldım. Toplam 146 satır.
- *Derine inerlerse:* 4 satır eski yıllara aitti (Intel 2024, Nestlé 2025, Nokia 2023, CrowdStrike 2025) → analizden çıkardım. 2 rakam yanlıştı (Verizon 3.000 → 500, Commerzbank 6.900 → 3.000) → düzelttim, orijinali ayrı kolonda sakladım. Rastgele örneklemde hata çıkmadı.

**S: Neden 653 satırın hepsine bakmadın?**
Zaman ve fayda dengesi. Toplamın büyük kısmını az sayıda dev satır oluşturuyor; onlar yanlışsa sonuç değişir, 80 kişilik bir satır yanlışsa değişmez. Denetçilerin kullandığı yaklaşım bu (materiality). Elle bakılan satırlar kişi sayısının %72'sini kapsıyor.

**S: Satır sildin mi?**
Hayır. "Silme, işaretle" prensibi: her sorun bir kolonla işaretli (`is_invalid`, `is_upper_bound`…). Böylece hangi satırı neden dışarıda bıraktığımı gösterebiliyorum ve farklı filtrelerle yeniden hesaplayabiliyorum.

**S: Güvenilirlik katmanları (T1–T5) ne?**
Her satırın ne kadar güvenilir olduğunu gösteren tek etiket. T1–T2 elle kontrol edildi; T3 linkte şirket adı ve rakam var; T4 sadece şirket adı; T5 genel sayfa. Bulgularımı T1–T3 "çekirdek" ile ve sadece elle kontrol edilenlerle tekrar hesapladım (sağlamlık testi).

**S: Doğrulama dengesiz değil mi? AI satırlarının hepsine baktın, diğerlerinin azına.**
Evet, bu bir sınırlılık ve ölçtüm. AI etiketi olmayan satırlarda kaçırılmış AI gerekçesi olabilir. Elle baktığım 50 AI-etiketsiz satırda 2 eksik etiket buldum (%4). Bu oranı bakmadığım 502 satıra uygulasam bile ana rakam %16,9'dan en fazla ~%18'e çıkıyor. Ayrıca bütün linkleri AI kelimeleri için taradım, yeni bir eksik etiket çıkmadı.

---

## 2. Tanımlar ve ana rakam

**S: %16,9 ile %38,4 arasındaki fark nereden geliyor? Neden %16,9?**
Sitenin "AI-DRIVEN" etiketi bazen tartışmalı: UPS'te ana gerekçe Amazon hacminin azalması, HubSpot'ta CEO AI'ı açıkça reddediyor. Bazı rakamlar da kesin değil, "…'e kadar" (Oracle 30.000, Meta 16.000). Sıkı tanım bu satırları dışarıda bırakıyor → %16,9, ana rakam. Geniş tanım hepsini sayıyor → %38,4, sadece üst sınır.
- *Kanıt:* Sadece geniş tanıma giren 18 satırın medyanı 1.750 kişi; geniş tanımı şişiren şey bu birkaç dev satır.

**S: %16,9 ne kadar kesin?**
Çok kesin değil, dürüstçe söylerim: bootstrap %95 güven aralığı %8,8–27,5. Rakam birkaç dev satıra bağlı. Bu yüzden "yaklaşık altıda bir" diyorum ve yanında duyuru sayısı payını veriyorum (%11,5, aralık %9–14, çok daha kararlı).

**S: Neden "kaybedilen işler" değil de "duyurulan kesintiler"?**
Büyük rakamların bir kısmı gerçekleşmiş işten çıkarma değil, yıllara yayılan plan ya da üst sınır. Örneğin Hollanda Hükümeti'nin 25.000'lik planı 2035'e kadar.

---

## 3. Zaman trendi ve bağımsız teyit

**S: AI payı zamanla nasıl değişti?**
AI duyurularının payı Ocak–Temmuz arasında %8–20 (Mayıs'ta zirve %40), Ağustos–Kasım arasında %3–6.

**S: Neden iki ayrı ölçü kullandın (kişi payı ve sayı payı)?**
Kişi payı tek bir dev duyuruyla sıçrıyor. Ekim'de Hollanda Hükümeti'nin planı oranı tek başına %50'ye çıkarıyor; aynı ayda AI duyurularının sayıca payı %5. Sayı payı "kaç şirket AI'ı gerekçe gösteriyor" sorusunu cevaplıyor ve dev satırlardan etkilenmiyor.

**S: Challenger ile karşılaştırma ne gösterdi?**
Challenger ABD'deki kesinti duyurularını aylık raporlayan, medyada çok alıntılanan bir firma. Onların aylık AI payı bizim sayı payımızla aynı yönde (korelasyon 0,72): zirve Mayıs, Ağustos'tan sonra düşüş. Kişi payımızla örtüşmüyor (−0,20). Bu da sayı payının doğru ölçü olduğunu gösteriyor.
- *Rakamları nasıl doğruladın?* Challenger her raporda yılbaşından bu yana toplamı veriyor. Aylık rakamları topladım, 11 kontrol noktasında bu toplamlarla tuttu. Bir haberde geçen "Eylül 7.000" rakamı tutmadı, kullanmadım.

**S: Ağustos ayrımını veriye bakıp sen seçmedin mi?**
Ağustos, bağımsız kaynakta AI'ın 5 aylık birinciliği kaybettiği ay; ama asıl cevabım şu: ayrımı Haziran, Temmuz, Ağustos ya da Eylül seçsem de "önce yüksek, sonra düşük" sonucu iki kaynakta da çıkıyor. Yani sonuç ayrım ayına bağlı değil. (Mayıs seçilirse fark çıkmıyor, çünkü zirve ayı Mayıs "sonra" grubuna düşüyor.)

**S: 10 aylık seride korelasyon anlamlı mı?**
Tek başına kanıt değil, yön teyidi. Permütasyon testinde p ≈ 0,006 çıkıyor ama aylık seriler birbirine bağımlı, o yüzden bu p iyimser. Ben bunu "iki bağımsız kaynak aynı deseni gösteriyor" diye sunuyorum, "kanıtladım" diye değil.

---

## 4. Diğer sorular (Q1, Q2, Q4, Q5)

**S: Hangi sektörler en çok kesinti duyurdu?**
Otomotiv & Ulaşım (%31), Teknoloji (%24), Finans (%11). Otomotivi birkaç dev plan taşıyor (Volkswagen toplam 100.000). Sıralama bütün güvenilirlik seviyelerinde aynı.

**S: Hangi sektörlerde AI daha çok gerekçe?**
Finans %33, Teknoloji %21, Kripto & Fintech %68 (sıkı, kişi bazında). Sağlık, Tüketim ürünleri, Eğitim'de sıfır. Kamu (%96) ve Enerji (%88) çok az duyuruya dayanıyor; tek bir duyuru oranı belirliyor, o yüzden yorumlamıyorum.

**S: AI duyuruları daha fazla kişiyi mi kapsıyor?**
Evet: medyan 295 kişiye karşı 180. Fark 115 kişi, bootstrap güven aralığı 50–421 (sıfırı içermiyor), Mann-Whitney p < 0,001. Ama "AI'ı büyük şirketler gerekçe gösteriyor" iddiası tutmadı; AI duyurusu yapan şirketler aslında daha küçük. Bu iddiayı projeden çıkardım.
- *Neden ortalama değil medyan?* Birkaç dev satır ortalamayı bozuyor (AI ortalaması 1.494, medyanı 295).

**S: İlanlarda ne oldu?**
AI'dan bahseden ilanların payı bir yılda ikiye katlandı: ABD %3,6 → %7,2, Birleşik Krallık %4,9 → %9,8. Karşılaştırılabilir 8 ülkenin hepsinde artış var.
- *Bu AI becerisi talebi mi?* Tam olarak değil. "İlanda AI geçmesi" AI ürünü satan şirketlerin ilanlarını ya da "işe alımda AI kullanıyoruz" beyanlarını da içeriyor. Kanada'da Ontario'daki bir yasa bu beyanı zorunlu yaptı ve oran %18'e fırladı; bu yüzden Kanada'yı karşılaştırma dışında tuttum.

---

## 5. Zor sorular (en çok bunlara hazırlan)

**S: Junior adaylarla ilgili sonucun verinden nasıl çıkıyor?**
Doğrudan çıkmıyor, ve bunu açıkça söylüyorum. Verilerimde kıdem bilgisi yok. Bulgu şu: kesinti gerekçesi olarak AI azalırken AI'dan bahseden ilanlar artıyor. Junior adaylar için kısmı bu iki trendin **düşündürdüğü** bir yorum: AI bir kesinti tehdidinden çok bir ilan gereksinimi olarak öne çıkıyor. Bunu test etmek için kıdem bilgisi olan ilan verisi gerekir.

**S: Dünya geneli kesintileri ABD ilanlarıyla karşılaştırmak doğru mu?**
Kapsamlar farklı: layoffhedge dünya geneli, Indeed 9 ülke (Türkiye yok), Challenger sadece ABD. Bu yüzden bunları "aynı şeyi ölçüyor" diye değil, "aynı yönü gösteriyor mu" diye karşılaştırıyorum.

**S: AI işleri mi götürüyor?**
Bu veri bunu söyleyemez. Bu veri şirketlerin ne **söylediğini** ölçüyor; AI'ın gerçekte neden olduğunu değil. Projenin ana fikri tam olarak bu fark.

**S: Bu projeyi tekrar yapsaydın neyi farklı yapardın?**
1. Doğrulamayı baştan daha dengeli planlardım: AI-etiketsiz satırlardan da daha büyük bir örneklem alırdım.
2. Kıdem bilgisi olan bir ilan verisi (ör. LinkedIn ya da Kariyer.net) bulmaya çalışırdım; junior sorusunu doğrudan test edebilmek için.
3. Türkiye verisi eklemeye çalışırdım.
4. Projeyi en baştan git ile sürüm kontrollü yürütürdüm.

---

## 6. Teknik sorular (SQL / Python)

**S: Neden PostgreSQL? Veri küçük, pandas yetmez miydi?**
Yeterdi. SQL katmanını üç sebeple ekledim: hesapları şeffaf ve tekrar edilebilir yapmak, Power BI'a düzgün bir yıldız şema vermek, ve aynı rakamlara iki bağımsız yoldan ulaşmak. `04_checks.sql` 41 rakamı Python sonuçlarıyla karşılaştırıyor; hepsi aynı.

**S: Yıldız şema ne, neden kullandın?**
Ortada olayların tutulduğu bir tablo (`fact_layoffs`: her duyuru bir satır), çevresinde tanım tabloları (şirket, sektör, tarih, ülke). Power BI filtreleri bu yapıda doğru çalışıyor ve üç veri seti ortak tarih tablosu üzerinden ay bazında birleşiyor.

**S: `date_key` neden YYYYMMDD sayısı?**
Veri ambarlarında yaygın bir alışkanlık: okunabilir (20260315 = 15 Mart 2026), sıralanabilir ve tam sayı olduğu için birleştirmeler hızlı. Aylık veriler (Indeed, Challenger) ayın 1. gününe bağlanıyor (20260301).

**S: `total_workforce` neden şirket tablosunda değil?**
Çünkü 21 şirkette satırdan satıra farklı (Amazon'da 350 bin ve 1,55 milyon). Şirket tablosuna tek bir değer koysam yanlış olurdu.

**S: CHECK kuralları ne işe yarıyor?**
Hatalı verinin tabloya girmesini engelliyor. Örneğin "AI etiketi yoksa sıkı AI olamaz" ve "çıkarılan kişi toplam çalışanı geçemez". Kasıtlı hatalı satırla test ettim, reddedildi.

**S: Kullandığın SQL teknikleri?**
`RANK()` (sektör sıralaması), `LAG()` (aydan aya değişim), `AVG() OVER (ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)` (3 aylık hareketli ortalama), `PERCENTILE_CONT(0.5)` (medyan), `FILTER (WHERE …)` (koşullu toplam), CTE ve `CORR()`.

**S: Bootstrap nedir?**
Veriden tekrar tekrar (10.000 kez) yerine koyarak rastgele örnek çekip aynı hesabı yapmak. Sonuçların %95'inin düştüğü aralık güven aralığıdır. Dağılım varsayımı gerektirmiyor; dev satırları olan bu veri için uygun.

**S: Mann-Whitney neden, t-testi neden değil?**
Kişi sayıları normal dağılmıyor (çok çarpık: medyan 200, en büyük 50.000). Mann-Whitney sıralamalara bakıyor, normal dağılım varsaymıyor.

---

## 7. Kendini test et

Aşağıdakileri **notlara bakmadan**, yüksek sesle anlatabiliyorsan hazırsın:

- [ ] Projeyi 2 dakikada anlat (Bölüm 0)
- [ ] Sıkı ve geniş tanım farkını bir örnekle anlat (UPS ya da Oracle)
- [ ] Neden kişi payı yerine sayı payına güvendiğini Ekim örneğiyle anlat
- [ ] Challenger rakamlarını nasıl doğruladığını anlat (yılbaşından bu yana toplamlar)
- [ ] Bulduğun 6 hatayı say (4 yanlış yıl + 2 yanlış rakam)
- [ ] Hangi iddiayı neden çıkardığını anlat (büyük şirketler)
- [ ] "Junior nerede?" sorusuna cevap ver
- [ ] Yıldız şemayı bir kâğıda çiz
- [ ] Bir SQL sorgusunu (ör. `v_q3_monthly_ai`) satır satır açıkla
- [ ] 3 sınırlılık say

**Pratik önerisi:** Bir arkadaşına ya da aynaya karşı Bölüm 5'teki 4 zor soruyu cevapla. Takıldığın yerde bu dosyaya dön.
