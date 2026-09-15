# Sözleşme Asistanı — Proje Rehberi

Bu dosyayı her oturum başında oku. Kullanıcı **Emre**, bir sendikada (TÜMTİS) TİS uzmanı.
**Kod bilgisi YOK.** Bu yüzden aşağıdaki "Çalışma Tarzı" kurallarına harfiyen uy.

---

## Dil ve iletişim

- **Her zaman Türkçe** yanıt ver. Sıcak, sabırlı, açık bir dil kullan.
- Teknik terimleri (özellikle Firebase Console, terminal komutları) **çok detaylı, adım adım** anlat. Emre teknik menülerde kolayca kayboluyor; "beni detaylı yönlendir, anlamıyorum" diyor.
- Kod açıklamalarında jargon yerine sade dil kullan. Ne yaptığını ve neden yaptığını kısaca söyle.
- Her büyük değişiklikten önce **ne yapacağını anlat**, sonra uygula.

## Çalışma tarzı (ÇOK ÖNEMLİ)

- Emre adım adım ilerler: bir şey yapar, test eder, "tamam" der, sonrakine geçilir. Aynı ritmi koru.
- Bir seferde **tek bir odak**. Aynı anda birçok dosyayı değiştirip kafasını karıştırma.
- Karmaşık/uzun dosyalarda parça parça düzenleme geçmişte sürekli **parantez kaymasına** yol açtı. Bu ortamda (Claude Code) dosyayı doğrudan sen düzenlediğin için bu risk azaldı — yine de her değişiklikten sonra dosyanın derlenebilir olduğundan emin ol.
- Büyük bir özelliğe başlamadan önce tasarım kararlarını netleştir (Emre'ye seçenek sun), sonra kodla.
- Değişikliklerden sonra Emre'ye **nasıl test edeceğini** açıkça söyle (hangi ekran, hangi düğme, ne görmeli).
- `git commit` yapmayı düzenli hatırlat (Emre bazen unutuyor). Commit mesajları kısa ve Türkçe/İngilizce sade olsun.

---

## Proje nedir

**Sözleşme Asistanı**: TİS uzmanının işini yöneten bir masaüstü + mobil uygulama.
- ~150 işyeriyle imzalı toplu iş sözleşmesi (TİS) kaydı tutuluyor.
- Her işyerinin dönemleri, sözleşme metni, ücret/sosyal hak tabloları, belgeleri, notları var.
- Gemini destekli bir "sözleşme asistanı" sözleşme metnine göre soru yanıtlıyor.
- Hukuki asistan modülü: yasa/mevzuat arşivi + yine Gemini destekli soru-cevap.
- Serbest "özel sayfalar": klasör ağacı + metin + tablo + dosya (kullanıcı kendi bölümlerini kuruyor).

## Teknoloji

- **Flutter** (Dart). Hedefler: **Windows (masaüstü)** ve **Android**. Windows ana platform, Android yeni eklendi.
- **Firebase**: Firestore (veri), Storage (dosyalar), Auth (giriş).
  - Aktif proje: `sendika-yazilimi` (hesap: sendikayazilimi@gmail.com), bölge europe-west1.
  - Org: `com.tumtis`.
- **Gemini API**: model `gemini-2.5-flash`, endpoint `generativelanguage.googleapis.com/v1beta`. Anahtar cihazda (shared_preferences) saklanır, buluta gitmez, her cihazda ayrı girilir.
- Proje yolu: `D:\EMRE\flutter_projeler\sozlesme_asistani`.

### Android derleme — kritik ortam notları
- **PubCache D: sürücüsünde olmalı.** Proje D:'de, ama pub cache varsayılan olarak C:'deydi ve "different roots" hatası veriyordu. `PUB_CACHE` ortam değişkeni `D:\PubCache` olarak ayarlandı. Buna dokunma.
- `android/gradle.properties` içinde `org.gradle.java.home` Android Studio'nun jbr'sini (Java 21) gösteriyor; `org.gradle.native=false` var. Bunlar Android derlemesinin çalışması için gerekli.
- Kotlin sürümü `settings.gradle`'da 2.1.0.
- Java 8 karışıklığı, bozuk Gradle önbelleği, `bad_record_mac` (ağ), "different roots" gibi hatalar geçmişte çıktı ve çözüldü. Android derleme sorunlarında önce bu notları hatırla.

## Paketler
firebase_core, cloud_firestore, firebase_storage, firebase_auth, file_picker (v11), url_launcher, syncfusion_flutter_pdfviewer, archive, shared_preferences, http, device_info_plus, path_provider.
- **share_plus YOK** (Windows'ta çökme yapıyordu).
- **excel paketi EKLENEMEDİ** (archive çakışması) → tüm "Excel'e aktar" işlemleri **CSV** ile yapılıyor (kendi UTF-8 kodlayıcı + BOM, ayırıcı `;`).

---

## Renk teması (AppRenk sınıfı, main.dart)
- indigo `0xFF6366F1` (ana renk)
- amber `0xFFF59E0B` (vurgu)
- emerald `0xFF10B981`
- arkaPlan `0xFFF8FAFC`

Modernleştirme yaparken bu temayı koru. Emre "modern, sade, karman çorman olmayan, profesyonel" bir görünüm istiyor.

## Güvenlik / giriş sistemi
- E-posta/şifre ile giriş (firebase_auth). `main.dart` içindeki `AuthKapisi` giriş + onay kontrolü yapıyor.
- **Onaya dayalı kayıt**: kişi kendi hesabını açar (`GirisEkrani` kayıt modu), ama onaysız → "Onay Bekleniyor" ekranı. Yönetici (Emre) Ayarlar > Kullanıcı Yönetimi'nden onaylar.
- `kullanicilar/{uid}` belgesi: `{eposta, onayli, yonetici, olusturma}`. Emre onayli=true, yonetici=true.
- Firestore & Storage kuralları **kilitli**: sadece giriş yapmış + onaylı kullanıcı erişebilir (`onayliMi()` fonksiyonu). "if true" dönemi bitti — kuralları gevşetme.

---

## Firestore veri modeli
- `isyerleri/{id}`: ad, anaKategori, altKategori, logoUrl, sube, calisanSayisi, uyeSayisi
  - `donemler/{id}`: donemNo, baslangic/bitisTarihi (Timestamp), baslangic/bitisYili (String), kategoriler[], maddeler[], pdfUrl, wordUrl; alt koleksiyon `ekBelgeler/`
  - `kisiler/`, `adresler/`, `gunluk/` (serbest etiketli notlar), `belgeAlani/kok`
- `ozelSayfalar/{id}`: ad, ikon, renk, sira; alt `klasorler/`, `kayitlar/`, `icerikler/{klasorId|'_kok'}`
- `hukuk/_ana/`: `klasorler/`, `yasalar/` (ad, no, klasorId, sira, maddeler[], duzMetin, pdfUrl, wordUrl)
- `ayarlar/asistan`: {tisSorulari:[...]} — asistan örnek soruları (global, Ayarlar'dan yönetilir)
- `kullanicilar/{uid}`: {eposta, onayli, yonetici, olusturma}

Önemli Firestore kuralları:
- İç içe dizi YASAK → tablo satırları `{'h':[...]}` map ile sarılır.
- Alt klasör kökte kimlik: `'_kok'` sabiti (null sorgu sorunu için).

## Önemli lib/ dosyaları
- `main.dart` — başlatma, AppRenk, AuthKapisi, tema
- `giris_ekrani.dart` — giriş + onaya dayalı kayıt
- `kullanici_servisi.dart` — kullanıcı onay/yönetici işlemleri
- `ana_kabuk.dart` — sol menü (İşyerleri / Güncel TİS'ler / Hukuki Asistan / özel sayfalar / Ayarlar)
- `isyeri_sayfasi.dart`, `isyeri_*_sekmesi.dart` — işyeri detayı (Genel/Detay/Belgeler/Notlar)
- `donem_detay_sayfasi.dart` + `donem_*_sekmesi.dart` — dönem detayı (Özet/Asistan/TİS Metni/Belgeler)
- `donem_bilgiler_sekmesi.dart` — ücret/sosyal hak yapısı (kategori/kalem/yıl, otomatik zam hesabı). **Hesap mantığına dokunurken çok dikkatli ol.**
- `donem_asistan_sekmesi.dart`, `yasa_detay_sayfasi.dart` — Gemini asistanları
- `ozel_sayfa_ekrani.dart` — klasör ağacı + metin + çoklu tablo + kayıtlar (EN KARMAŞIK dosya)
- `tablo_widget.dart` — kullanıcı tanımlı tablo (DataTable YERİNE Row/Container; Windows'ta DataTable çöküyor)
- `dosya_kaydet.dart` — platforma göre dosya kaydetme yardımcısı (Android: İndirilenler; Windows: kaydet penceresi). Tüm indirmeler bunu kullanır.
- `hukuki_asistan_ekrani.dart` — yasa arşivi

## Bilinen teknik kısıtlar
- **DataTable Windows'ta çöküyor** ("Lost connection to device") → tablolar elle Row/Container ile çiziliyor.
- Firestore iç içe dizi kabul etmiyor → `{'h':[...]}` sarma.
- Word okuma: `ZipDecoder` + `utf8.decode(dosya.content as List<int>)` (word/document.xml). `utf8Decode`/`Uint8List` DEĞİL.
- Yeni paket ekleyince Hot Restart yetmez, tam `flutter run` gerekir.

---

## Devam eden / bekleyen işler
- **Şu an aktif**: özel sayfa ekranını (`ozel_sayfa_ekrani.dart`) modernleştirme. Önce kayıt kartlarını akordeon + temiz başlık şeridine çevir (kapalı başlar, tıklayınca açılır). Tema indigo/amber kalsın. Adım adım: önce kayıt kartları, sonra klasörler/tablolar/üst başlık.
- Android'de başka ekranların telefonda düzeni (sıkışan yerler) gözden geçirilebilir.
- İleride (ihtiyaç doğdukça): sözleşme karşılaştırma, yenileme takvimi + uyarı, hesap makineleri (kıdem/ihbar/mesai), zam senaryosu.
- Inno Setup ile Windows kurulum dosyası (setup.exe) — ertelendi.

## Test alışkanlığı
Windows'ta: `flutter run -d windows`. Android'de: telefon USB ile bağlı, `flutter run`. Kod değişince Hot Restart (R), yeni paket/main.dart değişince tam restart.
