import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'dosya_kaydet.dart';
import 'excel_yazici.dart';
import 'izgara_tablo.dart';
import 'renk_secici.dart';

const Map<String, List<String>> presetKategoriler = {
  'ÜCRETLER': ['Ücret Zammı', 'İkramiye (Yıllık)', 'Promosyon'],
  'SOSYAL HAK VE YARDIMLAR': [
    'Aile',
    'Yemek',
    'Yakacak',
    'Evlenme',
    'Doğum',
    'Ramazan Bayramı',
    'Kurban Bayramı',
  ],
  'EĞİTİM YARDIMLARI': ['Ana-İlk Okul', 'Orta Okul', 'Lise', 'Üniversite'],
  'ÖLÜM': ['İşçi Vefat', 'İş Kazası', 'Eş/Çocuk', 'Anne/Baba'],
  'HARCIRAH': [],
  'DİĞER': [],
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
  DocumentReference<Map<String, dynamic>> _donemRef() => FirebaseFirestore
      .instance
      .collection('isyerleri')
      .doc(widget.isyeriId)
      .collection('donemler')
      .doc(widget.donemId);

  bool _direkt(Map<String, dynamic> kategori) {
    final ad = (kategori['ad'] ?? '').toString().toUpperCase();
    return kategori['tip'] == 'direkt' || direktKategoriler.contains(ad);
  }

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

  // ---------- DÖNEM SÜTUNLARI ----------
  /// Sütunlar. Belgede 'donemler' yoksa yıllardan üretilir ve kimlikler eski
  /// yıl numaralarıyla ('1', '2', ...) aynı olur; böylece mevcut sözleşmeler
  /// hiçbir dönüştürme gerekmeden aynen açılır.
  List<Map<String, String>> _donemler(Map<String, dynamic> veri) {
    final raw = veri['donemler'];
    if (raw is List && raw.isNotEmpty) {
      final liste = raw
          .map<Map<String, String>>((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return {
              'id': (m['id'] ?? '').toString(),
              'ad': (m['ad'] ?? '').toString(),
            };
          })
          .where((d) => d['id']!.isNotEmpty)
          .toList();
      if (liste.isNotEmpty) return liste;
    }
    final n = _yilSayisi(veri);
    return [
      for (var i = 1; i <= n; i++) {'id': '$i', 'ad': _yilEtiketi(veri, i)},
    ];
  }

  Future<void> _donemleriKaydet(List<Map<String, String>> donemler) =>
      _donemRef().update({'donemler': donemler});

  /// Dönem listesi ile kategorileri **tek işlemde** yazar.
  /// Dönem ekleme/silme sırasında taban değerler taşındığı için bu iki
  /// yazmanın ayrılması veri kaybına yol açabilir; bu yüzden birlikte gider.
  Future<void> _donemVeKategoriKaydet(
    List<Map<String, String>> donemler,
    List<Map<String, dynamic>> kategoriler,
  ) => _donemRef().update({
    'donemler': donemler,
    'kategoriler': kategoriler,
  });

  /// Yeni dönem için benzersiz kimlik.
  String _yeniDonemId() => 'd${DateTime.now().microsecondsSinceEpoch}';

  /// Bir kalemin ilk dönemdeki (taban) değeri.
  /// Eski sözleşmelerde taban 'yil1' alanındadır.
  String _tabanDeger(
    Map<String, dynamic> kalem,
    List<Map<String, String>> donemler,
  ) {
    if (donemler.isNotEmpty) {
      final ov = (kalem['overrides'] is Map)
          ? Map<String, dynamic>.from(kalem['overrides'])
          : {};
      final v = (ov[donemler.first['id']] ?? '').toString();
      if (v.isNotEmpty) return v;
    }
    return (kalem['yil1'] ?? '').toString();
  }

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
        'renk': k['renk'] ?? '',
        'zamlar': Map<String, dynamic>.from(zamlar),
        'kalemler': _kalemler(k).map((x) {
          final ov = (x['overrides'] is Map)
              ? Map<String, dynamic>.from(x['overrides'])
              : {};
          return {
            'ad': x['ad'] ?? '',
            'yil1': x['yil1'] ?? '',
            'not': x['not'] ?? '',
            'renk': x['renk'] ?? '',
            'tur': x['tur'] ?? 'kalem',
            'overrides': Map<String, dynamic>.from(ov),
          };
        }).toList(),
      };
    }).toList();
  }

  Future<void> _kaydet(List<Map<String, dynamic>> k) =>
      _donemRef().update({'kategoriler': k});

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

  /// Bir kalemin belirtilen dönemdeki değerini hesaplar.
  ///
  /// İlk dönem tabandır. Sonraki her dönem **bir önceki dönemin** üzerine
  /// zamlanır (bileşik). Elle girilmiş bir değer varsa zincir orada kesilir.
  /// Dönemler eskiden yıl numarasıydı; kimlikler aynı kaldığı için eski
  /// sözleşmelerde sonuç birebir aynıdır.
  Map<String, dynamic> _hesapla(
    Map<String, dynamic> kalem,
    Map<String, dynamic> kategori,
    List<Map<String, String>> donemler,
    int index,
  ) {
    if (index <= 0 || donemler.isEmpty) {
      return {'metin': _tabanDeger(kalem, donemler), 'tur': 'baz'};
    }

    final id = donemler[index]['id']!;

    final ov = (kalem['overrides'] is Map)
        ? Map<String, dynamic>.from(kalem['overrides'])
        : {};
    final elle = (ov[id] ?? '').toString().trim();
    if (elle.isNotEmpty) return {'metin': elle, 'tur': 'elle'};

    final zamlar = (kategori['zamlar'] is Map)
        ? Map<String, dynamic>.from(kategori['zamlar'])
        : {};
    final kural = (zamlar[id] ?? '').toString().trim();

    final onceki = _hesapla(kalem, kategori, donemler, index - 1);
    final oncekiMetin = (onceki['metin'] ?? '').toString();
    final oncekiSayi = _sayi(oncekiMetin);
    final oran = _sayi(kural);

    if (oncekiSayi != null && oran != null) {
      final sonuc = oncekiSayi * (1 + oran / 100);
      return {
        'metin': _bicim(sonuc),
        'tur': 'hesap',
        'kural': kural,
        'baz': oncekiMetin,
      };
    }
    return {'metin': '', 'tur': 'yok', 'kural': kural, 'baz': oncekiMetin};
  }

  // ---------- EXCEL (.xlsx) ----------
  /// Ekrandaki ızgaranın aynısını biçimli bir Excel dosyası olarak yazar.
  Future<void> _exceleAktar(Map<String, dynamic> veri) async {
    final kategoriler = _kategoriler(veri);
    if (kategoriler.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Aktarılacak veri yok')));
      return;
    }
    final donemler = _donemler(veri);
    final sutunSayisi = 1 + donemler.length;

    final satirlar = <List<XlsxHucre?>>[
      [
        const XlsxHucre(deger: 'Kalem', kalin: true, arkaPlan: 'E8EAF6'),
        for (final d in donemler)
          XlsxHucre(
            deger: d['ad']!,
            kalin: true,
            hizalama: 'orta',
            arkaPlan: 'E8EAF6',
          ),
      ],
    ];

    for (final kategori in kategoriler) {
      final ad = (kategori['ad'] ?? '').toString();
      final direkt = _direkt(kategori);
      final zamlar = (kategori['zamlar'] is Map)
          ? Map<String, dynamic>.from(kategori['zamlar'])
          : {};
      final katRenk = renkHex((kategori['renk'] ?? '').toString()) ?? 'C5CAE9';

      // Kategori başlığı: tüm genişliği kaplar
      satirlar.add([
        XlsxHucre(
          deger: ad,
          kalin: true,
          arkaPlan: katRenk,
          sutunKapla: sutunSayisi,
        ),
        for (var i = 1; i < sutunSayisi; i++) null,
      ]);

      // Zam oranı satırı
      if (!direkt && donemler.length > 1) {
        satirlar.add([
          const XlsxHucre(deger: 'Zam Oranı', italik: true),
          for (var i = 0; i < donemler.length; i++)
            XlsxHucre(
              deger: i == 0
                  ? '-'
                  : _zamMetni(
                      (zamlar[donemler[i]['id']] ?? '').toString().trim(),
                    ),
              hizalama: 'orta',
              italik: true,
            ),
        ]);
      }

      for (final kalem in _kalemler(kategori)) {
        final kalemRenk = renkHex((kalem['renk'] ?? '').toString());
        // Serbest satır: tüm genişliği kaplayan açıklama satırı
        if ((kalem['tur'] ?? 'kalem').toString() == 'serbest') {
          satirlar.add([
            XlsxHucre(
              deger: (kalem['ad'] ?? '').toString(),
              italik: true,
              arkaPlan: kalemRenk,
              sutunKapla: sutunSayisi,
            ),
            for (var i = 1; i < sutunSayisi; i++) null,
          ]);
          continue;
        }
        satirlar.add([
          XlsxHucre(deger: (kalem['ad'] ?? '').toString(), arkaPlan: kalemRenk),
          for (var i = 0; i < donemler.length; i++)
            XlsxHucre(
              deger: _degerMetni(kalem, kategori, donemler, i, direkt),
              hizalama: 'sag',
              kalin: true,
              arkaPlan: kalemRenk,
            ),
        ]);
      }

      // Kategori notu varsa alta tam genişlik satır
      final not = (kategori['not'] ?? '').toString();
      if (not.isNotEmpty) {
        satirlar.add([
          XlsxHucre(deger: not, italik: true, sutunKapla: sutunSayisi),
          for (var i = 1; i < sutunSayisi; i++) null,
        ]);
      }
    }

    final bytes = xlsxUret(
      sayfaAdi: 'Sözleşme Özeti',
      sutunGenislikleri: [
        for (var c = 0; c < sutunSayisi; c++) _sutunGenislik(veri, c),
      ],
      satirYukseklikleri: List.filled(satirlar.length, 38),
      satirlar: satirlar,
    );

    if (!mounted) return;
    await dosyaKaydet(
      context: context,
      bytes: bytes,
      dosyaAdi: 'sozlesme_ozeti.xlsx',
      dialogBaslik: 'Excel dosyasını kaydet',
    );
  }

  /// Zam kuralını gösterilecek metne çevirir (sayıysa başına % koyar).
  String _zamMetni(String kural) {
    if (kural.isEmpty) return '';
    return _sayi(kural) != null ? '%$kural' : kural;
  }

  /// Bir kalemin belirtilen yıldaki değerini metin olarak verir.
  String _degerMetni(
    Map<String, dynamic> kalem,
    Map<String, dynamic> kategori,
    List<Map<String, String>> donemler,
    int index,
    bool direkt,
  ) {
    if (index <= 0) return _tabanDeger(kalem, donemler);
    if (direkt) {
      final ov = (kalem['overrides'] is Map)
          ? Map<String, dynamic>.from(kalem['overrides'])
          : {};
      return (ov[donemler[index]['id']] ?? '').toString();
    }
    return (_hesapla(kalem, kategori, donemler, index)['metin'] ?? '')
        .toString();
  }


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
    required List<Map<String, String>> donemler,
    required int donemIndex,
    Map<String, dynamic>? mevcut,
    String otomatik = '',
    bool direkt = false,
  }) {
    final adC = TextEditingController(text: mevcut?['ad']?.toString() ?? '');
    final notC = TextEditingController(text: mevcut?['not']?.toString() ?? '');
    final donemAd = (donemIndex >= 0 && donemIndex < donemler.length)
        ? donemler[donemIndex]['ad']!
        : '';

    String basDeger;
    if (donemIndex <= 0) {
      basDeger = mevcut == null ? '' : _tabanDeger(mevcut, donemler);
    } else {
      final ov = (mevcut?['overrides'] is Map)
          ? Map<String, dynamic>.from(mevcut!['overrides'])
          : {};
      basDeger = (ov[donemler[donemIndex]['id']] ?? '').toString();
    }
    final degerC = TextEditingController(text: basDeger);

    String etiket;
    String ipucu;
    if (donemIndex <= 0) {
      etiket = '$donemAd değeri (taban)';
      ipucu = 'Örn. 8.500 TL veya %30';
    } else if (direkt) {
      etiket = '$donemAd değeri';
      ipucu = 'Örn. %35';
    } else {
      etiket = '$donemAd değeri (boş = otomatik)';
      ipucu = otomatik.isNotEmpty
          ? 'Otomatik: $otomatik'
          : 'Elle bir değer yaz';
    }

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(mevcut == null ? 'Kalem Ekle' : 'Kalem Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: adC,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Kalem adı',
                  hintText: 'Örn. Yakacak',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: degerC,
                decoration: InputDecoration(labelText: etiket, hintText: ipucu),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notC,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Not (opsiyonel)',
                  hintText: 'Örn. aylık, evli çalışana; çocuk başına',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
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
              'not': notC.text.trim(),
            }),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _presetKategoriEkle(
    List<Map<String, dynamic>> mevcut,
    String ad,
  ) async {
    final kalemler = (presetKategoriler[ad] ?? [])
        .map(
          (k) => {
            'ad': k,
            'yil1': '',
            'not': '',
            'renk': '',
            'tur': 'kalem',
            'overrides': {},
          },
        )
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

  // Zam kuralı artık ızgarada "Yıllık Zam Oranı" hücresine tıklanarak girilir.

  Future<void> _kalemEkle(List<Map<String, dynamic>> mevcut, int kat) async {
    final direkt = _direkt(mevcut[kat]);
    final donemler = _sonDonemler;
    final sonuc = await _kalemDialog(
      donemler: donemler,
      donemIndex: 0,
      direkt: direkt,
    );
    if (sonuc == null || sonuc['ad']!.isEmpty) return;
    final yeni = _kopya(mevcut);
    final overrides = <String, dynamic>{};
    if (donemler.isNotEmpty && sonuc['deger']!.isNotEmpty) {
      overrides[donemler.first['id']!] = sonuc['deger'];
    }
    (yeni[kat]['kalemler'] as List).add({
      'ad': sonuc['ad'],
      'yil1': sonuc['deger'],
      'not': sonuc['not'],
      'renk': '',
      'tur': 'kalem',
      'overrides': overrides,
    });
    await _kaydet(yeni);
  }

  Future<void> _kalemDuzenle(
    List<Map<String, dynamic>> mevcut,
    int kat,
    int idx,
    List<Map<String, String>> donemler,
    int donemIndex,
    String otomatik,
    bool direkt,
  ) async {
    final kalemler = _kalemler(mevcut[kat]);
    final sonuc = await _kalemDialog(
      donemler: donemler,
      donemIndex: donemIndex,
      mevcut: kalemler[idx],
      otomatik: otomatik,
      direkt: direkt,
    );
    if (sonuc == null || sonuc['ad']!.isEmpty) return;
    final yeni = _kopya(mevcut);
    final k = (yeni[kat]['kalemler'] as List)[idx] as Map;
    k['ad'] = sonuc['ad'];
    k['not'] = sonuc['not'];

    final deger = sonuc['deger'] ?? '';
    if (donemler.isEmpty) {
      k['yil1'] = deger;
    } else {
      final id = donemler[donemIndex.clamp(0, donemler.length - 1)]['id']!;
      final ov = k['overrides'] as Map;
      if (deger.isEmpty) {
        ov.remove(id);
      } else {
        ov[id] = deger;
      }
      // İlk dönem taban olduğu için eski alanla da eşitlenir
      if (donemIndex <= 0) k['yil1'] = deger;
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

  Future<void> _kalemNotGoster(String ad, String not) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ad),
        content: Text(not, style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  // ---------- DÜZENLEME DURUMU ----------
  // Hücreye tıklayıp yazma: anahtar 'tur:kategori:kalem:donemId' biçiminde.
  String? _duzAnahtar;
  final TextEditingController _duzC = TextEditingController();
  final FocusNode _duzOdak = FocusNode();
  bool _tumDonemler = true;
  int _seciliDonem = 0;

  /// Akıştan gelen en son veriler (düzenleme kaydederken kullanılır).
  List<Map<String, dynamic>> _sonKategoriler = [];
  List<Map<String, String>> _sonDonemler = [];

  @override
  void initState() {
    super.initState();
    _duzOdak.addListener(() {
      if (!_duzOdak.hasFocus && _duzAnahtar != null) _duzKaydet();
    });
  }

  @override
  void dispose() {
    _duzC.dispose();
    _duzOdak.dispose();
    super.dispose();
  }

  void _duzBaslat(String anahtar, String baslangic) {
    setState(() {
      _duzAnahtar = anahtar;
      _duzC.text = baslangic;
      _duzC.selection = TextSelection(
        baseOffset: 0,
        extentOffset: baslangic.length,
      );
    });
    _duzOdak.requestFocus();
  }

  Future<void> _duzKaydet() async {
    final anahtar = _duzAnahtar;
    if (anahtar == null) return;
    final metin = _duzC.text.trim();
    setState(() => _duzAnahtar = null);

    final p = anahtar.split(':');
    if (p.length != 4) return;
    final tur = p[0];
    final kat = int.tryParse(p[1]) ?? -1;
    final idx = int.tryParse(p[2]) ?? -1;
    final donemId = p[3];

    // Dönem başlığı kategori listesinden bağımsız
    if (tur == 'donemAd') {
      if (metin.isEmpty) return;
      final liste = _sonDonemler
          .map((d) => {'id': d['id']!, 'ad': d['ad']!})
          .toList();
      final yeri = liste.indexWhere((d) => d['id'] == donemId);
      if (yeri < 0) return;
      liste[yeri]['ad'] = metin;
      await _donemleriKaydet(liste);
      return;
    }

    final mevcut = _sonKategoriler;
    if (kat < 0 || kat >= mevcut.length) return;
    final yeni = _kopya(mevcut);
    final kalemler = yeni[kat]['kalemler'] as List;

    switch (tur) {
      case 'kategoriAd':
        if (metin.isEmpty) return;
        yeni[kat]['ad'] = metin;
      case 'kalemAd':
        if (idx < 0 || idx >= kalemler.length || metin.isEmpty) return;
        (kalemler[idx] as Map)['ad'] = metin;
      case 'zam':
        (yeni[kat]['zamlar'] as Map)[donemId] = metin;
      case 'deger':
        if (idx < 0 || idx >= kalemler.length) return;
        final k = kalemler[idx] as Map;
        final ov = k['overrides'] as Map;
        final ilkDonem =
            _sonDonemler.isNotEmpty && _sonDonemler.first['id'] == donemId;
        if (ilkDonem) {
          // Taban değer: hem yeni hem eski alana yazılır
          k['yil1'] = metin;
          if (metin.isEmpty) {
            ov.remove(donemId);
          } else {
            ov[donemId] = metin;
          }
        } else {
          // Boş bırakmak = otomatik hesaba dön
          if (metin.isEmpty) {
            ov.remove(donemId);
          } else {
            ov[donemId] = metin;
          }
        }
      default:
        return;
    }
    await _kaydet(yeni);
  }

  // ---------- DÖNEM YÖNETİMİ ----------
  /// Belirtilen konuma yeni dönem ekler.
  /// Başa eklenirken taban değerler eski ilk döneme taşınır ki
  /// hesap zinciri bozulmasın.
  Future<void> _donemEkle(
    Map<String, dynamic> veri,
    List<Map<String, String>> donemler,
    int konum,
  ) async {
    final ad = await _metinDialog(
      'Yeni Dönem',
      'Dönem adı',
      ipucu: 'Örn. 01.06.2026 - 31.12.2026',
    );
    if (ad == null || ad.isEmpty) return;

    final liste = donemler.map((d) => {'id': d['id']!, 'ad': d['ad']!}).toList();
    final yeniId = _yeniDonemId();
    final yer = konum.clamp(0, liste.length);

    if (yer == 0 && liste.isNotEmpty) {
      // Yeni dönem taban oluyor; eski taban değerler eski ilk döneme taşınır
      // ki hesap zinciri bozulmasın.
      final eskiIlkId = liste.first['id']!;
      final kategoriler = _kopya(_sonKategoriler);
      for (final kategori in kategoriler) {
        for (final kalem in (kategori['kalemler'] as List)) {
          final k = kalem as Map;
          final taban = _tabanDeger(
            Map<String, dynamic>.from(k),
            donemler,
          );
          if (taban.isNotEmpty) {
            (k['overrides'] as Map)[eskiIlkId] = taban;
          }
          k['yil1'] = '';
        }
      }
      liste.insert(yer, {'id': yeniId, 'ad': ad});
      await _donemVeKategoriKaydet(liste, kategoriler);
      return;
    }

    liste.insert(yer, {'id': yeniId, 'ad': ad});
    await _donemleriKaydet(liste);
  }

  Future<void> _donemSil(
    List<Map<String, String>> donemler,
    int index,
  ) async {
    if (donemler.length <= 1) {
      _uyari('Son dönem silinemez');
      return;
    }
    final onay = await _onayDialog(
      'Dönemi sil',
      '"${donemler[index]['ad']}" sütunu ve içindeki değerler silinsin mi?',
    );
    if (onay != true) return;

    final silinenId = donemler[index]['id']!;
    final ilkMi = index == 0;

    // Bu döneme ait elle girilmiş değerler ve zam kuralları temizlenir.
    final kategoriler = _kopya(_sonKategoriler);
    for (final kategori in kategoriler) {
      (kategori['zamlar'] as Map).remove(silinenId);
      for (final kalem in (kategori['kalemler'] as List)) {
        final k = kalem as Map;
        (k['overrides'] as Map).remove(silinenId);
        if (ilkMi) k['yil1'] = '';
      }
    }

    final liste = donemler.map((d) => {'id': d['id']!, 'ad': d['ad']!}).toList()
      ..removeAt(index);

    // Yeni ilk dönem taban olur: değerini yil1'e de yaz.
    if (ilkMi && liste.isNotEmpty) {
      final yeniIlkId = liste.first['id']!;
      for (final kategori in kategoriler) {
        for (final kalem in (kategori['kalemler'] as List)) {
          final k = kalem as Map;
          final v = ((k['overrides'] as Map)[yeniIlkId] ?? '').toString();
          k['yil1'] = v;
        }
      }
    }

    await _donemVeKategoriKaydet(liste, kategoriler);
  }

  Future<void> _donemTasi(
    List<Map<String, String>> donemler,
    int index,
    int yon,
  ) async {
    final hedef = index + yon;
    if (hedef < 0 || hedef >= donemler.length) return;
    final liste = donemler.map((d) => {'id': d['id']!, 'ad': d['ad']!}).toList();
    final t = liste[index];
    liste[index] = liste[hedef];
    liste[hedef] = t;
    await _donemleriKaydet(liste);
  }

  void _donemMenu(
    Offset konum,
    Map<String, dynamic> veri,
    List<Map<String, String>> donemler,
    int index,
  ) {
    _menuGoster(
      konum,
      [
        const PopupMenuItem(value: 'sol', child: Text('Soluna dönem ekle')),
        const PopupMenuItem(value: 'sag', child: Text('Sağına dönem ekle')),
        const PopupMenuDivider(),
        if (index > 0)
          const PopupMenuItem(value: 'geri', child: Text('Sola taşı')),
        if (index < donemler.length - 1)
          const PopupMenuItem(value: 'ileri', child: Text('Sağa taşı')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'sil', child: Text('Dönemi sil')),
      ],
      (x) async {
        if (x == 'sol') await _donemEkle(veri, donemler, index);
        if (x == 'sag') await _donemEkle(veri, donemler, index + 1);
        if (x == 'geri') await _donemTasi(donemler, index, -1);
        if (x == 'ileri') await _donemTasi(donemler, index, 1);
        if (x == 'sil') await _donemSil(donemler, index);
      },
    );
  }

  void _uyari(String metin) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(metin)));
  }

  // ---------- SATIR SIRASI VE SERBEST SATIR ----------
  Future<void> _kalemTasi(
    List<Map<String, dynamic>> mevcut,
    int kat,
    int idx,
    int yon,
  ) async {
    final yeni = _kopya(mevcut);
    final kalemler = yeni[kat]['kalemler'] as List;
    final hedef = idx + yon;
    if (hedef < 0 || hedef >= kalemler.length) return;
    final t = kalemler[idx];
    kalemler[idx] = kalemler[hedef];
    kalemler[hedef] = t;
    await _kaydet(yeni);
  }

  Future<void> _kategoriTasi(
    List<Map<String, dynamic>> mevcut,
    int kat,
    int yon,
  ) async {
    final hedef = kat + yon;
    if (hedef < 0 || hedef >= mevcut.length) return;
    final yeni = _kopya(mevcut);
    final t = yeni[kat];
    yeni[kat] = yeni[hedef];
    yeni[hedef] = t;
    await _kaydet(yeni);
  }

  Future<void> _serbestSatirEkle(
    List<Map<String, dynamic>> mevcut,
    int kat,
  ) async {
    final metin = await _metinDialog(
      'Serbest Satır',
      'Satır metni',
      ipucu: 'Örn. * İşçi vefatında 24 aylık maaşı ödenir',
    );
    if (metin == null || metin.isEmpty) return;
    final yeni = _kopya(mevcut);
    (yeni[kat]['kalemler'] as List).add({
      'ad': metin,
      'yil1': '',
      'not': '',
      'renk': '',
      'tur': 'serbest',
      'overrides': {},
    });
    await _kaydet(yeni);
  }

  // ---------- SÜTUN GENİŞLİKLERİ ----------
  double _sutunGenislik(Map<String, dynamic> veri, int c) {
    final raw = veri['ozetGenislikler'];
    if (raw is List && c < raw.length && raw[c] is num) {
      return (raw[c] as num).toDouble().clamp(60.0, 900.0);
    }
    return c == 0 ? 230 : 150;
  }

  Future<void> _genislikKaydet(
    Map<String, dynamic> veri,
    int sutun,
    double g,
    int sutunSayisi,
  ) async {
    final liste = <double>[
      for (var i = 0; i < sutunSayisi; i++) _sutunGenislik(veri, i),
    ];
    if (sutun >= liste.length) return;
    liste[sutun] = g;
    await _donemRef().update({'ozetGenislikler': liste});
  }

  // ---------- RENK ----------
  Future<void> _renkAta(
    List<Map<String, dynamic>> mevcut,
    int kat, {
    int? kalem,
  }) async {
    final hedef = kalem == null ? mevcut[kat] : _kalemler(mevcut[kat])[kalem];
    final secim = await renkSecDialog(
      context,
      mevcutSaklanan: (hedef['renk'] ?? '').toString(),
      vurguRenk: AppRenk.indigo,
    );
    if (secim == null) return;
    final yeni = _kopya(mevcut);
    if (kalem == null) {
      yeni[kat]['renk'] = secim;
    } else {
      ((yeni[kat]['kalemler'] as List)[kalem] as Map)['renk'] = secim;
    }
    await _kaydet(yeni);
  }

  // ---------- MENÜLER ----------
  Future<void> _menuGoster(
    Offset konum,
    List<PopupMenuEntry<String>> ogeler,
    Future<void> Function(String) secildi,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final secim = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(konum, konum),
        Offset.zero & overlay.size,
      ),
      items: ogeler,
    );
    if (secim == null || !mounted) return;
    await secildi(secim);
  }

  void _kategoriMenu(
    Offset konum,
    List<Map<String, dynamic>> kategoriler,
    int kat,
  ) {
    _menuGoster(
      konum,
      [
        const PopupMenuItem(value: 'renk', child: Text('Arka plan rengi…')),
        const PopupMenuItem(value: 'kalem', child: Text('Kalem ekle')),
        const PopupMenuItem(value: 'serbest', child: Text('Serbest satır ekle')),
        const PopupMenuItem(value: 'not', child: Text('Not düzenle')),
        const PopupMenuDivider(),
        if (kat > 0)
          const PopupMenuItem(value: 'yukari', child: Text('Yukarı taşı')),
        if (kat < kategoriler.length - 1)
          const PopupMenuItem(value: 'asagi', child: Text('Aşağı taşı')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'sil', child: Text('Kategoriyi sil')),
      ],
      (x) async {
        if (x == 'renk') await _renkAta(kategoriler, kat);
        if (x == 'kalem') await _kalemEkle(kategoriler, kat);
        if (x == 'serbest') await _serbestSatirEkle(kategoriler, kat);
        if (x == 'not') await _kategoriNot(kategoriler, kat);
        if (x == 'yukari') await _kategoriTasi(kategoriler, kat, -1);
        if (x == 'asagi') await _kategoriTasi(kategoriler, kat, 1);
        if (x == 'sil') await _kategoriSil(kategoriler, kat);
      },
    );
  }

  void _kalemMenu(
    Offset konum,
    List<Map<String, dynamic>> kategoriler,
    List<Map<String, String>> donemler,
    int kat,
    int idx,
    int donemIndex,
    bool direkt,
  ) {
    final kalemler = _kalemler(kategoriler[kat]);
    final kalem = kalemler[idx];
    final not = (kalem['not'] ?? '').toString();
    final serbest = (kalem['tur'] ?? 'kalem').toString() == 'serbest';
    _menuGoster(
      konum,
      [
        const PopupMenuItem(value: 'renk', child: Text('Arka plan rengi…')),
        if (!serbest)
          const PopupMenuItem(value: 'duzenle', child: Text('Düzenle…')),
        if (not.isNotEmpty)
          const PopupMenuItem(value: 'notGoster', child: Text('Notu göster')),
        const PopupMenuDivider(),
        if (idx > 0)
          const PopupMenuItem(value: 'yukari', child: Text('Yukarı taşı')),
        if (idx < kalemler.length - 1)
          const PopupMenuItem(value: 'asagi', child: Text('Aşağı taşı')),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'sil',
          child: Text(serbest ? 'Satırı sil' : 'Kalemi sil'),
        ),
      ],
      (x) async {
        if (x == 'renk') await _renkAta(kategoriler, kat, kalem: idx);
        if (x == 'duzenle') {
          final otomatik = (donemIndex > 0 && !direkt)
              ? (_hesapla(
                      kalem,
                      kategoriler[kat],
                      donemler,
                      donemIndex,
                    )['metin'] ??
                    '')
                    .toString()
              : '';
          await _kalemDuzenle(
            kategoriler,
            kat,
            idx,
            donemler,
            donemIndex,
            otomatik,
            direkt,
          );
        }
        if (x == 'notGoster') {
          await _kalemNotGoster((kalem['ad'] ?? '').toString(), not);
        }
        if (x == 'yukari') await _kalemTasi(kategoriler, kat, idx, -1);
        if (x == 'asagi') await _kalemTasi(kategoriler, kat, idx, 1);
        if (x == 'sil') await _kalemSil(kategoriler, kat, idx);
      },
    );
  }

  // ---------- IZGARA HÜCRELERİ ----------
  IzgaraHucre _duzenlenebilir({
    required String anahtar,
    required String gosterilen,
    required String duzenlenecek,
    String? ipucuMetin,
    bool kalin = false,
    bool italik = false,
    Color? zemin,
    Color? yazi,
    TextAlign hiza = TextAlign.left,
    void Function(Offset)? onMenu,
    int sutunKapla = 1,
  }) {
    final aktif = _duzAnahtar == anahtar;
    return IzgaraHucre(
      metin: gosterilen,
      kalin: kalin,
      italik: italik,
      zemin: zemin,
      yazi: yazi,
      hiza: hiza,
      sutunKapla: sutunKapla,
      vurgulu: aktif,
      ipucu: ipucuMetin,
      onTap: aktif ? null : () => _duzBaslat(anahtar, duzenlenecek),
      onMenu: onMenu,
      icerik: aktif
          ? TextField(
              controller: _duzC,
              focusNode: _duzOdak,
              style: TextStyle(
                fontSize: 13,
                fontWeight: kalin ? FontWeight.w700 : FontWeight.normal,
              ),
              textAlign: hiza,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _duzKaydet(),
            )
          : null,
    );
  }

  /// Bir kalemin bir döneme ait değer hücresi.
  IzgaraHucre _degerHucresi(
    List<Map<String, dynamic>> kategoriler,
    List<Map<String, String>> donemler,
    int kat,
    int idx,
    int donemIndex,
    bool direkt,
    Color? zemin,
  ) {
    final kategori = kategoriler[kat];
    final kalem = _kalemler(kategori)[idx];
    final donemId = donemler[donemIndex]['id']!;
    final anahtar = 'deger:$kat:$idx:$donemId';

    final ov = (kalem['overrides'] is Map)
        ? Map<String, dynamic>.from(kalem['overrides'])
        : {};

    // İlk dönem = taban değer
    if (donemIndex <= 0) {
      final v = _tabanDeger(kalem, donemler);
      return _duzenlenebilir(
        anahtar: anahtar,
        gosterilen: v.isEmpty ? '—' : v,
        duzenlenecek: v,
        kalin: true,
        yazi: v.isEmpty ? Colors.grey.shade400 : AppRenk.amber,
        hiza: TextAlign.right,
        zemin: zemin,
        ipucuMetin: 'Taban değer — zam zinciri buradan başlar',
        onMenu: (k) =>
            _kalemMenu(k, kategoriler, donemler, kat, idx, donemIndex, direkt),
      );
    }

    final elleDeger = (ov[donemId] ?? '').toString();

    if (direkt) {
      return _duzenlenebilir(
        anahtar: anahtar,
        gosterilen: elleDeger.isEmpty ? '—' : elleDeger,
        duzenlenecek: elleDeger,
        kalin: true,
        yazi: elleDeger.isEmpty ? Colors.grey.shade400 : AppRenk.amber,
        hiza: TextAlign.right,
        zemin: zemin,
        ipucuMetin: '${donemler[donemIndex]['ad']} değeri',
        onMenu: (k) =>
            _kalemMenu(k, kategoriler, donemler, kat, idx, donemIndex, direkt),
      );
    }

    final hesap = _hesapla(kalem, kategori, donemler, donemIndex);
    final tur = (hesap['tur'] ?? '').toString();
    final metin = (hesap['metin'] ?? '').toString();

    final String ipucu;
    final Color renk;
    if (tur == 'elle') {
      ipucu = 'Elle girildi — silersen otomatik hesaba döner';
      renk = AppRenk.indigo;
    } else if (tur == 'hesap') {
      ipucu =
          'Otomatik: ${hesap['baz']} × (1 + %${hesap['kural']})'
          '\nÜzerine yazarsan elle değere döner';
      renk = AppRenk.amber;
    } else {
      final kural = (hesap['kural'] ?? '').toString();
      ipucu = kural.isEmpty
          ? 'Zam oranı girilmemiş'
          : 'Önceki dönem değeri sayı değil, hesaplanamıyor';
      renk = Colors.grey.shade400;
    }

    return _duzenlenebilir(
      anahtar: anahtar,
      gosterilen: metin.isEmpty ? '—' : metin,
      duzenlenecek: elleDeger,
      kalin: true,
      italik: tur == 'elle',
      yazi: renk,
      hiza: TextAlign.right,
      zemin: zemin,
      ipucuMetin: ipucu,
      onMenu: (k) =>
          _kalemMenu(k, kategoriler, donemler, kat, idx, donemIndex, direkt),
    );
  }

  /// Kategori başlığı — tüm genişliği kaplayan bölüm satırı.
  List<IzgaraHucre?> _kategoriSatiri(
    List<Map<String, dynamic>> kategoriler,
    int kat,
    int sutunSayisi,
  ) {
    final kategori = kategoriler[kat];
    final zemin = renkCoz((kategori['renk'] ?? '').toString()) ?? _katVarsayilan;
    return [
      _duzenlenebilir(
        anahtar: 'kategoriAd:$kat:-1:0',
        gosterilen: (kategori['ad'] ?? '').toString(),
        duzenlenecek: (kategori['ad'] ?? '').toString(),
        kalin: true,
        zemin: zemin,
        yazi: yaziRengi(zemin),
        sutunKapla: sutunSayisi,
        ipucuMetin: 'Tıkla: adı değiştir • Sağ tık: renk, satır ekle, taşı, sil',
        onMenu: (k) => _kategoriMenu(k, kategoriler, kat),
      ),
      for (var i = 1; i < sutunSayisi; i++) null,
    ];
  }

  /// Kaleme bağlı olmayan serbest açıklama satırı.
  List<IzgaraHucre?> _serbestSatir(
    List<Map<String, dynamic>> kategoriler,
    List<Map<String, String>> donemler,
    int kat,
    int idx,
    int sutunSayisi,
    bool direkt,
  ) {
    final kalem = _kalemler(kategoriler[kat])[idx];
    final zemin = renkCoz((kalem['renk'] ?? '').toString());
    return [
      _duzenlenebilir(
        anahtar: 'kalemAd:$kat:$idx:0',
        gosterilen: (kalem['ad'] ?? '').toString(),
        duzenlenecek: (kalem['ad'] ?? '').toString(),
        italik: true,
        yazi: Colors.black87,
        zemin: zemin,
        sutunKapla: sutunSayisi,
        ipucuMetin: 'Serbest satır — istediğini yazabilirsin',
        onMenu: (k) => _kalemMenu(k, kategoriler, donemler, kat, idx, 0, direkt),
      ),
      for (var i = 1; i < sutunSayisi; i++) null,
    ];
  }

  static final Color _katVarsayilan = AppRenk.indigo.withOpacity(0.14);
  static const Color _baslikZemin = Color(0xFFE8EAF6);

  /// Dönem başlığı hücresi — tıkla adını değiştir, sağ tık menü.
  IzgaraHucre _donemBasligi(
    Map<String, dynamic> veri,
    List<Map<String, String>> donemler,
    int index,
  ) {
    final d = donemler[index];
    return _duzenlenebilir(
      anahtar: 'donemAd:-1:-1:${d['id']}',
      gosterilen: d['ad']!,
      duzenlenecek: d['ad']!,
      kalin: true,
      hiza: TextAlign.center,
      zemin: _baslikZemin,
      ipucuMetin: 'Tıkla: adı değiştir • Sağ tık: dönem ekle, taşı, sil',
      onMenu: (k) => _donemMenu(k, veri, donemler, index),
    );
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
        final donemler = _donemler(veri);
        _sonKategoriler = kategoriler;
        _sonDonemler = donemler;
        final seciliDonem = _seciliDonem.clamp(0, donemler.length - 1);
        final eklenenAdlar = kategoriler.map((k) => k['ad'] as String).toSet();
        final tumDonemler = _tumDonemler || donemler.length <= 1;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sözleşme Bilgileri',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _donemEkle(veri, donemler, donemler.length),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Dönem ekle'),
                ),
                const SizedBox(width: 8),
                if (kategoriler.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _exceleAktar(veri),
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Excel\'e Aktar'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (donemler.length > 1)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.table_chart_outlined, size: 16),
                        label: Text('Tüm dönemler'),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.view_week_outlined, size: 16),
                        label: Text('Tek dönem (detaylı)'),
                      ),
                    ],
                    selected: {tumDonemler},
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    onSelectionChanged: (s) =>
                        setState(() => _tumDonemler = s.first),
                  ),
                  if (!tumDonemler)
                    ...List.generate(donemler.length, (i) {
                      return ChoiceChip(
                        label: Text(donemler[i]['ad']!),
                        selected: seciliDonem == i,
                        selectedColor: AppRenk.indigo,
                        labelStyle: TextStyle(
                          color: seciliDonem == i
                              ? Colors.white
                              : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() => _seciliDonem = i),
                      );
                    }),
                ],
              ),
            const SizedBox(height: 14),
            if (kategoriler.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Henüz kategori yok — aşağıdan ekleyin',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: tumDonemler
                    ? _tumDonemlerIzgara(veri, kategoriler, donemler)
                    : _tekDonemIzgara(
                        veri,
                        kategoriler,
                        donemler,
                        seciliDonem,
                      ),
              ),
            const SizedBox(height: 6),
            Text(
              'Hücreye tıkla: yaz  •  Sağ tık (telefonda uzun bas): renk, satır/dönem ekle, taşı, sil  •  Sütun kenarını çek: genişlik',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 12),
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

  /// Kalemler satır, dönemler sütun.
  Widget _tumDonemlerIzgara(
    Map<String, dynamic> veri,
    List<Map<String, dynamic>> kategoriler,
    List<Map<String, String>> donemler,
  ) {
    final sutunSayisi = 1 + donemler.length;
    final satirlar = <List<IzgaraHucre?>>[
      [
        const IzgaraHucre(metin: 'Kalem', kalin: true, zemin: _baslikZemin),
        for (var i = 0; i < donemler.length; i++)
          _donemBasligi(veri, donemler, i),
      ],
    ];

    for (var kat = 0; kat < kategoriler.length; kat++) {
      final kategori = kategoriler[kat];
      final direkt = _direkt(kategori);
      final kalemler = _kalemler(kategori);
      final zamlar = (kategori['zamlar'] is Map)
          ? Map<String, dynamic>.from(kategori['zamlar'])
          : {};

      satirlar.add(_kategoriSatiri(kategoriler, kat, sutunSayisi));

      final not = (kategori['not'] ?? '').toString();
      if (not.isNotEmpty) {
        satirlar.add([
          IzgaraHucre(
            metin: not,
            italik: true,
            yazi: Colors.black54,
            yaziBoyutu: 12,
            sutunKapla: sutunSayisi,
          ),
          for (var i = 1; i < sutunSayisi; i++) null,
        ]);
      }

      if (!direkt && donemler.length > 1) {
        satirlar.add([
          IzgaraHucre(
            metin: 'Zam Oranı',
            italik: true,
            yazi: AppRenk.emerald,
            yaziBoyutu: 12.5,
          ),
          for (var i = 0; i < donemler.length; i++)
            if (i == 0)
              IzgaraHucre(
                metin: '—',
                hiza: TextAlign.center,
                yazi: Colors.grey.shade400,
                ipucu: 'İlk dönem tabandır, zam uygulanmaz',
              )
            else
              _duzenlenebilir(
                anahtar: 'zam:$kat:-1:${donemler[i]['id']}',
                gosterilen: _zamMetni(
                  (zamlar[donemler[i]['id']] ?? '').toString().trim(),
                ),
                duzenlenecek: (zamlar[donemler[i]['id']] ?? '').toString(),
                italik: true,
                kalin: true,
                yazi: AppRenk.emerald,
                hiza: TextAlign.center,
                ipucuMetin:
                    'Tıkla: bu dönemin zam oranını yaz (örn. 20)\n'
                    'Bir önceki dönemin üzerine uygulanır',
              ),
        ]);
      }

      if (kalemler.isEmpty) {
        satirlar.add([
          IzgaraHucre(
            metin: 'Kalem yok — kategoriye sağ tıkla, "Kalem ekle"',
            italik: true,
            yazi: Colors.grey.shade500,
            yaziBoyutu: 12,
            sutunKapla: sutunSayisi,
          ),
          for (var i = 1; i < sutunSayisi; i++) null,
        ]);
      }

      for (var idx = 0; idx < kalemler.length; idx++) {
        if ((kalemler[idx]['tur'] ?? 'kalem').toString() == 'serbest') {
          satirlar.add(
            _serbestSatir(
              kategoriler,
              donemler,
              kat,
              idx,
              sutunSayisi,
              direkt,
            ),
          );
          continue;
        }
        final zemin = renkCoz((kalemler[idx]['renk'] ?? '').toString());
        satirlar.add([
          _duzenlenebilir(
            anahtar: 'kalemAd:$kat:$idx:0',
            gosterilen: (kalemler[idx]['ad'] ?? '').toString(),
            duzenlenecek: (kalemler[idx]['ad'] ?? '').toString(),
            zemin: zemin,
            ipucuMetin: (kalemler[idx]['not'] ?? '').toString(),
            onMenu: (k) =>
                _kalemMenu(k, kategoriler, donemler, kat, idx, 0, direkt),
          ),
          for (var i = 0; i < donemler.length; i++)
            _degerHucresi(kategoriler, donemler, kat, idx, i, direkt, zemin),
        ]);
      }
    }

    return IzgaraTablo(
      sutunGenislikleri: [
        for (var c = 0; c < sutunSayisi; c++) _sutunGenislik(veri, c),
      ],
      satirlar: satirlar,
      vurguRenk: AppRenk.indigo,
      onGenislikDegisti: (c, g) => _genislikKaydet(veri, c, g, sutunSayisi),
    );
  }

  /// Tek dönem: önceki dönem ve zam oranı ayrı sütunlarda.
  Widget _tekDonemIzgara(
    Map<String, dynamic> veri,
    List<Map<String, dynamic>> kategoriler,
    List<Map<String, String>> donemler,
    int donemIndex,
  ) {
    final detay = donemIndex > 0;
    final sutunSayisi = detay ? 4 : 2;
    final oncekiAd = detay ? donemler[donemIndex - 1]['ad']! : '';

    final satirlar = <List<IzgaraHucre?>>[
      [
        const IzgaraHucre(metin: 'Kalem', kalin: true, zemin: _baslikZemin),
        if (detay) ...[
          IzgaraHucre(
            metin: 'Önceki\n$oncekiAd',
            kalin: true,
            hiza: TextAlign.center,
            zemin: _baslikZemin,
            yaziBoyutu: 12,
          ),
          const IzgaraHucre(
            metin: 'Zam',
            kalin: true,
            hiza: TextAlign.center,
            zemin: _baslikZemin,
          ),
        ],
        _donemBasligi(veri, donemler, donemIndex),
      ],
    ];

    for (var kat = 0; kat < kategoriler.length; kat++) {
      final kategori = kategoriler[kat];
      final direkt = _direkt(kategori);
      final kalemler = _kalemler(kategori);
      final zamlar = (kategori['zamlar'] is Map)
          ? Map<String, dynamic>.from(kategori['zamlar'])
          : {};

      satirlar.add(_kategoriSatiri(kategoriler, kat, sutunSayisi));

      for (var idx = 0; idx < kalemler.length; idx++) {
        final kalem = kalemler[idx];
        if ((kalem['tur'] ?? 'kalem').toString() == 'serbest') {
          satirlar.add(
            _serbestSatir(
              kategoriler,
              donemler,
              kat,
              idx,
              sutunSayisi,
              direkt,
            ),
          );
          continue;
        }
        final zemin = renkCoz((kalem['renk'] ?? '').toString());

        satirlar.add([
          _duzenlenebilir(
            anahtar: 'kalemAd:$kat:$idx:0',
            gosterilen: (kalem['ad'] ?? '').toString(),
            duzenlenecek: (kalem['ad'] ?? '').toString(),
            zemin: zemin,
            ipucuMetin: (kalem['not'] ?? '').toString(),
            onMenu: (k) => _kalemMenu(
              k,
              kategoriler,
              donemler,
              kat,
              idx,
              donemIndex,
              direkt,
            ),
          ),
          if (detay) ...[
            IzgaraHucre(
              metin: _degerMetni(
                kalem,
                kategori,
                donemler,
                donemIndex - 1,
                direkt,
              ).isEmpty
                  ? '—'
                  : _degerMetni(
                      kalem,
                      kategori,
                      donemler,
                      donemIndex - 1,
                      direkt,
                    ),
              hiza: TextAlign.right,
              yazi: Colors.grey.shade600,
              zemin: zemin,
              ipucu: 'Bir önceki dönemin değeri',
            ),
            if (direkt)
              IzgaraHucre(
                metin: '—',
                hiza: TextAlign.center,
                yazi: Colors.grey.shade400,
                zemin: zemin,
              )
            else
              _duzenlenebilir(
                anahtar: 'zam:$kat:-1:${donemler[donemIndex]['id']}',
                gosterilen: _zamMetni(
                  (zamlar[donemler[donemIndex]['id']] ?? '').toString().trim(),
                ),
                duzenlenecek: (zamlar[donemler[donemIndex]['id']] ?? '')
                    .toString(),
                kalin: true,
                yazi: AppRenk.emerald,
                hiza: TextAlign.center,
                zemin: zemin,
                ipucuMetin: 'Tıkla: bu dönemin zam oranını yaz',
              ),
          ],
          _degerHucresi(
            kategoriler,
            donemler,
            kat,
            idx,
            donemIndex,
            direkt,
            zemin,
          ),
        ]);
      }
    }

    return IzgaraTablo(
      sutunGenislikleri: [
        for (var c = 0; c < sutunSayisi; c++) _sutunGenislik(veri, c),
      ],
      satirlar: satirlar,
      vurguRenk: AppRenk.indigo,
      onGenislikDegisti: (c, g) => _genislikKaydet(veri, c, g, sutunSayisi),
    );
  }
}
