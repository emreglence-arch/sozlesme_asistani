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
  int _seciliYil = 1;

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
    final yilSayisi = _yilSayisi(veri);
    final sutunSayisi = 1 + yilSayisi;

    final satirlar = <List<XlsxHucre?>>[
      [
        const XlsxHucre(deger: 'Kalem', kalin: true, arkaPlan: 'E8EAF6'),
        for (var y = 1; y <= yilSayisi; y++)
          XlsxHucre(
            deger: _yilEtiketi(veri, y),
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
      if (!direkt && yilSayisi > 1) {
        satirlar.add([
          const XlsxHucre(deger: 'Yıllık Zam Oranı', italik: true),
          for (var y = 1; y <= yilSayisi; y++)
            XlsxHucre(
              deger: y == 1
                  ? '-'
                  : _zamMetni((zamlar['$y'] ?? '').toString().trim()),
              hizalama: 'orta',
              italik: true,
            ),
        ]);
      }

      for (final kalem in _kalemler(kategori)) {
        final kalemRenk = renkHex((kalem['renk'] ?? '').toString());
        satirlar.add([
          XlsxHucre(deger: (kalem['ad'] ?? '').toString(), arkaPlan: kalemRenk),
          for (var y = 1; y <= yilSayisi; y++)
            XlsxHucre(
              deger: _degerMetni(kalem, kategori, y, direkt),
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
    int yil,
    bool direkt,
  ) {
    if (yil <= 1) return (kalem['yil1'] ?? '').toString();
    if (direkt) {
      final ov = (kalem['overrides'] is Map)
          ? Map<String, dynamic>.from(kalem['overrides'])
          : {};
      return (ov['$yil'] ?? '').toString();
    }
    return (_hesapla(kalem, kategori, yil)['metin'] ?? '').toString();
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
    required int yil,
    Map<String, dynamic>? mevcut,
    String otomatik = '',
    bool direkt = false,
  }) {
    final adC = TextEditingController(text: mevcut?['ad']?.toString() ?? '');
    final notC = TextEditingController(text: mevcut?['not']?.toString() ?? '');
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
        .map((k) => {'ad': k, 'yil1': '', 'not': '', 'overrides': {}})
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
    final sonuc = await _kalemDialog(yil: 1, direkt: direkt);
    if (sonuc == null || sonuc['ad']!.isEmpty) return;
    final yeni = _kopya(mevcut);
    (yeni[kat]['kalemler'] as List).add({
      'ad': sonuc['ad'],
      'yil1': sonuc['deger'],
      'not': sonuc['not'],
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
    k['not'] = sonuc['not'];
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
  // Hücreye tıklayıp yazma: anahtar 'tur:kategori:kalem:yil' biçiminde.
  String? _duzAnahtar;
  final TextEditingController _duzC = TextEditingController();
  final FocusNode _duzOdak = FocusNode();
  bool _tumYillar = true;

  /// Akıştan gelen en son kategori listesi (düzenleme kaydederken kullanılır).
  List<Map<String, dynamic>> _sonKategoriler = [];

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
    final yil = int.tryParse(p[3]) ?? 0;

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
        (yeni[kat]['zamlar'] as Map)['$yil'] = metin;
      case 'deger':
        if (idx < 0 || idx >= kalemler.length) return;
        final k = kalemler[idx] as Map;
        if (yil <= 1) {
          k['yil1'] = metin;
        } else {
          final ov = k['overrides'] as Map;
          // Boş bırakmak = otomatik hesaba dön
          if (metin.isEmpty) {
            ov.remove('$yil');
          } else {
            ov['$yil'] = metin;
          }
        }
      default:
        return;
    }
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
      const [
        PopupMenuItem(value: 'renk', child: Text('Arka plan rengi…')),
        PopupMenuItem(value: 'kalem', child: Text('Kalem ekle')),
        PopupMenuItem(value: 'not', child: Text('Not düzenle')),
        PopupMenuItem(value: 'sil', child: Text('Kategoriyi sil')),
      ],
      (x) async {
        if (x == 'renk') await _renkAta(kategoriler, kat);
        if (x == 'kalem') await _kalemEkle(kategoriler, kat);
        if (x == 'not') await _kategoriNot(kategoriler, kat);
        if (x == 'sil') await _kategoriSil(kategoriler, kat);
      },
    );
  }

  void _kalemMenu(
    Offset konum,
    List<Map<String, dynamic>> kategoriler,
    int kat,
    int idx,
    int yil,
    bool direkt,
  ) {
    final kalem = _kalemler(kategoriler[kat])[idx];
    final not = (kalem['not'] ?? '').toString();
    _menuGoster(
      konum,
      [
        const PopupMenuItem(value: 'renk', child: Text('Arka plan rengi…')),
        const PopupMenuItem(value: 'duzenle', child: Text('Düzenle…')),
        if (not.isNotEmpty)
          const PopupMenuItem(value: 'notGoster', child: Text('Notu göster')),
        const PopupMenuItem(value: 'sil', child: Text('Kalemi sil')),
      ],
      (x) async {
        if (x == 'renk') await _renkAta(kategoriler, kat, kalem: idx);
        if (x == 'duzenle') {
          final otomatik = (yil > 1 && !direkt)
              ? (_hesapla(kalem, kategoriler[kat], yil)['metin'] ?? '')
                    .toString()
              : '';
          await _kalemDuzenle(kategoriler, kat, idx, yil, otomatik, direkt);
        }
        if (x == 'notGoster') {
          await _kalemNotGoster((kalem['ad'] ?? '').toString(), not);
        }
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

  /// Bir kalemin bir yıla ait değer hücresi.
  IzgaraHucre _degerHucresi(
    List<Map<String, dynamic>> kategoriler,
    int kat,
    int idx,
    int yil,
    bool direkt,
    Color? zemin,
  ) {
    final kategori = kategoriler[kat];
    final kalem = _kalemler(kategori)[idx];
    final anahtar = 'deger:$kat:$idx:$yil';

    if (yil <= 1) {
      final v = (kalem['yil1'] ?? '').toString();
      return _duzenlenebilir(
        anahtar: anahtar,
        gosterilen: v.isEmpty ? '—' : v,
        duzenlenecek: v,
        kalin: true,
        yazi: v.isEmpty ? Colors.grey.shade400 : AppRenk.amber,
        hiza: TextAlign.right,
        zemin: zemin,
        ipucuMetin: '1. yıl değeri — taban',
        onMenu: (k) => _kalemMenu(k, kategoriler, kat, idx, yil, direkt),
      );
    }

    final ov = (kalem['overrides'] is Map)
        ? Map<String, dynamic>.from(kalem['overrides'])
        : {};
    final elleDeger = (ov['$yil'] ?? '').toString();

    if (direkt) {
      return _duzenlenebilir(
        anahtar: anahtar,
        gosterilen: elleDeger.isEmpty ? '—' : elleDeger,
        duzenlenecek: elleDeger,
        kalin: true,
        yazi: elleDeger.isEmpty ? Colors.grey.shade400 : AppRenk.amber,
        hiza: TextAlign.right,
        zemin: zemin,
        ipucuMetin: '$yil. yıl değeri',
        onMenu: (k) => _kalemMenu(k, kategoriler, kat, idx, yil, direkt),
      );
    }

    final hesap = _hesapla(kalem, kategori, yil);
    final tur = (hesap['tur'] ?? '').toString();
    final metin = (hesap['metin'] ?? '').toString();

    final String ipucu;
    final Color renk;
    if (tur == 'elle') {
      ipucu = 'Elle girildi — silersen otomatik hesaba döner';
      renk = AppRenk.indigo;
    } else if (tur == 'hesap') {
      ipucu =
          'Otomatik: bir önceki yıl × (1 + %${hesap['kural']})'
          '\nÜzerine yazarsan elle değere döner';
      renk = AppRenk.amber;
    } else {
      final kural = (hesap['kural'] ?? '').toString();
      ipucu = kural.isEmpty
          ? 'Zam oranı girilmemiş'
          : 'Taban değer sayı değil, hesaplanamıyor';
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
      onMenu: (k) => _kalemMenu(k, kategoriler, kat, idx, yil, direkt),
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
        ipucuMetin: 'Tıkla: adı değiştir • Sağ tık: renk, kalem, not, sil',
        onMenu: (k) => _kategoriMenu(k, kategoriler, kat),
      ),
      for (var i = 1; i < sutunSayisi; i++) null,
    ];
  }

  static final Color _katVarsayilan = AppRenk.indigo.withOpacity(0.14);

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
        _sonKategoriler = kategoriler;
        final yilSayisi = _yilSayisi(veri);
        final seciliYil = _seciliYil.clamp(1, yilSayisi);
        final eklenenAdlar = kategoriler.map((k) => k['ad'] as String).toSet();
        final tumYillar = _tumYillar || yilSayisi <= 1;

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
                if (kategoriler.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _exceleAktar(veri),
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Excel\'e Aktar'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (yilSayisi > 1)
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
                        label: Text('Tüm yıllar'),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.view_week_outlined, size: 16),
                        label: Text('Tek yıl (detaylı)'),
                      ),
                    ],
                    selected: {tumYillar},
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    onSelectionChanged: (s) =>
                        setState(() => _tumYillar = s.first),
                  ),
                  if (!tumYillar)
                    ...List.generate(yilSayisi, (i) {
                      final yil = i + 1;
                      return ChoiceChip(
                        label: Text(_yilEtiketi(veri, yil)),
                        selected: seciliYil == yil,
                        selectedColor: AppRenk.indigo,
                        labelStyle: TextStyle(
                          color: seciliYil == yil
                              ? Colors.white
                              : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() => _seciliYil = yil),
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
                child: tumYillar
                    ? _tumYillarIzgara(veri, kategoriler, yilSayisi)
                    : _tekYilIzgara(veri, kategoriler, seciliYil),
              ),
            const SizedBox(height: 6),
            Text(
              'Hücreye tıkla: yaz  •  Sağ tık (telefonda uzun bas): renk, kalem, not, sil  •  Sütun kenarını çek: genişlik',
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

  /// Kalemler satır, yıllar sütun.
  Widget _tumYillarIzgara(
    Map<String, dynamic> veri,
    List<Map<String, dynamic>> kategoriler,
    int yilSayisi,
  ) {
    final sutunSayisi = 1 + yilSayisi;
    final satirlar = <List<IzgaraHucre?>>[
      [
        const IzgaraHucre(
          metin: 'Kalem',
          kalin: true,
          zemin: Color(0xFFE8EAF6),
        ),
        for (var y = 1; y <= yilSayisi; y++)
          IzgaraHucre(
            metin: _yilEtiketi(veri, y),
            kalin: true,
            hiza: TextAlign.center,
            zemin: const Color(0xFFE8EAF6),
          ),
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

      if (!direkt && yilSayisi > 1) {
        satirlar.add([
          IzgaraHucre(
            metin: 'Yıllık Zam Oranı',
            italik: true,
            yazi: AppRenk.emerald,
            yaziBoyutu: 12.5,
          ),
          for (var y = 1; y <= yilSayisi; y++)
            if (y == 1)
              IzgaraHucre(
                metin: '—',
                hiza: TextAlign.center,
                yazi: Colors.grey.shade400,
              )
            else
              _duzenlenebilir(
                anahtar: 'zam:$kat:-1:$y',
                gosterilen: _zamMetni((zamlar['$y'] ?? '').toString().trim()),
                duzenlenecek: (zamlar['$y'] ?? '').toString(),
                italik: true,
                kalin: true,
                yazi: AppRenk.emerald,
                hiza: TextAlign.center,
                ipucuMetin: 'Tıkla: $y. yıl zam oranını yaz (örn. 40)',
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
        final zemin = renkCoz((kalemler[idx]['renk'] ?? '').toString());
        satirlar.add([
          _duzenlenebilir(
            anahtar: 'kalemAd:$kat:$idx:0',
            gosterilen: (kalemler[idx]['ad'] ?? '').toString(),
            duzenlenecek: (kalemler[idx]['ad'] ?? '').toString(),
            zemin: zemin,
            ipucuMetin: (kalemler[idx]['not'] ?? '').toString(),
            onMenu: (k) => _kalemMenu(k, kategoriler, kat, idx, 1, direkt),
          ),
          for (var y = 1; y <= yilSayisi; y++)
            _degerHucresi(kategoriler, kat, idx, y, direkt, zemin),
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

  /// Tek yıl: taban ve zam oranı ayrı sütunlarda.
  Widget _tekYilIzgara(
    Map<String, dynamic> veri,
    List<Map<String, dynamic>> kategoriler,
    int yil,
  ) {
    final detay = yil > 1;
    final sutunSayisi = detay ? 4 : 2;

    final satirlar = <List<IzgaraHucre?>>[
      [
        const IzgaraHucre(
          metin: 'Kalem',
          kalin: true,
          zemin: Color(0xFFE8EAF6),
        ),
        if (detay) ...[
          const IzgaraHucre(
            metin: 'Taban (1. Yıl)',
            kalin: true,
            hiza: TextAlign.center,
            zemin: Color(0xFFE8EAF6),
          ),
          const IzgaraHucre(
            metin: 'Zam',
            kalin: true,
            hiza: TextAlign.center,
            zemin: Color(0xFFE8EAF6),
          ),
        ],
        IzgaraHucre(
          metin: _yilEtiketi(veri, yil),
          kalin: true,
          hiza: TextAlign.center,
          zemin: const Color(0xFFE8EAF6),
        ),
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
        final zemin = renkCoz((kalem['renk'] ?? '').toString());
        final taban = (kalem['yil1'] ?? '').toString();

        satirlar.add([
          _duzenlenebilir(
            anahtar: 'kalemAd:$kat:$idx:0',
            gosterilen: (kalem['ad'] ?? '').toString(),
            duzenlenecek: (kalem['ad'] ?? '').toString(),
            zemin: zemin,
            ipucuMetin: (kalem['not'] ?? '').toString(),
            onMenu: (k) => _kalemMenu(k, kategoriler, kat, idx, yil, direkt),
          ),
          if (detay) ...[
            IzgaraHucre(
              metin: taban.isEmpty ? '—' : taban,
              hiza: TextAlign.right,
              yazi: Colors.grey.shade600,
              zemin: zemin,
              ipucu: '1. yıl değeri',
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
                anahtar: 'zam:$kat:-1:$yil',
                gosterilen: _zamMetni((zamlar['$yil'] ?? '').toString().trim()),
                duzenlenecek: (zamlar['$yil'] ?? '').toString(),
                kalin: true,
                yazi: AppRenk.emerald,
                hiza: TextAlign.center,
                zemin: zemin,
                ipucuMetin: 'Tıkla: $yil. yıl zam oranını yaz',
              ),
          ],
          _degerHucresi(kategoriler, kat, idx, yil, direkt, zemin),
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
