import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:archive/archive.dart';
import 'main.dart';
import 'paylas.dart';

class DonemMaddelerSekmesi extends StatefulWidget {
  final String isyeriId;
  final String donemId;

  const DonemMaddelerSekmesi({
    super.key,
    required this.isyeriId,
    required this.donemId,
  });

  @override
  State<DonemMaddelerSekmesi> createState() => _DonemMaddelerSekmesiState();
}

class _DonemMaddelerSekmesiState extends State<DonemMaddelerSekmesi> {
  bool _islemde = false;
  String _arama = '';

  DocumentReference<Map<String, dynamic>> _donemRef() => FirebaseFirestore
      .instance
      .collection('isyerleri')
      .doc(widget.isyeriId)
      .collection('donemler')
      .doc(widget.donemId);

  List<Map<String, dynamic>> _maddeler(Map<String, dynamic> veri) {
    final raw = veri['maddeler'];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> _kaydet(List<Map<String, dynamic>> m) =>
      _donemRef().update({'maddeler': m});

  // ---------- METNİ MADDELERE BÖL ----------
  List<Map<String, dynamic>> _bolumle(String metin) {
    final satirlar = metin.replaceAll('\r', '').split('\n');
    final sonuc = <Map<String, dynamic>>[];
    String currentBolum = '';
    Map<String, dynamic>? current;
    final buf = StringBuffer();

    final maddeRe = RegExp(r'^\s*MADDE\s*\d+', caseSensitive: false);
    final bolumRe = RegExp(r'^\s*\d+\s*\.?\s*BÖLÜM', caseSensitive: false);

    void kapat() {
      if (current != null) {
        current!['icerik'] = buf.toString().trim();
      }
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
      if (maddeRe.hasMatch(satir)) {
        kapat();
        current = {'bolum': currentBolum, 'baslik': satir, 'icerik': ''};
        sonuc.add(current!);
        continue;
      }
      if (current != null) {
        buf.writeln(ham);
      } else if (satir.isNotEmpty &&
          currentBolum.isNotEmpty &&
          satir.length < 60 &&
          satir == satir.toUpperCase() &&
          !currentBolum.contains(satir)) {
        currentBolum = '$currentBolum - $satir';
      }
    }
    kapat();
    return sonuc;
  }

  // ---------- WORD (.docx) METNİNİ ÇIKAR ----------
  String _docxToText(Uint8List bytes) {
    final arsiv = ZipDecoder().decodeBytes(bytes);
    final dosya = arsiv.files.firstWhere((f) => f.name == 'word/document.xml');
    var xml = utf8.decode(dosya.content as List<int>);
    xml = xml
        .replaceAll('</w:p>', '\n')
        .replaceAll('<w:br/>', '\n')
        .replaceAll('<w:tab/>', '\t');
    xml = xml.replaceAll(RegExp(r'<[^>]+>'), '');
    xml = xml
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
    xml = xml.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!)),
    );
    return xml;
  }

  // ---------- YÖNTEM 1: WORD'DEN ----------
  Future<void> _wordDen(List<Map<String, dynamic>> mevcut) async {
    if (mevcut.isNotEmpty) {
      final ok = await _onay(
        'Maddeleri yenile',
        'Mevcut maddelerin üzerine Word\'den gelenler yazılacak. Devam edilsin mi?',
      );
      if (ok != true) return;
    }
    setState(() => _islemde = true);
    try {
      final ref = FirebaseStorage.instance.ref(
        'sozlesmeler/${widget.isyeriId}/${widget.donemId}/word',
      );
      final bytes = await ref.getData(60 * 1024 * 1024);
      if (bytes == null) throw 'Word dosyası bulunamadı.';
      String metin;
      try {
        metin = _docxToText(bytes);
      } catch (_) {
        throw 'Bu dosya .docx değil (eski .doc olabilir). Lütfen .docx yükleyin ya da "Metni Yapıştır"ı kullanın.';
      }
      final maddeler = _bolumle(metin);
      if (maddeler.isEmpty) {
        throw 'Metinde "MADDE" başlığı bulunamadı.';
      }
      await _kaydet(maddeler);
      _bilgi('${maddeler.length} madde oluşturuldu.');
    } catch (e) {
      _bilgi('$e');
    } finally {
      if (mounted) setState(() => _islemde = false);
    }
  }

  // ---------- YÖNTEM 2: YAPIŞTIR ----------
  Future<void> _yapistir(List<Map<String, dynamic>> mevcut) async {
    final c = TextEditingController();
    final metin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Metni Yapıştır'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: c,
            autofocus: true,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText:
                  'Sözleşme metnini buraya yapıştırın.\n(Word\'de Ctrl+A ile seç, Ctrl+C ile kopyala)',
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

  // ---------- YÖNTEM 3: ELLE EKLE / DÜZENLE ----------
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
                    labelText: 'Bölüm (opsiyonel)',
                    hintText: 'Örn. 4. BÖLÜM - ÜCRETLER VE SOSYAL HAKLAR',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: baslikC,
                  decoration: const InputDecoration(
                    labelText: 'Madde başlığı',
                    hintText: 'Örn. MADDE 37 - ÜCRETLER, SOSYAL HAKLAR',
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

    if (kaydet != true) return;
    if (baslikC.text.trim().isEmpty) return;

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

  Future<void> _maddeSil(List<Map<String, dynamic>> mevcut, int index) async {
    final ok = await _onay('Maddeyi sil', 'Bu madde silinsin mi?');
    if (ok != true) return;
    final yeni = mevcut.map((e) => Map<String, dynamic>.from(e)).toList();
    yeni.removeAt(index);
    await _kaydet(yeni);
  }

  // ---------- YARDIMCI ----------
  Future<bool?> _onay(String baslik, String metin) {
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Devam'),
          ),
        ],
      ),
    );
  }

  void _bilgi(String metin) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(metin)));
  }

  // Aramaya uyan maddelerin ORİJİNAL sıra numaralarını döner
  List<int> _filtreliIndeksler(List<Map<String, dynamic>> maddeler) {
    final sonuc = <int>[];
    for (var i = 0; i < maddeler.length; i++) {
      if (_arama.isEmpty) {
        sonuc.add(i);
        continue;
      }
      final m = maddeler[i];
      final baslik = (m['baslik'] ?? '').toString().toLowerCase();
      final icerik = (m['icerik'] ?? '').toString().toLowerCase();
      final bolum = (m['bolum'] ?? '').toString().toLowerCase();
      if (baslik.contains(_arama) ||
          icerik.contains(_arama) ||
          bolum.contains(_arama)) {
        sonuc.add(i);
      }
    }
    return sonuc;
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
        final maddeler = _maddeler(veri);
        final wordVar = veri['wordUrl'] != null;
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
                    FilledButton.icon(
                      onPressed: wordVar
                          ? () => _wordDen(maddeler)
                          : () => _bilgi(
                              'Önce "Belgeler" sekmesinden Word dosyası yükleyin.',
                            ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppRenk.indigo,
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Word\'den Oluştur'),
                    ),
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
                  ],
                ),
                const SizedBox(height: 14),
                if (maddeler.isNotEmpty)
                  TextField(
                    onChanged: (v) => setState(() => _arama = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Madde ara (başlık veya içerik)',
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
                if (maddeler.isEmpty)
                  _bosDurum()
                else if (indeksler.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 54,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '"$_arama" için sonuç yok',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
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

  Widget _bosDurum() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Henüz madde yok',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              'Word\'den oluştur, metni yapıştır ya da elle ekle',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

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
