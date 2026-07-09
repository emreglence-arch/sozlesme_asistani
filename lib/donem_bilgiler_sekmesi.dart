import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'pdf_goruntuleyici.dart';
import 'donem_ek_belgeler.dart';

const Map<String, List<String>> presetKategoriler = {
  'ÜCRETLER': ['Ücret Zammı', 'İkramiye (Yıllık)', 'Promosyon'],
  'SOSYAL YARDIMLAR': [
    'Aile (Aylık)',
    'Yemek (Kart-Gün)',
    'Yakacak (Yıllık)',
    'Çocuk',
    'Evlenme',
    'Doğum',
    'Bayram (İki Bayram Toplam)',
  ],
  'EĞİTİM': ['Ana-İlk', 'Orta Okul', 'Lise', 'Üniversite'],
  'ÖLÜM': ['İşçi Vefat', 'İş Kazası', 'Eş/Çocuk', 'Anne/Baba'],
  'HARCIRAH': ['0-10 Saat', '10-18 Saat', '18 Saat +'],
  'DİĞER': ['Tabii Afet', 'Giyim Yardımı (Yıllık)'],
};

const Set<String> direktKategoriler = {'ÜCRETLER'};

class DonemBilgilerSekmesi extends StatefulWidget {
  final String isyeriId;
  final String donemId;

  const DonemBilgilerSekmesi({
    super.key,
    required this.isyeriId,
    required this.donemId,
  });

  @override
  State<DonemBilgilerSekmesi> createState() => _DonemBilgilerSekmesiState();
}

class _DonemBilgilerSekmesiState extends State<DonemBilgilerSekmesi> {
  String? _yukleniyor;
  int _seciliYil = 1;

  DocumentReference<Map<String, dynamic>> _donemRef() => FirebaseFirestore
      .instance
      .collection('isyerleri')
      .doc(widget.isyeriId)
      .collection('donemler')
      .doc(widget.donemId);

  String _depoYolu(String tur) =>
      'sozlesmeler/${widget.isyeriId}/${widget.donemId}/$tur';

  bool _direkt(Map<String, dynamic> kategori) {
    final ad = (kategori['ad'] ?? '').toString().toUpperCase();
    return kategori['tip'] == 'direkt' || direktKategoriler.contains(ad);
  }

  // ---------- BELGE YÜKLEME ----------
  Future<void> _yukle(String tur) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: tur == 'pdf' ? ['pdf'] : ['doc', 'docx'],
      withData: true,
    );
    if (result == null) return;
    final secilen = result.files.first;
    if (secilen.bytes == null) return;

    setState(() => _yukleniyor = tur);
    try {
      final ref = FirebaseStorage.instance.ref(_depoYolu(tur));
      String ct;
      if (tur == 'pdf') {
        ct = 'application/pdf';
      } else if (secilen.name.toLowerCase().endsWith('.doc')) {
        ct = 'application/msword';
      } else {
        ct =
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      }
      await ref.putData(secilen.bytes!, SettableMetadata(contentType: ct));
      final url = await ref.getDownloadURL();
      await _donemRef().update({'${tur}Url': url, '${tur}Ad': secilen.name});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Yükleme hatası: $e')));
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = null);
    }
  }

  Future<void> _indir(String tur, String? ad) async {
    final dosyaAdi = (ad == null || ad.isEmpty) ? 'belge' : ad;
    try {
      final yol = await FilePicker.saveFile(
        dialogTitle: 'Nereye kaydedilsin?',
        fileName: dosyaAdi,
      );
      if (yol == null) return;
      final bytes = await FirebaseStorage.instance
          .ref(_depoYolu(tur))
          .getData(200 * 1024 * 1024);
      if (bytes == null) throw 'Dosya okunamadı';
      await File(yol).writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('İndirildi: $dosyaAdi')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('İndirme hatası: $e')));
      }
    }
  }

  Future<void> _ac(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dosya açılamadı')));
      }
    }
  }

  Future<void> _belgeSil(String tur) async {
    final onay = await _onayDialog('Belgeyi sil', 'Bu belge silinsin mi?');
    if (onay != true) return;
    try {
      await FirebaseStorage.instance.ref(_depoYolu(tur)).delete();
    } catch (_) {}
    await _donemRef().update({
      '${tur}Url': FieldValue.delete(),
      '${tur}Ad': FieldValue.delete(),
    });
  }

  // ---------- YIL ----------
  int _yilSayisi(Map<String, dynamic> veri) {
    final b = int.tryParse((veri['baslangicYili'] ?? '').toString());
    final s = int.tryParse((veri['bitisYili'] ?? '').toString());
    if (b != null && s != null && s >= b) return (s - b + 1).clamp(1, 10);
    return 1;
  }

  String _yilEtiketi(Map<String, dynamic> veri, int i) {
    final b = int.tryParse((veri['baslangicYili'] ?? '').toString());
    if (b != null) return '$i. Yıl (${b + i - 1})';
    return '$i. Yıl';
  }

  // ---------- VERİ ----------
  List<Map<String, dynamic>> _kategoriler(Map<String, dynamic> veri) {
    final raw = veri['kategoriler'];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _kalemler(Map<String, dynamic> kategori) {
    final raw = kategori['kalemler'];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _kopya(List<Map<String, dynamic>> src) {
    return src.map((k) {
      final zamlar = (k['zamlar'] is Map)
          ? Map<String, dynamic>.from(k['zamlar'])
          : {};
      return {
        'ad': k['ad'] ?? '',
        'not': k['not'] ?? '',
        'tip': k['tip'] ?? 'zamli',
        'zamlar': Map<String, dynamic>.from(zamlar),
        'kalemler': _kalemler(k).map((x) {
          final ov = (x['overrides'] is Map)
              ? Map<String, dynamic>.from(x['overrides'])
              : {};
          return {
            'ad': x['ad'] ?? '',
            'yil1': x['yil1'] ?? '',
            'overrides': Map<String, dynamic>.from(ov),
          };
        }).toList(),
      };
    }).toList();
  }

  Future<void> _kaydet(List<Map<String, dynamic>> k) =>
      _donemRef().update({'kategoriler': k});

  // ---------- SAYI / HESAP ----------
  double? _sayi(String? raw) {
    if (raw == null) return null;
    var s = raw
        .trim()
        .replaceAll(RegExp('[Tt][Ll]'), '')
        .replaceAll('₺', '')
        .replaceAll('%', '')
        .trim();
    if (s.isEmpty) return null;
    if (!RegExp(r'^[0-9.,]+$').hasMatch(s)) return null;
    final nokta = s.contains('.');
    final virgul = s.contains(',');
    if (nokta && virgul) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (virgul) {
      s = s.replaceAll(',', '.');
    } else if (nokta) {
      if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
        s = s.replaceAll('.', '');
      }
    }
    return double.tryParse(s);
  }

  String _binlik(String tam) {
    final ters = tam.split('').reversed.toList();
    final buf = StringBuffer();
    for (var i = 0; i < ters.length; i++) {
      if (i > 0 && i % 3 == 0) buf.write('.');
      buf.write(ters[i]);
    }
    return buf.toString().split('').reversed.join();
  }

  String _bicim(double v) {
    final r = (v * 100).round() / 100;
    if (r == r.roundToDouble()) return _binlik(r.toInt().toString());
    final parts = r.toStringAsFixed(2).split('.');
    var dec = parts[1].replaceAll(RegExp(r'0+$'), '');
    return '${_binlik(parts[0])},$dec';
  }

  Map<String, dynamic> _hesapla(
    Map<String, dynamic> kalem,
    Map<String, dynamic> kategori,
    int yil,
  ) {
    final yil1 = (kalem['yil1'] ?? '').toString();
    if (yil <= 1) return {'metin': yil1, 'tur': 'baz'};

    final ov = (kalem['overrides'] is Map)
        ? Map<String, dynamic>.from(kalem['overrides'])
        : {};
    final elle = (ov['$yil'] ?? '').toString().trim();
    if (elle.isNotEmpty) return {'metin': elle, 'tur': 'elle'};

    final zamlar = (kategori['zamlar'] is Map)
        ? Map<String, dynamic>.from(kategori['zamlar'])
        : {};
    final kural = (zamlar['$yil'] ?? '').toString().trim();

    final onceki = _hesapla(kalem, kategori, yil - 1);
    final oncekiSayi = _sayi(onceki['metin']?.toString());
    final oran = _sayi(kural);

    if (oncekiSayi != null && oran != null) {
      final sonuc = oncekiSayi * (1 + oran / 100);
      return {
        'metin': _bicim(sonuc),
        'tur': 'hesap',
        'kural': kural,
        'baz': yil1,
      };
    }
    return {'metin': '', 'tur': 'yok', 'kural': kural, 'baz': yil1};
  }

  // ---------- DİYALOGLAR ----------
  Future<bool?> _onayDialog(String baslik, String metin) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(baslik),
        content: Text(metin),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Future<String?> _metinDialog(
    String baslik,
    String etiket, {
    String baslangic = '',
    String ipucu = '',
  }) {
    final c = TextEditingController(text: baslangic);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(baslik),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(labelText: etiket, hintText: ipucu),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>?> _kalemDialog({
    required int yil,
    Map<String, dynamic>? mevcut,
    String otomatik = '',
    bool direkt = false,
  }) {
    final adC = TextEditingController(text: mevcut?['ad']?.toString() ?? '');
    String basDeger;
    if (yil <= 1) {
      basDeger = mevcut?['yil1']?.toString() ?? '';
    } else {
      final ov = (mevcut?['overrides'] is Map)
          ? Map<String, dynamic>.from(mevcut!['overrides'])
          : {};
      basDeger = (ov['$yil'] ?? '').toString();
    }
    final degerC = TextEditingController(text: basDeger);

    String etiket;
    String ipucu;
    if (yil <= 1) {
      etiket = '1. Yıl değeri';
      ipucu = 'Örn. 8.500 TL veya %30';
    } else if (direkt) {
      etiket = '$yil. Yıl değeri';
      ipucu = 'Örn. %35';
    } else {
      etiket = '$yil. Yıl değeri (boş = otomatik)';
      ipucu = otomatik.isNotEmpty
          ? 'Otomatik: $otomatik'
          : 'Elle bir değer yaz';
    }

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(mevcut == null ? 'Kalem Ekle' : 'Kalem Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: adC,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Kalem adı',
                hintText: 'Örn. Yakacak (Yıllık)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: degerC,
              decoration: InputDecoration(labelText: etiket, hintText: ipucu),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'ad': adC.text.trim(),
              'deger': degerC.text.trim(),
            }),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // ---------- İŞLEMLER ----------
  Future<void> _presetKategoriEkle(
    List<Map<String, dynamic>> mevcut,
    String ad,
  ) async {
    final kalemler = (presetKategoriler[ad] ?? [])
        .map((k) => {'ad': k, 'yil1': '', 'overrides': {}})
        .toList();
    final yeni = _kopya(mevcut)
      ..add({
        'ad': ad,
        'not': '',
        'tip': direktKategoriler.contains(ad) ? 'direkt' : 'zamli',
        'zamlar': {},
        'kalemler': kalemler,
      });
    await _kaydet(yeni);
  }

  Future<void> _yeniKategoriEkle(List<Map<String, dynamic>> mevcut) async {
    final ad = await _metinDialog(
      'Yeni Kategori',
      'Kategori adı',
      ipucu: 'Örn. PRİM',
    );
    if (ad == null || ad.isEmpty) return;
    final yeni = _kopya(
      mevcut,
    )..add({'ad': ad, 'not': '', 'tip': 'zamli', 'zamlar': {}, 'kalemler': []});
    await _kaydet(yeni);
  }

  Future<void> _kategoriSil(List<Map<String, dynamic>> mevcut, int i) async {
    final onay = await _onayDialog(
      'Kategoriyi sil',
      'Bu kategori ve tüm kalemleri silinsin mi?',
    );
    if (onay != true) return;
    final yeni = _kopya(mevcut)..removeAt(i);
    await _kaydet(yeni);
  }

  Future<void> _kategoriNot(List<Map<String, dynamic>> mevcut, int i) async {
    final not = await _metinDialog(
      'Not',
      'Kategori notu',
      baslangic: mevcut[i]['not']?.toString() ?? '',
      ipucu: 'Örn. 2027 için TÜFE+ÜFE/2',
    );
    if (not == null) return;
    final yeni = _kopya(mevcut);
    yeni[i]['not'] = not;
    await _kaydet(yeni);
  }

  Future<void> _zamKurali(
    List<Map<String, dynamic>> mevcut,
    int i,
    int yil,
  ) async {
    final zamlar = (mevcut[i]['zamlar'] is Map)
        ? Map<String, dynamic>.from(mevcut[i]['zamlar'])
        : {};
    final kural = await _metinDialog(
      '$yil. Yıl Zammı',
      'Zam oranı / kuralı',
      baslangic: (zamlar['$yil'] ?? '').toString(),
      ipucu: 'Örn. 40  ya da  (TÜFE+ÜFE)/2',
    );
    if (kural == null) return;
    final yeni = _kopya(mevcut);
    (yeni[i]['zamlar'] as Map)['$yil'] = kural;
    await _kaydet(yeni);
  }

  Future<void> _kalemEkle(List<Map<String, dynamic>> mevcut, int kat) async {
    final direkt = _direkt(mevcut[kat]);
    final sonuc = await _kalemDialog(yil: 1, direkt: direkt);
    if (sonuc == null || sonuc['ad']!.isEmpty) return;
    final yeni = _kopya(mevcut);
    (yeni[kat]['kalemler'] as List).add({
      'ad': sonuc['ad'],
      'yil1': sonuc['deger'],
      'overrides': {},
    });
    await _kaydet(yeni);
  }

  Future<void> _kalemDuzenle(
    List<Map<String, dynamic>> mevcut,
    int kat,
    int idx,
    int yil,
    String otomatik,
    bool direkt,
  ) async {
    final kalemler = _kalemler(mevcut[kat]);
    final sonuc = await _kalemDialog(
      yil: yil,
      mevcut: kalemler[idx],
      otomatik: otomatik,
      direkt: direkt,
    );
    if (sonuc == null || sonuc['ad']!.isEmpty) return;
    final yeni = _kopya(mevcut);
    final k = (yeni[kat]['kalemler'] as List)[idx] as Map;
    k['ad'] = sonuc['ad'];
    if (yil <= 1) {
      k['yil1'] = sonuc['deger'];
    } else {
      (k['overrides'] as Map)['$yil'] = sonuc['deger'];
    }
    await _kaydet(yeni);
  }

  Future<void> _kalemSil(
    List<Map<String, dynamic>> mevcut,
    int kat,
    int idx,
  ) async {
    final yeni = _kopya(mevcut);
    (yeni[kat]['kalemler'] as List).removeAt(idx);
    await _kaydet(yeni);
  }

  // ---------- EKRAN ----------
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _donemRef().snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final veri = snapshot.data!.data() ?? {};
        final kategoriler = _kategoriler(veri);
        final yilSayisi = _yilSayisi(veri);
        final seciliYil = _seciliYil.clamp(1, yilSayisi);
        final eklenenAdlar = kategoriler.map((k) => k['ad'] as String).toSet();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Belgeler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _belgeKarti(
              tur: 'pdf',
              baslik: 'İmzalı Sözleşme',
              ikon: Icons.picture_as_pdf,
              renk: Colors.red,
              url: veri['pdfUrl'] as String?,
              ad: veri['pdfAd'] as String?,
            ),
            const SizedBox(height: 12),
            _belgeKarti(
              tur: 'word',
              baslik: 'TİS Word Belgesi',
              ikon: Icons.description,
              renk: Colors.blue,
              url: veri['wordUrl'] as String?,
              ad: veri['wordAd'] as String?,
            ),
            const SizedBox(height: 28),
            DonemEkBelgeler(isyeriId: widget.isyeriId, donemId: widget.donemId),
            const SizedBox(height: 28),
            const Text(
              'Sözleşme Bilgileri',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (yilSayisi > 1)
              Wrap(
                spacing: 8,
                children: List.generate(yilSayisi, (i) {
                  final yil = i + 1;
                  return ChoiceChip(
                    label: Text(_yilEtiketi(veri, yil)),
                    selected: seciliYil == yil,
                    selectedColor: AppRenk.indigo,
                    labelStyle: TextStyle(
                      color: seciliYil == yil ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _seciliYil = yil),
                  );
                }),
              ),
            const SizedBox(height: 14),
            ...List.generate(
              kategoriler.length,
              (i) => _kategoriKarti(veri, kategoriler, i, seciliYil),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ad in presetKategoriler.keys)
                  if (!eklenenAdlar.contains(ad))
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: Text(ad),
                      onPressed: () => _presetKategoriEkle(kategoriler, ad),
                    ),
                ActionChip(
                  avatar: const Icon(Icons.create, size: 16),
                  label: const Text('Yeni Kategori'),
                  backgroundColor: AppRenk.indigo.withOpacity(0.1),
                  onPressed: () => _yeniKategoriEkle(kategoriler),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _kategoriKarti(
    Map<String, dynamic> veri,
    List<Map<String, dynamic>> kategoriler,
    int i,
    int yil,
  ) {
    final kategori = kategoriler[i];
    final ad = kategori['ad'] as String;
    final not = (kategori['not'] ?? '').toString();
    final kalemler = _kalemler(kategori);
    final direkt = _direkt(kategori);
    final zamlar = (kategori['zamlar'] is Map)
        ? Map<String, dynamic>.from(kategori['zamlar'])
        : {};
    final kural = (zamlar['$yil'] ?? '').toString();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ad,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppRenk.indigo,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (d) {
                    if (d == 'kalem') _kalemEkle(kategoriler, i);
                    if (d == 'not') _kategoriNot(kategoriler, i);
                    if (d == 'sil') _kategoriSil(kategoriler, i);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'kalem', child: Text('Kalem ekle')),
                    PopupMenuItem(value: 'not', child: Text('Not düzenle')),
                    PopupMenuItem(value: 'sil', child: Text('Kategoriyi sil')),
                  ],
                ),
              ],
            ),
            if (not.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 15,
                      color: AppRenk.amber,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        not,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (yil > 1 && !direkt)
              InkWell(
                onTap: () => _zamKurali(kategoriler, i, yil),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppRenk.emerald.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.trending_up,
                        size: 17,
                        color: AppRenk.emerald,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$yil. Yıl Zammı: ',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          kural.isEmpty ? 'belirtilmedi (dokun)' : kural,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kural.isEmpty
                                ? Colors.grey
                                : AppRenk.emerald,
                          ),
                        ),
                      ),
                      const Icon(Icons.edit, size: 15, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            const Divider(height: 16),
            if (kalemler.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Kalem yok — menüden "Kalem ekle" ile ekle',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              )
            else
              ...List.generate(
                kalemler.length,
                (k) => _kalemSatiri(kategoriler, i, k, yil, direkt),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kalemSatiri(
    List<Map<String, dynamic>> kategoriler,
    int kat,
    int idx,
    int yil,
    bool direkt,
  ) {
    final kategori = kategoriler[kat];
    final kalem = _kalemler(kategori)[idx];
    final kalemAd = (kalem['ad'] ?? '').toString();

    Widget deger;
    String otomatikIpucu = '';

    if (yil <= 1) {
      final v = (kalem['yil1'] ?? '').toString();
      deger = Text(
        v.isEmpty ? '—' : v,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppRenk.amber,
        ),
      );
    } else if (direkt) {
      final ov = (kalem['overrides'] is Map)
          ? Map<String, dynamic>.from(kalem['overrides'])
          : {};
      final v = (ov['$yil'] ?? '').toString();
      deger = Text(
        v.isEmpty ? '—' : v,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppRenk.amber,
        ),
      );
    } else {
      final hesap = _hesapla(kalem, kategori, yil);
      if (hesap['tur'] == 'elle') {
        deger = Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              hesap['metin'],
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppRenk.amber,
              ),
            ),
            _etiket('elle', Colors.grey),
          ],
        );
      } else if (hesap['tur'] == 'hesap') {
        otomatikIpucu = hesap['metin'];
        deger = Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${hesap['baz']}',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade500,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
            Text(
              hesap['metin'],
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppRenk.amber,
              ),
            ),
            _etiket('%${hesap['kural']}', AppRenk.emerald),
          ],
        );
      } else {
        final kural = (hesap['kural'] ?? '').toString();
        final baz = (hesap['baz'] ?? '').toString();
        deger = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              baz.isEmpty ? '—' : '1. yıl: $baz',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            if (kural.isNotEmpty)
              Text(
                '$kural oranında zamlanacak',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppRenk.amber,
                ),
              ),
          ],
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kalemAd,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                deger,
              ],
            ),
          ),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
            onSelected: (d) {
              if (d == 'duzenle') {
                _kalemDuzenle(
                  kategoriler,
                  kat,
                  idx,
                  yil,
                  otomatikIpucu,
                  direkt,
                );
              }
              if (d == 'sil') _kalemSil(kategoriler, kat, idx);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
              PopupMenuItem(value: 'sil', child: Text('Sil')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _etiket(String metin, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        metin,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: renk,
        ),
      ),
    );
  }

  Widget _belgeKarti({
    required String tur,
    required String baslik,
    required IconData ikon,
    required Color renk,
    required String? url,
    required String? ad,
  }) {
    final buYukleniyor = _yukleniyor == tur;
    final varMi = url != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(ikon, color: renk, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baslik,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    varMi ? (ad ?? 'Yüklendi') : 'Henüz yüklenmedi',
                    style: TextStyle(
                      fontSize: 13,
                      color: varMi ? AppRenk.emerald : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (buYukleniyor)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (varMi)
              Row(
                children: [
                  IconButton(
                    tooltip: 'Aç',
                    icon: const Icon(Icons.open_in_new, color: AppRenk.indigo),
                    onPressed: () => _ac(url),
                  ),
                  IconButton(
                    tooltip: 'İndir',
                    icon: const Icon(Icons.download, color: AppRenk.emerald),
                    onPressed: () => _indir(tur, ad),
                  ),
                  IconButton(
                    tooltip: 'Değiştir',
                    icon: const Icon(Icons.refresh, color: AppRenk.amber),
                    onPressed: () => _yukle(tur),
                  ),
                  IconButton(
                    tooltip: 'Sil',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _belgeSil(tur),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: () => _yukle(tur),
                style: FilledButton.styleFrom(backgroundColor: AppRenk.indigo),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Yükle'),
              ),
          ],
        ),
      ),
    );
  }
}
