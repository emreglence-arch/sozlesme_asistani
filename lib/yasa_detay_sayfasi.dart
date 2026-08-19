import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'pdf_goruntuleyici.dart';
import 'paylas.dart';
import 'ayarlar_servisi.dart';

class YasaDetaySayfasi extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> yasaRef;
  final String yasaAdi;

  const YasaDetaySayfasi({
    super.key,
    required this.yasaRef,
    required this.yasaAdi,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(yasaAdi),
          backgroundColor: AppRenk.indigo,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: AppRenk.amber,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.article_outlined), text: 'Metin'),
              Tab(icon: Icon(Icons.auto_awesome), text: 'Asistan'),
              Tab(icon: Icon(Icons.folder_outlined), text: 'Belgeler'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            YasaMetinSekmesi(yasaRef: yasaRef),
            YasaAsistanSekmesi(yasaRef: yasaRef, yasaAdi: yasaAdi),
            YasaBelgelerSekmesi(yasaRef: yasaRef),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// METİN SEKMESİ
// ============================================================
class YasaMetinSekmesi extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> yasaRef;
  const YasaMetinSekmesi({super.key, required this.yasaRef});

  @override
  State<YasaMetinSekmesi> createState() => _YasaMetinSekmesiState();
}

class _YasaMetinSekmesiState extends State<YasaMetinSekmesi> {
  final bool _islemde = false;
  String _arama = '';

  List<Map<String, dynamic>> _maddeler(Map<String, dynamic> veri) {
    final raw = veri['maddeler'];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> _kaydet(List<Map<String, dynamic>> m) =>
      widget.yasaRef.update({'maddeler': m});
  Future<void> _duzKaydet(String metin) =>
      widget.yasaRef.update({'duzMetin': metin, 'maddeler': []});

  Future<void> _duzTemizle() => widget.yasaRef.update({'duzMetin': ''});

  Future<void> _duzYapistir(String mevcutDuz) async {
    final c = TextEditingController(text: mevcutDuz);
    final metin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Düz Metin'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: c,
            autofocus: true,
            maxLines: 16,
            decoration: const InputDecoration(
              hintText: 'Yasa metnini olduğu gibi buraya yapıştırın. Bölünmez.',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (metin == null) return;
    await _duzKaydet(metin.trim());
  }

  List<Map<String, dynamic>> _bolumle(String metin) {
    final satirlar = metin.replaceAll('\r', '').split('\n');
    final sonuc = <Map<String, dynamic>>[];
    String currentBolum = '';
    Map<String, dynamic>? current;
    final buf = StringBuffer();

    // "MADDE 12", "Madde 12", "MADDE 12 -", "MADDE 12/A" gibi başları yakalar.
    // Grup 1: madde numarası (12, 12/A). Kalan: satırın devamı (metin/başlık).
    final maddeRe = RegExp(
      r'^\s*madde\s*([0-9]+(?:/[A-Za-zÇĞİÖŞÜçğıöşü]+)?)\s*[-–—.:]?\s*(.*)$',
      caseSensitive: false,
    );
    final bolumRe = RegExp(
      r'^\s*\d+\s*\.?\s*(BÖLÜM|KISIM)',
      caseSensitive: false,
    );

    // Bir metnin gerçek başlık olup olmadığını anlar.
    // Başlık: kısa, cümle noktalaması yok. Değilse null.
    String? baslikMi(String s) {
      final t = s.trim();
      if (t.isEmpty) return null;
      if (RegExp(r'[.!?]').hasMatch(t)) return null; // cümle
      if (t.length > 60) return null; // çok uzun
      if (t.split(RegExp(r'\s+')).length > 8) return null; // çok kelime
      if (RegExp(r'^(\(\d+\)|\d+[\.\)]|[a-zçğıöşü]\))').hasMatch(t)) {
        return null; // paragraf numarasıyla başlıyor
      }
      return t;
    }

    void kapat() {
      if (current != null) current['icerik'] = buf.toString().trim();
      buf.clear();
    }

    for (final ham in satirlar) {
      final satir = ham.trim();

      if (bolumRe.hasMatch(satir)) {
        kapat();
        current = null;
        currentBolum = satir;
        continue;
      }

      final m = maddeRe.firstMatch(satir);
      if (m != null) {
        kapat();
        final no = m.group(1) ?? '';
        final kalan = (m.group(2) ?? '').trim();
        final olasiBaslik = baslikMi(kalan);

        // Başlık: "MADDE 12" + (varsa gerçek başlık)
        final baslik = olasiBaslik == null
            ? 'MADDE $no'
            : 'MADDE $no - $olasiBaslik';

        current = {'bolum': currentBolum, 'baslik': baslik, 'icerik': ''};
        sonuc.add(current);

        // Kalan gerçek başlık DEĞİLSE, o satır aslında metnin ilk cümlesidir
        if (olasiBaslik == null && kalan.isNotEmpty) {
          buf.writeln(kalan);
        }
        continue;
      }

      if (current != null) buf.writeln(ham);
    }
    kapat();
    return sonuc;
  }

  Future<void> _yapistir(List<Map<String, dynamic>> mevcut) async {
    final c = TextEditingController();
    final metin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yasa Metnini Yapıştır'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: c,
            autofocus: true,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText:
                  'Yasa metnini buraya yapıştırın.\nMADDE 1, MADDE 2... şeklindeki başlıklara göre bölünür.',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Maddelere Böl'),
          ),
        ],
      ),
    );
    if (metin == null || metin.trim().isEmpty) return;
    if (mevcut.isNotEmpty) {
      final ok = await _onay(
        'Maddeleri yenile',
        'Mevcut maddelerin üzerine yazılacak. Devam edilsin mi?',
      );
      if (ok != true) return;
    }
    final maddeler = _bolumle(metin);
    if (maddeler.isEmpty) {
      _bilgi('Metinde "MADDE" başlığı bulunamadı.');
      return;
    }
    await _kaydet(maddeler);
    _bilgi('${maddeler.length} madde oluşturuldu.');
  }

  Future<void> _maddeDialog(
    List<Map<String, dynamic>> mevcut, {
    int? index,
  }) async {
    final duzenle = index != null;
    final m = duzenle ? mevcut[index] : null;
    final bolumC = TextEditingController(text: m?['bolum']?.toString() ?? '');
    final baslikC = TextEditingController(text: m?['baslik']?.toString() ?? '');
    final icerikC = TextEditingController(text: m?['icerik']?.toString() ?? '');

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(duzenle ? 'Maddeyi Düzenle' : 'Madde Ekle'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: bolumC,
                  decoration: const InputDecoration(
                    labelText: 'Bölüm/Kısım (opsiyonel)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: baslikC,
                  decoration: const InputDecoration(
                    labelText: 'Madde başlığı',
                    hintText: 'Örn. MADDE 18 - Feshin geçerli sebebe...',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: icerikC,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Madde metni',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (kaydet != true || baslikC.text.trim().isEmpty) return;
    final yeni = mevcut.map((e) => Map<String, dynamic>.from(e)).toList();
    final kayit = {
      'bolum': bolumC.text.trim(),
      'baslik': baslikC.text.trim(),
      'icerik': icerikC.text.trim(),
    };
    if (duzenle) {
      yeni[index] = kayit;
    } else {
      yeni.add(kayit);
    }
    await _kaydet(yeni);
  }

  Future<void> _tumunuSil() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Tüm metni sil'),
        content: const Text(
          'Bu yasanın tüm maddeleri ve düz metni silinecek. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dc, true),
            child: const Text('Hepsini Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.yasaRef.update({'maddeler': [], 'duzMetin': ''});
    _bilgi('Tüm metin silindi.');
  }

  Future<void> _maddeSil(List<Map<String, dynamic>> mevcut, int index) async {
    final ok = await _onay('Maddeyi sil', 'Bu madde silinsin mi?');
    if (ok != true) return;
    final yeni = mevcut.map((e) => Map<String, dynamic>.from(e)).toList();
    yeni.removeAt(index);
    await _kaydet(yeni);
  }

  Future<bool?> _onay(String baslik, String metin) => showDialog<bool>(
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
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Devam'),
        ),
      ],
    ),
  );

  void _bilgi(String metin) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(metin)));
  }

  List<int> _filtreliIndeksler(List<Map<String, dynamic>> maddeler) {
    final sonuc = <int>[];
    for (var i = 0; i < maddeler.length; i++) {
      if (_arama.isEmpty) {
        sonuc.add(i);
        continue;
      }
      final m = maddeler[i];
      final hepsi =
          '${m['baslik'] ?? ''} ${m['icerik'] ?? ''} ${m['bolum'] ?? ''}'
              .toLowerCase();
      if (hepsi.contains(_arama)) sonuc.add(i);
    }
    return sonuc;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.yasaRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final veri = snapshot.data!.data() ?? {};
        final maddeler = _maddeler(veri);
        final indeksler = _filtreliIndeksler(maddeler);

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _yapistir(maddeler),
                      icon: const Icon(Icons.content_paste, size: 18),
                      label: const Text('Metni Yapıştır'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _maddeDialog(maddeler),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Madde Ekle'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _duzYapistir((veri['duzMetin'] ?? '').toString()),
                      icon: const Icon(Icons.notes, size: 18),
                      label: const Text('Düz Metin'),
                    ),
                    if (maddeler.isNotEmpty ||
                        (veri['duzMetin'] ?? '').toString().trim().isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _tumunuSil,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        label: const Text('Tümünü Sil'),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (maddeler.isNotEmpty)
                  TextField(
                    onChanged: (v) => setState(() => _arama = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Madde ara',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                if ((veri['duzMetin'] ?? '').toString().trim().isNotEmpty)
                  _duzKart((veri['duzMetin'] ?? '').toString())
                else if (maddeler.isEmpty)
                  _bosDurum()
                else if (indeksler.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        '"$_arama" için sonuç yok',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                else ...[
                  if (_arama.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 4),
                      child: Text(
                        '${indeksler.length} madde bulundu',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ..._grupluListe(maddeler, indeksler),
                ],
              ],
            ),
            if (_islemde)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _duzKart(String metin) {
    final gorunur = _arama.isEmpty || metin.toLowerCase().contains(_arama);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.article, size: 18, color: AppRenk.indigo),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Yasa Metni',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Düzenle',
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 19,
                    color: AppRenk.indigo,
                  ),
                  onPressed: () => _duzYapistir(metin),
                ),
                IconButton(
                  tooltip: 'Paylaş',
                  icon: const Icon(
                    Icons.share_outlined,
                    size: 19,
                    color: Colors.grey,
                  ),
                  onPressed: () => Paylas.menu(context, metin),
                ),
                IconButton(
                  tooltip: 'Sil',
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: Colors.red,
                  ),
                  onPressed: () async {
                    final ok = await _onay(
                      'Metni sil',
                      'Düz metin silinsin mi?',
                    );
                    if (ok == true) _duzTemizle();
                  },
                ),
              ],
            ),
            const Divider(),
            if (!gorunur)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    '"$_arama" bu metinde geçmiyor',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else
              SelectableText(
                metin,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.grey.shade800,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bosDurum() => Padding(
    padding: const EdgeInsets.only(top: 50),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gavel, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            'Henüz madde yok',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            'Yasa metnini yapıştır ya da elle madde ekle',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    ),
  );

  List<Widget> _grupluListe(
    List<Map<String, dynamic>> maddeler,
    List<int> indeksler,
  ) {
    final widgets = <Widget>[];
    String? sonBolum;
    for (final i in indeksler) {
      final m = maddeler[i];
      final bolum = (m['bolum'] ?? '').toString();
      if (bolum != sonBolum) {
        sonBolum = bolum;
        if (bolum.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
              child: Text(
                bolum,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppRenk.indigo,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }
      }
      widgets.add(_maddeKarti(maddeler, i));
    }
    return widgets;
  }

  Widget _maddeKarti(List<Map<String, dynamic>> maddeler, int i) {
    final m = maddeler[i];
    final baslik = (m['baslik'] ?? '').toString();
    final icerik = (m['icerik'] ?? '').toString();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('madde_$i'),
          initiallyExpanded: _arama.isNotEmpty,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            baslik,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                icerik.isEmpty ? '(içerik yok)' : icerik,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => Paylas.menu(context, '$baslik\n\n$icerik'),
                  icon: const Icon(Icons.share_outlined, size: 17),
                  label: const Text('Paylaş'),
                ),
                TextButton.icon(
                  onPressed: () => _maddeDialog(maddeler, index: i),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Düzenle'),
                ),
                TextButton.icon(
                  onPressed: () => _maddeSil(maddeler, i),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.delete_outline, size: 17),
                  label: const Text('Sil'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ASİSTAN SEKMESİ
// ============================================================
class YasaAsistanSekmesi extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> yasaRef;
  final String yasaAdi;
  const YasaAsistanSekmesi({
    super.key,
    required this.yasaRef,
    required this.yasaAdi,
  });

  @override
  State<YasaAsistanSekmesi> createState() => _YasaAsistanSekmesiState();
}

class _AsMesaj {
  final String metin;
  final bool benden;
  _AsMesaj(this.metin, this.benden);
}

class _YasaAsistanSekmesiState extends State<YasaAsistanSekmesi> {
  final _soruC = TextEditingController();
  final _kaydirma = ScrollController();
  final List<_AsMesaj> _mesajlar = [];
  bool _bekleniyor = false;
  String? _anahtar;
  bool _hazir = false;

  @override
  void initState() {
    super.initState();
    _anahtarKontrol();
  }

  Future<void> _anahtarKontrol() async {
    final a = await AyarlarServisi.anahtarAl();
    if (mounted) {
      setState(() {
        _anahtar = a;
        _hazir = true;
      });
    }
  }

  Future<String> _baglamHazirla() async {
    final snap = await widget.yasaRef.get();
    final veri = snap.data() ?? {};
    final buf = StringBuffer();
    buf.writeln('YASA: ${widget.yasaAdi}');
    buf.writeln();
    final duz = (veri['duzMetin'] ?? '').toString();
    if (duz.trim().isNotEmpty) {
      buf.writeln(duz);
    }
    final maddeler = veri['maddeler'];
    if (maddeler is List) {
      for (final m in maddeler) {
        final mad = Map<String, dynamic>.from(m as Map);
        final bolum = (mad['bolum'] ?? '').toString();
        final baslik = (mad['baslik'] ?? '').toString();
        final icerik = (mad['icerik'] ?? '').toString();
        buf.writeln('\n--- $baslik ${bolum.isNotEmpty ? "($bolum)" : ""}');
        buf.writeln(icerik);
      }
    }
    return buf.toString();
  }

  Future<void> _sor(String soru) async {
    if (soru.trim().isEmpty || _bekleniyor || _anahtar == null) return;
    setState(() {
      _mesajlar.add(_AsMesaj(soru.trim(), true));
      _bekleniyor = true;
    });
    _soruC.clear();
    _asagiKaydir();

    try {
      final baglam = await _baglamHazirla();
      final sistem =
          '''
Sen bir hukuk uzmanısın. Aşağıda bir yasanın tam metni verilmiştir. Kullanıcının sorularını SADECE bu yasaya dayanarak yanıtla.

KURALLAR:
- Cevabında mutlaka dayandığın madde numarasını belirt. Örnek: "(Madde 18)"
- Yasada olmayan bir şey sorulursa "Bu yasada bu konuda hüküm bulamadım" de. Tahmin etme.
- Türkçe, açık ve net yanıtla. Gerektiğinde maddeyi kısaca açıkla.

=== YASA METNİ ===
$baglam
=== METİN SONU ===
''';
      final contents = <Map<String, dynamic>>[];
      for (final m in _mesajlar) {
        contents.add({
          'role': m.benden ? 'user' : 'model',
          'parts': [
            {'text': m.metin},
          ],
        });
      }

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_anahtar',
      );
      final yanit = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {
            'parts': [
              {'text': sistem},
            ],
          },
          'contents': contents,
          'generationConfig': {'temperature': 0.2},
        }),
      );

      if (yanit.statusCode != 200) {
        throw 'API hatası (${yanit.statusCode}): ${yanit.body}';
      }
      final json = jsonDecode(utf8.decode(yanit.bodyBytes));
      final metin =
          json['candidates']?[0]?['content']?['parts']?[0]?['text']
              ?.toString() ??
          'Yanıt alınamadı.';
      if (mounted) setState(() => _mesajlar.add(_AsMesaj(metin.trim(), false)));
    } catch (e) {
      if (mounted) setState(() => _mesajlar.add(_AsMesaj('Hata: $e', false)));
    } finally {
      if (mounted) setState(() => _bekleniyor = false);
      _asagiKaydir();
    }
  }

  void _asagiKaydir() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_kaydirma.hasClients) {
        _kaydirma.animateTo(
          _kaydirma.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hazir) return const Center(child: CircularProgressIndicator());
    if (_anahtar == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.key_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'API anahtarı gerekli',
                style: TextStyle(fontSize: 17, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 6),
              Text(
                'Ayarlar > AI API Anahtarı bölümünden anahtarınızı girin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _anahtarKontrol,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Yeniden kontrol et'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _mesajlar.isEmpty
              ? _bosDurum()
              : ListView.builder(
                  controller: _kaydirma,
                  padding: const EdgeInsets.all(16),
                  itemCount: _mesajlar.length + (_bekleniyor ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == _mesajlar.length) return _yaziliyor();
                    return _balon(_mesajlar[i]);
                  },
                ),
        ),
        _girisAlani(),
      ],
    );
  }

  Widget _bosDurum() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 20),
      Icon(Icons.balance, size: 56, color: AppRenk.indigo.withOpacity(0.5)),
      const SizedBox(height: 14),
      const Center(
        child: Text(
          'Hukuki Asistan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 6),
      Center(
        child: Text(
          'Bu yasa hakkında soru sorun.\nCevaplar madde numaralarıyla birlikte gelir.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ),
    ],
  );

  Widget _balon(_AsMesaj m) {
    return Align(
      alignment: m.benden ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: m.benden ? AppRenk.indigo : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              m.metin,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: m.benden ? Colors.white : Colors.black87,
              ),
            ),
            if (!m.benden)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  onTap: () => Paylas.menu(context, m.metin),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.share_outlined,
                        size: 15,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Paylaş',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _yaziliyor() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Yasa inceleniyor...',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    ),
  );

  Widget _girisAlani() => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    color: AppRenk.arkaPlan,
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _soruC,
            enabled: !_bekleniyor,
            onSubmitted: _sor,
            textInputAction: TextInputAction.send,
            decoration: InputDecoration(
              hintText: 'Yasaya dair bir soru sorun...',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _bekleniyor ? null : () => _sor(_soruC.text),
          style: FilledButton.styleFrom(
            backgroundColor: AppRenk.indigo,
            padding: const EdgeInsets.all(16),
          ),
          child: const Icon(Icons.send, size: 20),
        ),
      ],
    ),
  );
}

// ============================================================
// BELGELER SEKMESİ
// ============================================================
class YasaBelgelerSekmesi extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> yasaRef;
  const YasaBelgelerSekmesi({super.key, required this.yasaRef});

  @override
  State<YasaBelgelerSekmesi> createState() => _YasaBelgelerSekmesiState();
}

class _YasaBelgelerSekmesiState extends State<YasaBelgelerSekmesi> {
  String? _yukleniyor;

  String _depoYolu(String tur) => 'yasalar/${widget.yasaRef.id}/$tur';

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
      final ct = tur == 'pdf'
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      await ref.putData(secilen.bytes!, SettableMetadata(contentType: ct));
      final url = await ref.getDownloadURL();
      await widget.yasaRef.update({'${tur}Url': url, '${tur}Ad': secilen.name});
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

  Future<void> _sil(String tur) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Belgeyi sil'),
        content: const Text('Bu belge silinsin mi?'),
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
    if (onay != true) return;
    try {
      await FirebaseStorage.instance.ref(_depoYolu(tur)).delete();
    } catch (_) {}
    await widget.yasaRef.update({
      '${tur}Url': FieldValue.delete(),
      '${tur}Ad': FieldValue.delete(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.yasaRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final veri = snapshot.data!.data() ?? {};
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Yasa Belgeleri',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _belgeKarti(
              tur: 'pdf',
              baslik: 'Yasa Metni (PDF)',
              ikon: Icons.picture_as_pdf,
              renk: Colors.red,
              url: veri['pdfUrl'] as String?,
              ad: veri['pdfAd'] as String?,
            ),
            const SizedBox(height: 12),
            _belgeKarti(
              tur: 'word',
              baslik: 'Word Belgesi',
              ikon: Icons.description,
              renk: Colors.blue,
              url: veri['wordUrl'] as String?,
              ad: veri['wordAd'] as String?,
            ),
          ],
        );
      },
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
                    onPressed: () {
                      if (tur == 'pdf') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PdfGoruntuleyici(
                              url: url,
                              baslik: ad ?? 'Yasa',
                            ),
                          ),
                        );
                      } else {
                        _indir(tur, ad);
                      }
                    },
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
                    onPressed: () => _sil(tur),
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
