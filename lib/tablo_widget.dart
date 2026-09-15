import 'package:flutter/material.dart';
import 'dosya_kaydet.dart';
import 'excel_yazici.dart';
import 'renk_secici.dart';

// Renk paleti, dönüştürücüler ve seçim penceresi renk_secici.dart'ta
// (dönem özet ızgarası da aynısını kullanıyor).

/// Tek bir hücre. Firestore'da `{d, k, r, sk, yk, hz}` olarak saklanır;
/// eski tablolardaki düz metin hücreler de okunur.
class _Hucre {
  String d; // değer
  bool k; // kalın
  String r; // renk anahtarı
  int sk; // satır kaplama (dikey birleştirme)
  int yk; // yatay kaplama (sütun birleştirme)
  String hz; // hizalama: '', 'sol', 'orta', 'sag'

  _Hucre({
    this.d = '',
    this.k = false,
    this.r = '',
    this.sk = 1,
    this.yk = 1,
    this.hz = '',
  });

  factory _Hucre.oku(dynamic raw) {
    if (raw is Map) {
      int say(dynamic v) => v is num ? v.toInt() : 1;
      return _Hucre(
        d: (raw['d'] ?? '').toString(),
        k: raw['k'] == true,
        r: (raw['r'] ?? '').toString(),
        sk: say(raw['sk']).clamp(1, 200),
        yk: say(raw['yk']).clamp(1, 200),
        hz: (raw['hz'] ?? '').toString(),
      );
    }
    return _Hucre(d: raw == null ? '' : raw.toString());
  }

  Map<String, dynamic> yaz() {
    final m = <String, dynamic>{'d': d};
    if (k) m['k'] = true;
    if (r.isNotEmpty) m['r'] = r;
    if (sk > 1) m['sk'] = sk;
    if (yk > 1) m['yk'] = yk;
    if (hz.isNotEmpty) m['hz'] = hz;
    return m;
  }

  _Hucre kopya() => _Hucre(d: d, k: k, r: r, sk: sk, yk: yk, hz: hz);
}

class TabloWidget extends StatefulWidget {
  final Map<String, dynamic> tablo;
  final Color renk;
  final Future<void> Function(Map<String, dynamic> yeniTablo) onDegisti;
  final VoidCallback? onBaslikDuzenle;
  final VoidCallback? onTabloSil;

  const TabloWidget({
    super.key,
    required this.tablo,
    required this.renk,
    required this.onDegisti,
    this.onBaslikDuzenle,
    this.onTabloSil,
  });

  @override
  State<TabloWidget> createState() => _TabloWidgetState();
}

class _TabloWidgetState extends State<TabloWidget> {
  static const double _varsayilanGenislik = 140;
  static const double _enAzGenislik = 60;
  static const double _enAzYukseklik = 38;
  static const double _yatayBosluk = 8;
  static const double _dikeyBosluk = 7;
  static const double _cizgi = 0.8;

  // Düzenlenen hücre
  int? _duzR;
  int? _duzC;
  final TextEditingController _hucreC = TextEditingController();
  final FocusNode _hucreOdak = FocusNode();

  // Sütun genişliği sürüklenirken geçici değer
  int? _surukleSutun;
  double _surukleGenislik = 0;

  @override
  void initState() {
    super.initState();
    _hucreOdak.addListener(() {
      if (!_hucreOdak.hasFocus && _duzR != null) _hucreKaydet();
    });
  }

  @override
  void dispose() {
    _hucreC.dispose();
    _hucreOdak.dispose();
    super.dispose();
  }

  // ---------- VERİ OKUMA ----------
  List<Map<String, dynamic>> get _sutunlar {
    final raw = widget.tablo['sutunlar'];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  List<List<_Hucre>> get _satirlar {
    final n = _sutunlar.length;
    final raw = widget.tablo['satirlar'];
    if (raw is! List) return [];
    return raw.map<List<_Hucre>>((r) {
      List<_Hucre> liste;
      if (r is Map && r['h'] is List) {
        liste = (r['h'] as List).map((c) => _Hucre.oku(c)).toList();
      } else if (r is List) {
        liste = r.map((c) => _Hucre.oku(c)).toList();
      } else {
        liste = <_Hucre>[];
      }
      while (liste.length < n) {
        liste.add(_Hucre());
      }
      return liste.length > n ? liste.sublist(0, n) : liste;
    }).toList();
  }

  String _ad(int i) => (_sutunlar[i]['ad'] ?? '').toString();
  String _tip(int i) => (_sutunlar[i]['tip'] ?? 'metin').toString();

  double _genislik(int i) {
    if (_surukleSutun == i) return _surukleGenislik;
    final g = _sutunlar[i]['genislik'];
    if (g is num) return g.toDouble().clamp(_enAzGenislik, 900.0);
    return _varsayilanGenislik;
  }

  String _tarihMetni(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';

  /// Değişiklikleri yazmak için tablonun düzenlenebilir bir kopyası.
  Map<String, dynamic> _kopya() => {
    'baslik': (widget.tablo['baslik'] ?? 'Tablo').toString(),
    'sutunlar': _sutunlar.map((s) => Map<String, dynamic>.from(s)).toList(),
    'satirlar': _satirlar
        .map((r) => {'h': r.map((h) => h.kopya()).toList()})
        .toList(),
  };

  /// Kopyayı Firestore'a yazılabilir hale getirir (hücreleri map'e çevirir).
  Future<void> _yaz(Map<String, dynamic> yeni) async {
    final satirlar = (yeni['satirlar'] as List)
        .map(
          (r) => {
            'h': ((r as Map)['h'] as List)
                .map((h) => (h as _Hucre).yaz())
                .toList(),
          },
        )
        .toList();
    await widget.onDegisti({
      'baslik': yeni['baslik'],
      'sutunlar': yeni['sutunlar'],
      'satirlar': satirlar,
    });
  }

  /// Satır/sütun eklenip silindikten sonra taşan birleştirmeleri düzeltir.
  void _birlestirmeleriDuzelt(Map<String, dynamic> yeni) {
    final satirlar = yeni['satirlar'] as List;
    final sutunSayisi = (yeni['sutunlar'] as List).length;
    for (var r = 0; r < satirlar.length; r++) {
      final h = (satirlar[r] as Map)['h'] as List;
      for (var c = 0; c < h.length; c++) {
        final hucre = h[c] as _Hucre;
        if (hucre.sk > satirlar.length - r) hucre.sk = satirlar.length - r;
        if (hucre.yk > sutunSayisi - c) hucre.yk = sutunSayisi - c;
        if (hucre.sk < 1) hucre.sk = 1;
        if (hucre.yk < 1) hucre.yk = 1;
      }
    }
  }

  // ---------- YERLEŞİM HESABI ----------
  TextStyle _hucreStili(_Hucre h) => TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: h.k ? FontWeight.w700 : FontWeight.normal,
    color: Colors.black87,
  );

  TextStyle get _baslikStili => TextStyle(
    fontSize: 12.5,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: widget.renk,
  );

  double _metinYukseklik(String metin, double genislik, TextStyle stil) {
    final tp = TextPainter(
      text: TextSpan(text: metin.isEmpty ? ' ' : metin, style: stil),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: (genislik - _yatayBosluk * 2).clamp(10.0, 2000.0));
    return tp.height + _dikeyBosluk * 2;
  }

  /// Hücre bloğunun kapladığı toplam genişlik.
  double _blokGenislik(int c, int yk) {
    var t = 0.0;
    for (var i = c; i < c + yk && i < _sutunlar.length; i++) {
      t += _genislik(i);
    }
    return t;
  }

  /// Metne göre satır yüksekliklerini hesaplar (birleştirilmiş hücreler dahil).
  List<double> _satirYukseklikleri(
    List<List<_Hucre>> satirlar,
    List<List<bool>> kapali,
  ) {
    final yuk = List<double>.filled(satirlar.length, _enAzYukseklik);
    // Önce tek satırlık hücreler
    for (var r = 0; r < satirlar.length; r++) {
      for (var c = 0; c < satirlar[r].length; c++) {
        if (kapali[r][c]) continue;
        final h = satirlar[r][c];
        if (h.sk != 1) continue;
        final y = _metinYukseklik(h.d, _blokGenislik(c, h.yk), _hucreStili(h));
        if (y > yuk[r]) yuk[r] = y;
      }
    }
    // Sonra birleştirilmiş hücreler sığmıyorsa son satırı büyüt
    for (var r = 0; r < satirlar.length; r++) {
      for (var c = 0; c < satirlar[r].length; c++) {
        if (kapali[r][c]) continue;
        final h = satirlar[r][c];
        if (h.sk <= 1) continue;
        final y = _metinYukseklik(h.d, _blokGenislik(c, h.yk), _hucreStili(h));
        var toplam = 0.0;
        for (var i = r; i < r + h.sk && i < yuk.length; i++) {
          toplam += yuk[i];
        }
        if (y > toplam) {
          final son = (r + h.sk - 1).clamp(0, yuk.length - 1);
          yuk[son] += y - toplam;
        }
      }
    }
    return yuk;
  }

  /// Birleştirme yüzünden çizilmeyecek hücreleri işaretler.
  List<List<bool>> _kapaliHucreler(List<List<_Hucre>> satirlar) {
    final n = _sutunlar.length;
    final kapali = List.generate(satirlar.length, (_) => List.filled(n, false));
    for (var r = 0; r < satirlar.length; r++) {
      for (var c = 0; c < n; c++) {
        if (kapali[r][c]) continue;
        final h = satirlar[r][c];
        final sk = h.sk.clamp(1, satirlar.length - r);
        final yk = h.yk.clamp(1, n - c);
        for (var i = r; i < r + sk; i++) {
          for (var j = c; j < c + yk; j++) {
            if (i == r && j == c) continue;
            kapali[i][j] = true;
          }
        }
      }
    }
    return kapali;
  }

  // ---------- HÜCRE DÜZENLEME ----------
  void _hucreDuzenleBaslat(int r, int c, _Hucre h) {
    setState(() {
      _duzR = r;
      _duzC = c;
      _hucreC.text = h.d;
      _hucreC.selection = TextSelection(
        baseOffset: 0,
        extentOffset: h.d.length,
      );
    });
    _hucreOdak.requestFocus();
  }

  Future<void> _hucreKaydet() async {
    final r = _duzR, c = _duzC;
    if (r == null || c == null) return;
    final yeniDeger = _hucreC.text;
    setState(() {
      _duzR = null;
      _duzC = null;
    });
    final satirlar = _satirlar;
    if (r >= satirlar.length || c >= satirlar[r].length) return;
    if (satirlar[r][c].d == yeniDeger) return;
    final yeni = _kopya();
    (((yeni['satirlar'] as List)[r] as Map)['h'] as List)[c] =
        (satirlar[r][c].kopya()..d = yeniDeger);
    await _yaz(yeni);
  }

  Future<void> _hucreDegistir(
    int r,
    int c,
    void Function(_Hucre h) islem,
  ) async {
    final yeni = _kopya();
    final h = (((yeni['satirlar'] as List)[r] as Map)['h'] as List)[c] as _Hucre;
    islem(h);
    _birlestirmeleriDuzelt(yeni);
    await _yaz(yeni);
  }

  // ---------- BİRLEŞTİRME ----------
  /// Bu hücreyi üstündeki hücreye katar.
  Future<void> _yukariBirlestir(int r, int c) async {
    final satirlar = _satirlar;
    final kapali = _kapaliHucreler(satirlar);
    // Üstteki bloğun başlangıcını bul
    var ust = r - 1;
    while (ust >= 0 && kapali[ust][c]) {
      ust--;
    }
    if (ust < 0) return;
    final yeni = _kopya();
    final list = yeni['satirlar'] as List;
    final ustH = ((list[ust] as Map)['h'] as List)[c] as _Hucre;
    final buH = ((list[r] as Map)['h'] as List)[c] as _Hucre;
    if (ustH.yk != buH.yk) {
      _uyari('Birleştirilecek hücrelerin genişliği aynı olmalı');
      return;
    }
    if (ustH.d.trim().isEmpty && buH.d.trim().isNotEmpty) ustH.d = buH.d;
    ustH.sk = (r - ust) + buH.sk;
    buH.d = '';
    buH.sk = 1;
    _birlestirmeleriDuzelt(yeni);
    await _yaz(yeni);
  }

  /// Bu hücreyi sağındaki hücreyle birleştirir.
  Future<void> _sagaBirlestir(int r, int c) async {
    final satirlar = _satirlar;
    final buH = satirlar[r][c];
    final sag = c + buH.yk;
    if (sag >= _sutunlar.length) return;
    final sagH = satirlar[r][sag];
    if (sagH.sk != buH.sk) {
      _uyari('Birleştirilecek hücrelerin yüksekliği aynı olmalı');
      return;
    }
    final yeni = _kopya();
    final list = (yeni['satirlar'] as List);
    final a = ((list[r] as Map)['h'] as List)[c] as _Hucre;
    final b = ((list[r] as Map)['h'] as List)[sag] as _Hucre;
    if (a.d.trim().isEmpty && b.d.trim().isNotEmpty) a.d = b.d;
    a.yk = buH.yk + sagH.yk;
    b.d = '';
    b.yk = 1;
    _birlestirmeleriDuzelt(yeni);
    await _yaz(yeni);
  }

  Future<void> _birlestirmeCoz(int r, int c) =>
      _hucreDegistir(r, c, (h) {
        h.sk = 1;
        h.yk = 1;
      });

  void _uyari(String metin) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(metin)));
  }

  // ---------- SATIR / SÜTUN ----------
  Future<void> _satirEkle(int index) async {
    final yeni = _kopya();
    final n = (yeni['sutunlar'] as List).length;
    (yeni['satirlar'] as List).insert(index, {
      'h': List.generate(n, (_) => _Hucre()),
    });
    _birlestirmeleriDuzelt(yeni);
    await _yaz(yeni);
  }

  Future<void> _satirSil(int index) async {
    final onay = await _onay('Satırı sil', 'Bu satır silinsin mi?');
    if (onay != true) return;
    final yeni = _kopya();
    (yeni['satirlar'] as List).removeAt(index);
    _birlestirmeleriDuzelt(yeni);
    await _yaz(yeni);
  }

  Future<void> _sutunSil(int index) async {
    final onay = await _onay(
      'Sütunu sil',
      '"${_ad(index)}" sütunu ve verileri silinsin mi?',
    );
    if (onay != true) return;
    final yeni = _kopya();
    (yeni['sutunlar'] as List).removeAt(index);
    for (final r in (yeni['satirlar'] as List)) {
      final h = (r as Map)['h'] as List;
      if (h.length > index) h.removeAt(index);
    }
    _birlestirmeleriDuzelt(yeni);
    await _yaz(yeni);
  }

  Future<void> _sutunDialog({int? index}) async {
    final duzenle = index != null;
    final adC = TextEditingController(text: duzenle ? _ad(index) : '');
    String tip = duzenle ? _tip(index) : 'metin';

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          title: Text(duzenle ? 'Sütunu Düzenle' : 'Sütun Ekle'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: adC,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Sütun adı',
                    hintText: 'Örn. TİS TEKLİFİ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sütun tipi',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in ['metin', 'sayi', 'tarih'])
                      ChoiceChip(
                        label: Text(
                          t == 'metin'
                              ? 'Metin'
                              : (t == 'sayi' ? 'Sayı' : 'Tarih'),
                        ),
                        selected: tip == t,
                        showCheckmark: false,
                        selectedColor: widget.renk,
                        labelStyle: TextStyle(
                          color: tip == t ? Colors.white : Colors.black87,
                        ),
                        onSelected: (_) => setSt(() => tip = t),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Sayı sütunları varsayılan olarak sağa yaslanır.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dc, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (kaydet != true || adC.text.trim().isEmpty) return;

    final yeni = _kopya();
    final sutunlar = yeni['sutunlar'] as List;
    final satirlar = yeni['satirlar'] as List;

    if (duzenle) {
      sutunlar[index] = {
        'ad': adC.text.trim(),
        'tip': tip,
        'genislik': _genislik(index),
      };
    } else {
      sutunlar.add({
        'ad': adC.text.trim(),
        'tip': tip,
        'genislik': _varsayilanGenislik,
      });
      for (var i = 0; i < satirlar.length; i++) {
        ((satirlar[i] as Map)['h'] as List).add(_Hucre());
      }
    }
    await _yaz(yeni);
  }

  Future<void> _genislikKaydet(int index, double genislik) async {
    final yeni = _kopya();
    final s = (yeni['sutunlar'] as List)[index] as Map;
    s['genislik'] = genislik;
    await _yaz(yeni);
  }

  Future<bool?> _onay(String baslik, String metin) => showDialog<bool>(
    context: context,
    builder: (dc) => AlertDialog(
      title: Text(baslik),
      content: Text(metin),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dc, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(dc, true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );

  // ---------- HÜCRE MENÜSÜ ----------
  Future<void> _hucreMenu(Offset konum, int r, int c, _Hucre h) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final secim = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(konum, konum),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'kalin',
          child: Text(h.k ? 'Kalınlığı kaldır' : 'Kalın yap'),
        ),
        const PopupMenuItem(value: 'renk', child: Text('Arka plan rengi…')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'sol', child: Text('Sola yasla')),
        const PopupMenuItem(value: 'orta', child: Text('Ortala')),
        const PopupMenuItem(value: 'sag', child: Text('Sağa yasla')),
        const PopupMenuDivider(),
        if (r > 0)
          const PopupMenuItem(
            value: 'yukari',
            child: Text('Yukarıdaki hücreyle birleştir'),
          ),
        if (c + h.yk < _sutunlar.length)
          const PopupMenuItem(
            value: 'saga',
            child: Text('Sağdaki hücreyle birleştir'),
          ),
        if (h.sk > 1 || h.yk > 1)
          const PopupMenuItem(value: 'coz', child: Text('Birleştirmeyi çöz')),
        const PopupMenuDivider(),
        if (_tip(c) == 'tarih')
          const PopupMenuItem(value: 'tarih', child: Text('Tarih seç…')),
        const PopupMenuItem(value: 'ustSatir', child: Text('Üste satır ekle')),
        const PopupMenuItem(value: 'altSatir', child: Text('Alta satır ekle')),
        const PopupMenuItem(value: 'satirSil', child: Text('Satırı sil')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'sutunDuzenle', child: Text('Sütunu düzenle')),
        const PopupMenuItem(value: 'sutunSil', child: Text('Sütunu sil')),
      ],
    );
    if (secim == null || !mounted) return;

    switch (secim) {
      case 'kalin':
        await _hucreDegistir(r, c, (x) => x.k = !x.k);
      case 'renk':
        await _renkSec(r, c, h);
      case 'sol':
      case 'orta':
      case 'sag':
        await _hucreDegistir(r, c, (x) => x.hz = secim);
      case 'yukari':
        await _yukariBirlestir(r, c);
      case 'saga':
        await _sagaBirlestir(r, c);
      case 'coz':
        await _birlestirmeCoz(r, c);
      case 'tarih':
        final s = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1950),
          lastDate: DateTime(2100),
        );
        if (s != null) await _hucreDegistir(r, c, (x) => x.d = _tarihMetni(s));
      case 'ustSatir':
        await _satirEkle(r);
      case 'altSatir':
        await _satirEkle(r + 1);
      case 'satirSil':
        await _satirSil(r);
      case 'sutunDuzenle':
        await _sutunDialog(index: c);
      case 'sutunSil':
        await _sutunSil(c);
    }
  }

  Future<void> _renkSec(int r, int c, _Hucre h) async {
    final secim = await renkSecDialog(
      context,
      mevcutSaklanan: h.r,
      vurguRenk: widget.renk,
    );
    if (secim == null) return;
    await _hucreDegistir(r, c, (x) => x.r = secim);
  }

  // ---------- EXCEL (.xlsx) ----------
  String _hizaAdi(_Hucre h, int c) {
    switch (_hizala(h, c)) {
      case TextAlign.center:
        return 'orta';
      case TextAlign.right:
        return 'sag';
      default:
        return 'sol';
    }
  }

  Future<void> _exceleAktar() async {
    final sutunlar = _sutunlar;
    final satirlar = _satirlar;
    if (sutunlar.isEmpty) {
      _uyari('Boş tablo aktarılamaz');
      return;
    }

    final n = sutunlar.length;
    final kapali = _kapaliHucreler(satirlar);
    final yukseklikler = _satirYukseklikleri(satirlar, kapali);

    // Başlık satırı
    var baslikYuk = _enAzYukseklik;
    for (var i = 0; i < n; i++) {
      final y = _metinYukseklik(_ad(i), _genislik(i), _baslikStili);
      if (y > baslikYuk) baslikYuk = y;
    }

    final xlsxSatirlar = <List<XlsxHucre?>>[
      [
        for (var c = 0; c < n; c++)
          XlsxHucre(deger: _ad(c), kalin: true, arkaPlan: 'EFEFEF'),
      ],
    ];

    for (var r = 0; r < satirlar.length; r++) {
      final satir = <XlsxHucre?>[];
      for (var c = 0; c < n; c++) {
        if (kapali[r][c]) {
          satir.add(null);
          continue;
        }
        final h = satirlar[r][c];
        satir.add(
          XlsxHucre(
            deger: h.d,
            kalin: h.k,
            arkaPlan: renkHex(h.r),
            hizalama: _hizaAdi(h, c),
            satirKapla: h.sk.clamp(1, satirlar.length - r),
            sutunKapla: h.yk.clamp(1, n - c),
          ),
        );
      }
      xlsxSatirlar.add(satir);
    }

    final baslik = (widget.tablo['baslik'] ?? 'Tablo').toString();
    final bytes = xlsxUret(
      sayfaAdi: baslik,
      sutunGenislikleri: [for (var i = 0; i < n; i++) _genislik(i)],
      satirYukseklikleri: [baslikYuk, ...yukseklikler],
      satirlar: xlsxSatirlar,
    );

    var dosyaAdi = baslik.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (dosyaAdi.isEmpty) dosyaAdi = 'tablo';

    if (!mounted) return;
    await dosyaKaydet(
      context: context,
      bytes: bytes,
      dosyaAdi: '$dosyaAdi.xlsx',
      dialogBaslik: 'Excel dosyasını kaydet',
    );
  }

  // ---------- ÇİZİM ----------
  TextAlign _hizala(_Hucre h, int c) {
    switch (h.hz) {
      case 'orta':
        return TextAlign.center;
      case 'sag':
        return TextAlign.right;
      case 'sol':
        return TextAlign.left;
    }
    return _tip(c) == 'sayi' ? TextAlign.right : TextAlign.left;
  }

  Alignment _hizaKonum(_Hucre h, int c) {
    switch (_hizala(h, c)) {
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }

  Widget _hucreCiz(int r, int c, _Hucre h, double g, double y) {
    final duzenleniyor = _duzR == r && _duzC == c;
    return GestureDetector(
      onTap: () => _hucreDuzenleBaslat(r, c, h),
      onSecondaryTapDown: (d) => _hucreMenu(d.globalPosition, r, c, h),
      onLongPressStart: (d) => _hucreMenu(d.globalPosition, r, c, h),
      child: Container(
        width: g,
        height: y,
        padding: const EdgeInsets.symmetric(
          horizontal: _yatayBosluk,
          vertical: _dikeyBosluk,
        ),
        decoration: BoxDecoration(
          color: renkCoz(h.r) ?? Colors.white,
          border: Border.all(
            color: duzenleniyor ? widget.renk : Colors.grey.shade300,
            width: duzenleniyor ? 1.6 : _cizgi,
          ),
        ),
        alignment: _hizaKonum(h, c),
        child: duzenleniyor
            ? TextField(
                controller: _hucreC,
                focusNode: _hucreOdak,
                style: _hucreStili(h),
                textAlign: _hizala(h, c),
                maxLines: null,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _hucreKaydet(),
              )
            : Text(h.d, style: _hucreStili(h), textAlign: _hizala(h, c)),
      ),
    );
  }

  Widget _baslikCiz(int c, double g, double y) {
    return SizedBox(
      width: g,
      height: y,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _sutunDialog(index: c),
            onSecondaryTapDown: (_) => _sutunSil(c),
            onLongPress: () => _sutunSil(c),
            child: Container(
              width: g,
              height: y,
              padding: const EdgeInsets.symmetric(
                horizontal: _yatayBosluk,
                vertical: _dikeyBosluk,
              ),
              decoration: BoxDecoration(
                color: widget.renk.withOpacity(0.10),
                border: Border.all(color: Colors.grey.shade300, width: _cizgi),
              ),
              alignment: Alignment.centerLeft,
              child: Text(_ad(c), style: _baslikStili),
            ),
          ),
          // Sütun genişliğini çekme tutamacı
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 10,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) => setState(() {
                  _surukleSutun = c;
                  _surukleGenislik = _genislik(c);
                }),
                onHorizontalDragUpdate: (d) => setState(() {
                  _surukleGenislik = (_surukleGenislik + d.delta.dx).clamp(
                    _enAzGenislik,
                    900.0,
                  );
                }),
                onHorizontalDragEnd: (_) {
                  final g = _surukleGenislik;
                  setState(() => _surukleSutun = null);
                  _genislikKaydet(c, g);
                },
                child: Center(
                  child: Container(width: 2, height: y * 0.5, color: Colors.grey.shade300),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sutunlar = _sutunlar;
    final satirlar = _satirlar;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart_outlined, size: 19, color: widget.renk),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (widget.tablo['baslik'] ?? 'Tablo').toString(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _sutunDialog(),
                  icon: const Icon(Icons.view_column_outlined, size: 17),
                  label: const Text('Sütun', style: TextStyle(fontSize: 12.5)),
                ),
                if (sutunlar.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _satirEkle(satirlar.length),
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('Satır', style: TextStyle(fontSize: 12.5)),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 19,
                    color: Colors.grey,
                  ),
                  onSelected: (x) {
                    if (x == 'excel') _exceleAktar();
                    if (x == 'baslik') widget.onBaslikDuzenle?.call();
                    if (x == 'sil') widget.onTabloSil?.call();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'excel', child: Text('Excel\'e Aktar')),
                    PopupMenuItem(
                      value: 'baslik',
                      child: Text('Başlığı düzenle'),
                    ),
                    PopupMenuItem(value: 'sil', child: Text('Tabloyu sil')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (sutunlar.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Önce "Sütun" ile sütunları tanımlayın',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ),
              )
            else ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _izgara(satirlar),
              ),
              if (satirlar.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Center(
                    child: Text(
                      'Henüz satır yok — "Satır" ile ekleyin',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 2),
                child: Text(
                  'Hücreye tıkla: yaz  •  Sağ tık (telefonda uzun bas): kalın, renk, birleştirme, satır/sütun  •  Sütun kenarını çek: genişlik',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _izgara(List<List<_Hucre>> satirlar) {
    final n = _sutunlar.length;
    final genislikler = List.generate(n, (i) => _genislik(i));
    final toplamGenislik = genislikler.fold<double>(0, (a, b) => a + b);

    // Sütun x konumları
    final x = List<double>.filled(n + 1, 0);
    for (var i = 0; i < n; i++) {
      x[i + 1] = x[i] + genislikler[i];
    }

    // Başlık satırı yüksekliği
    var baslikYuk = _enAzYukseklik;
    for (var i = 0; i < n; i++) {
      final y = _metinYukseklik(_ad(i), genislikler[i], _baslikStili);
      if (y > baslikYuk) baslikYuk = y;
    }

    final kapali = _kapaliHucreler(satirlar);
    final yukseklikler = _satirYukseklikleri(satirlar, kapali);

    // Satır y konumları
    final yk = List<double>.filled(satirlar.length + 1, 0);
    for (var i = 0; i < satirlar.length; i++) {
      yk[i + 1] = yk[i] + yukseklikler[i];
    }
    final toplamYukseklik = yk[satirlar.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: toplamGenislik,
          height: baslikYuk,
          child: Stack(
            children: [
              for (var c = 0; c < n; c++)
                Positioned(
                  left: x[c],
                  top: 0,
                  child: _baslikCiz(c, genislikler[c], baslikYuk),
                ),
            ],
          ),
        ),
        SizedBox(
          width: toplamGenislik,
          height: toplamYukseklik,
          child: Stack(
            children: [
              for (var r = 0; r < satirlar.length; r++)
                for (var c = 0; c < n; c++)
                  if (!kapali[r][c])
                    Positioned(
                      left: x[c],
                      top: yk[r],
                      child: _hucreCiz(
                        r,
                        c,
                        satirlar[r][c],
                        _blokGenislik(c, satirlar[r][c].yk.clamp(1, n - c)),
                        yk[(r + satirlar[r][c].sk).clamp(0, satirlar.length)] -
                            yk[r],
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
