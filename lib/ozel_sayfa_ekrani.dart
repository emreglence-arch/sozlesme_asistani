import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'pdf_goruntuleyici.dart';
import 'paylas.dart';
import 'tablo_widget.dart';

class OzelSayfaEkrani extends StatefulWidget {
  final String sayfaId;
  final String sayfaAdi;
  final Color renk;
  final IconData ikon;

  const OzelSayfaEkrani({
    super.key,
    required this.sayfaId,
    required this.sayfaAdi,
    required this.renk,
    required this.ikon,
  });

  @override
  State<OzelSayfaEkrani> createState() => _OzelSayfaEkraniState();
}

class _Kirinti {
  final String? id;
  final String ad;
  _Kirinti(this.id, this.ad);
}

class _OzelSayfaEkraniState extends State<OzelSayfaEkrani> {
  late List<_Kirinti> _yol;
  bool _yukleniyor = false;

  @override
  void initState() {
    super.initState();
    _yol = [_Kirinti(null, widget.sayfaAdi)];
  }

  String? get _aktifKlasorId => _yol.last.id;

  DocumentReference<Map<String, dynamic>> _sayfaRef() =>
      FirebaseFirestore.instance.collection('ozelSayfalar').doc(widget.sayfaId);

  CollectionReference<Map<String, dynamic>> _klasorlerRef() =>
      _sayfaRef().collection('klasorler');

  CollectionReference<Map<String, dynamic>> _kayitlarRef() =>
      _sayfaRef().collection('kayitlar');

  DocumentReference<Map<String, dynamic>> _icerikRef() =>
      _sayfaRef().collection('icerikler').doc(_aktifKlasorId ?? '_kok');

  String _tarihMetni(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';

  String _boyut(int? b) {
    if (b == null || b == 0) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).round()} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  IconData _dosyaIkon(String ad) {
    final n = ad.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (n.endsWith('.doc') || n.endsWith('.docx')) return Icons.description;
    if (n.endsWith('.xlsx') || n.endsWith('.xls')) return Icons.table_chart;
    if (n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png')) {
      return Icons.image;
    }
    return Icons.insert_drive_file;
  }

  String _ct(String ad) {
    final n = ad.toLowerCase();
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (n.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.png')) return 'image/png';
    return 'application/octet-stream';
  }

  // ---------- METİN ----------
  Future<void> _metinDuzenle(String mevcut) async {
    final c = TextEditingController(text: mevcut);
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Açıklama'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: c,
            autofocus: true,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Bu klasöre dair notlar, açıklamalar...',
              border: OutlineInputBorder(),
            ),
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
    );
    if (kaydet != true) return;
    await _icerikRef().set({'metin': c.text.trim()}, SetOptions(merge: true));
  }

  // ---------- TABLOLAR ----------
  List<Map<String, dynamic>> _tablolar(Map<String, dynamic> icerik) {
    final raw = icerik['tablolar'];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (icerik['tablo'] is Map) {
      final t = Map<String, dynamic>.from(icerik['tablo']);
      t['baslik'] = t['baslik'] ?? 'Tablo';
      return [t];
    }
    return [];
  }

  Future<String?> _baslikSor(String baslangic) {
    final c = TextEditingController(text: baslangic);
    return showDialog<String>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Tablo Başlığı'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: c,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Başlık',
              hintText: 'Örn. 2026 Enflasyon Verileri',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dc, c.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _tabloEkle(List<Map<String, dynamic>> mevcut) async {
    final baslik = await _baslikSor('');
    if (baslik == null || baslik.isEmpty) return;
    final yeni = [
      ...mevcut.map((t) => Map<String, dynamic>.from(t)),
      {'baslik': baslik, 'sutunlar': [], 'satirlar': []},
    ];
    await _icerikRef().set({'tablolar': yeni}, SetOptions(merge: true));
  }

  Future<void> _tabloBaslikDuzenle(
    List<Map<String, dynamic>> mevcut,
    int i,
  ) async {
    final baslik = await _baslikSor((mevcut[i]['baslik'] ?? '').toString());
    if (baslik == null || baslik.isEmpty) return;
    final yeni = mevcut.map((t) => Map<String, dynamic>.from(t)).toList();
    yeni[i]['baslik'] = baslik;
    await _icerikRef().set({'tablolar': yeni}, SetOptions(merge: true));
  }

  Future<void> _tabloSil(List<Map<String, dynamic>> mevcut, int i) async {
    final onay = await _silOnay(
      'Tabloyu sil',
      '"${mevcut[i]['baslik']}" tablosu ve verileri silinsin mi?',
    );
    if (onay != true) return;
    final yeni = mevcut.map((t) => Map<String, dynamic>.from(t)).toList();
    yeni.removeAt(i);
    await _icerikRef().set({'tablolar': yeni}, SetOptions(merge: true));
  }

  Future<void> _tabloKaydet(
    List<Map<String, dynamic>> mevcut,
    int i,
    Map<String, dynamic> t,
  ) async {
    final yeni = mevcut.map((x) => Map<String, dynamic>.from(x)).toList();
    yeni[i] = t;
    await _icerikRef().set({'tablolar': yeni}, SetOptions(merge: true));
  }

  // ---------- KLASÖR ----------
  Future<void> _klasorDialog({
    DocumentSnapshot<Map<String, dynamic>>? mevcut,
  }) async {
    final c = TextEditingController(
      text: (mevcut?.data()?['ad'] ?? '').toString(),
    );
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(
          mevcut == null ? 'Yeni Klasör' : 'Klasörü Yeniden Adlandır',
        ),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: c,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Klasör adı',
              hintText: 'Örn. 2026',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dc, true),
            child: Text(mevcut == null ? 'Oluştur' : 'Kaydet'),
          ),
        ],
      ),
    );

    if (kaydet != true || c.text.trim().isEmpty) return;
    if (mevcut == null) {
      await _klasorlerRef().add({
        'ad': c.text.trim(),
        'ustKlasorId': _aktifKlasorId,
        'olusturma': FieldValue.serverTimestamp(),
      });
    } else {
      await _klasorlerRef().doc(mevcut.id).update({'ad': c.text.trim()});
    }
  }

  Future<void> _klasorSil(String id, String ad) async {
    final onay = await _silOnay(
      'Klasörü sil',
      '"$ad" ve içindeki tüm klasör/kayıtlar silinsin mi?',
    );
    if (onay != true) return;

    Future<void> silAgac(String klasorId) async {
      final altlar = await _klasorlerRef()
          .where('ustKlasorId', isEqualTo: klasorId)
          .get();
      for (final a in altlar.docs) {
        await silAgac(a.id);
      }
      final kayitlar = await _kayitlarRef()
          .where('klasorId', isEqualTo: klasorId)
          .get();
      for (final k in kayitlar.docs) {
        await _kayitDosyaSil(k.data());
        await k.reference.delete();
      }
      try {
        await _sayfaRef().collection('icerikler').doc(klasorId).delete();
      } catch (_) {}
      await _klasorlerRef().doc(klasorId).delete();
    }

    setState(() => _yukleniyor = true);
    await silAgac(id);
    if (mounted) setState(() => _yukleniyor = false);
  }

  // ---------- KAYIT ----------
  Future<void> _kayitDialog({
    DocumentSnapshot<Map<String, dynamic>>? mevcut,
  }) async {
    final v = mevcut?.data() ?? {};
    final baslikC = TextEditingController(text: (v['baslik'] ?? '').toString());
    final aciklamaC = TextEditingController(
      text: (v['aciklama'] ?? '').toString(),
    );
    final etiketC = TextEditingController(text: (v['etiket'] ?? '').toString());
    DateTime tarih = (v['tarih'] as Timestamp?)?.toDate() ?? DateTime.now();

    PlatformFile? yeniDosya;
    bool dosyaKaldirildi = false;

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (context, setSt) {
          final eskiDosyaAdi = (v['dosyaAdi'] ?? '').toString();
          final gosterilenDosya =
              yeniDosya?.name ?? (dosyaKaldirildi ? '' : eskiDosyaAdi);

          return AlertDialog(
            title: Text(mevcut == null ? 'Kayıt Ekle' : 'Kaydı Düzenle'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: baslikC,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Başlık',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: aciklamaC,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama (opsiyonel)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final s = await showDatePicker(
                                context: dc,
                                initialDate: tarih,
                                firstDate: DateTime(1950),
                                lastDate: DateTime(2100),
                              );
                              if (s != null) setSt(() => tarih = s);
                            },
                            icon: const Icon(Icons.event, size: 17),
                            label: Text(
                              _tarihMetni(tarih),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: etiketC,
                            decoration: const InputDecoration(
                              labelText: 'Etiket',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            gosterilenDosya.isEmpty
                                ? Icons.attach_file
                                : _dosyaIkon(gosterilenDosya),
                            size: 20,
                            color: gosterilenDosya.isEmpty
                                ? Colors.grey.shade500
                                : widget.renk,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              gosterilenDosya.isEmpty
                                  ? 'Dosya eklenmedi'
                                  : gosterilenDosya,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: gosterilenDosya.isEmpty
                                    ? Colors.grey.shade600
                                    : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (gosterilenDosya.isNotEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.red,
                              ),
                              onPressed: () => setSt(() {
                                yeniDosya = null;
                                dosyaKaldirildi = true;
                              }),
                            ),
                          TextButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.pickFiles(
                                withData: true,
                              );
                              if (result != null &&
                                  result.files.first.bytes != null) {
                                setSt(() {
                                  yeniDosya = result.files.first;
                                  dosyaKaldirildi = false;
                                });
                              }
                            },
                            icon: const Icon(Icons.upload_file, size: 17),
                            label: Text(
                              gosterilenDosya.isEmpty
                                  ? 'Dosya seç'
                                  : 'Değiştir',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
          );
        },
      ),
    );

    if (kaydet != true || baslikC.text.trim().isEmpty) return;

    setState(() => _yukleniyor = true);
    try {
      final kayit = <String, dynamic>{
        'baslik': baslikC.text.trim(),
        'aciklama': aciklamaC.text.trim(),
        'etiket': etiketC.text.trim(),
        'tarih': Timestamp.fromDate(tarih),
        'klasorId': mevcut == null ? _aktifKlasorId : v['klasorId'],
      };

      if (yeniDosya != null) {
        if (mevcut != null) await _kayitDosyaSil(v);
        final f = yeniDosya!;
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        final ref = FirebaseStorage.instance.ref(
          'ozelSayfalar/${widget.sayfaId}/$id',
        );
        await ref.putData(f.bytes!, SettableMetadata(contentType: _ct(f.name)));
        kayit['url'] = await ref.getDownloadURL();
        kayit['dosyaAdi'] = f.name;
        kayit['boyut'] = f.size;
        kayit['depoYolu'] = ref.fullPath;
      } else if (dosyaKaldirildi && mevcut != null) {
        await _kayitDosyaSil(v);
        kayit['url'] = FieldValue.delete();
        kayit['dosyaAdi'] = FieldValue.delete();
        kayit['boyut'] = FieldValue.delete();
        kayit['depoYolu'] = FieldValue.delete();
      }

      if (mevcut == null) {
        await _kayitlarRef().add(kayit);
      } else {
        await _kayitlarRef().doc(mevcut.id).update(kayit);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _kayitDosyaSil(Map<String, dynamic> v) async {
    final yol = (v['depoYolu'] ?? '').toString();
    if (yol.isEmpty) return;
    try {
      await FirebaseStorage.instance.ref(yol).delete();
    } catch (_) {}
  }

  Future<void> _kayitSil(DocumentSnapshot<Map<String, dynamic>> d) async {
    final v = d.data()!;
    final onay = await _silOnay('Kaydı sil', '"${v['baslik']}" silinsin mi?');
    if (onay != true) return;
    await _kayitDosyaSil(v);
    await _kayitlarRef().doc(d.id).delete();
  }

  Future<void> _dosyaAc(Map<String, dynamic> v) async {
    final url = (v['url'] ?? '').toString();
    if (url.isEmpty) return;
    final ad = (v['dosyaAdi'] ?? '').toString();
    if (ad.toLowerCase().endsWith('.pdf')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfGoruntuleyici(url: url, baslik: ad),
        ),
      );
    } else {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _dosyaIndir(Map<String, dynamic> v) async {
    final ad = (v['dosyaAdi'] ?? 'belge').toString();
    final yol = (v['depoYolu'] ?? '').toString();
    if (yol.isEmpty) return;
    try {
      final hedef = await FilePicker.saveFile(
        dialogTitle: 'Nereye kaydedilsin?',
        fileName: ad,
      );
      if (hedef == null) return;
      final bytes = await FirebaseStorage.instance
          .ref(yol)
          .getData(200 * 1024 * 1024);
      if (bytes == null) throw 'Dosya okunamadı';
      await File(hedef).writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('İndirildi: $ad')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('İndirme hatası: $e')));
      }
    }
  }

  Future<bool?> _silOnay(String baslik, String metin) => showDialog<bool>(
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

  void _klasoreGir(String id, String ad) =>
      setState(() => _yol.add(_Kirinti(id, ad)));

  void _yolaGit(int index) => setState(() => _yol = _yol.sublist(0, index + 1));

  // ---------- EKRAN ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppRenk.arkaPlan,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'klasor',
            onPressed: () => _klasorDialog(),
            backgroundColor: Colors.white,
            foregroundColor: widget.renk,
            tooltip: 'Klasör Ekle',
            child: const Icon(Icons.create_new_folder_outlined),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'kayit',
            onPressed: () => _kayitDialog(),
            backgroundColor: widget.renk,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Kayıt Ekle'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: widget.renk.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(widget.ikon, color: widget.renk, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.sayfaAdi,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_yol.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < _yol.length; i++) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ),
                          InkWell(
                            onTap: i == _yol.length - 1
                                ? null
                                : () => _yolaGit(i),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 3,
                              ),
                              child: Text(
                                _yol[i].ad,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: i == _yol.length - 1
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: i == _yol.length - 1
                                      ? Colors.black87
                                      : widget.renk,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Expanded(child: _icerik()),
            ],
          ),
          if (_yukleniyor)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _icerik() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _icerikRef().snapshots(),
      builder: (context, icerikSnap) {
        final icerik = icerikSnap.data?.data() ?? {};
        final metin = (icerik['metin'] ?? '').toString();
        final tablolar = _tablolar(icerik);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _klasorlerRef()
              .where('ustKlasorId', isEqualTo: _aktifKlasorId)
              .snapshots(),
          builder: (context, klasorSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _kayitlarRef()
                  .where('klasorId', isEqualTo: _aktifKlasorId)
                  .snapshots(),
              builder: (context, kayitSnap) {
                if (!klasorSnap.hasData || !kayitSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final klasorler = klasorSnap.data!.docs.toList()
                  ..sort(
                    (a, b) => (a.data()['ad'] ?? '').toString().compareTo(
                      (b.data()['ad'] ?? '').toString(),
                    ),
                  );

                final kayitlar = kayitSnap.data!.docs.toList()
                  ..sort((a, b) {
                    final ta = (a.data()['tarih'] as Timestamp?)?.toDate();
                    final tb = (b.data()['tarih'] as Timestamp?)?.toDate();
                    if (ta == null || tb == null) return 0;
                    return tb.compareTo(ta);
                  });

                final bosMu =
                    klasorler.isEmpty &&
                    kayitlar.isEmpty &&
                    metin.isEmpty &&
                    tablolar.isEmpty;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                  children: [
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _metinDuzenle(metin),
                          icon: const Icon(Icons.notes, size: 17),
                          label: Text(
                            metin.isEmpty
                                ? 'Açıklama ekle'
                                : 'Açıklamayı düzenle',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _tabloEkle(tablolar),
                          icon: const Icon(
                            Icons.table_chart_outlined,
                            size: 17,
                          ),
                          label: const Text(
                            'Tablo ekle',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (metin.isNotEmpty)
                      Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.notes, size: 19, color: widget.renk),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SelectableText(
                                  metin,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    for (var i = 0; i < tablolar.length; i++)
                      TabloWidget(
                        key: ValueKey('tablo_${_aktifKlasorId}_$i'),
                        tablo: tablolar[i],
                        renk: widget.renk,
                        onDegisti: (t) => _tabloKaydet(tablolar, i, t),
                        onBaslikDuzenle: () => _tabloBaslikDuzenle(tablolar, i),
                        onTabloSil: () => _tabloSil(tablolar, i),
                      ),

                    ...klasorler.map((k) => _klasorKarti(k)),
                    if (klasorler.isNotEmpty && kayitlar.isNotEmpty)
                      const SizedBox(height: 14),
                    ...kayitlar.map((k) => _kayitKarti(k)),

                    if (bosMu)
                      Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: _bosDurum(),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _klasorKarti(DocumentSnapshot<Map<String, dynamic>> k) {
    final ad = (k.data()!['ad'] ?? '').toString();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(Icons.folder, color: widget.renk, size: 32),
        title: Text(ad, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
              onSelected: (x) {
                if (x == 'ad') _klasorDialog(mevcut: k);
                if (x == 'sil') _klasorSil(k.id, ad);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'ad', child: Text('Yeniden adlandır')),
                PopupMenuItem(value: 'sil', child: Text('Sil')),
              ],
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: () => _klasoreGir(k.id, ad),
      ),
    );
  }

  Widget _kayitKarti(DocumentSnapshot<Map<String, dynamic>> d) {
    final v = d.data()!;
    final baslik = (v['baslik'] ?? '').toString();
    final aciklama = (v['aciklama'] ?? '').toString();
    final etiket = (v['etiket'] ?? '').toString();
    final dosyaAdi = (v['dosyaAdi'] ?? '').toString();
    final tarih = (v['tarih'] as Timestamp?)?.toDate();
    final boyut = _boyut(v['boyut'] as int?);
    final dosyaVar = dosyaAdi.isNotEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: dosyaVar ? () => _dosyaAc(v) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                dosyaVar ? _dosyaIkon(dosyaAdi) : Icons.notes,
                color: widget.renk,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (etiket.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.renk.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              etiket,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: widget.renk,
                              ),
                            ),
                          ),
                        if (etiket.isNotEmpty && tarih != null)
                          const SizedBox(width: 8),
                        if (tarih != null)
                          Text(
                            _tarihMetni(tarih),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      baslik,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    if (aciklama.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        aciklama,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    if (dosyaVar) ...[
                      const SizedBox(height: 3),
                      Text(
                        boyut.isEmpty ? dosyaAdi : '$dosyaAdi  •  $boyut',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                onSelected: (x) {
                  if (x == 'ac') _dosyaAc(v);
                  if (x == 'indir') _dosyaIndir(v);
                  if (x == 'paylas') {
                    final url = (v['url'] ?? '').toString();
                    Paylas.menu(
                      context,
                      url.isEmpty ? '$baslik\n$aciklama' : '$baslik\n$url',
                    );
                  }
                  if (x == 'duzenle') _kayitDialog(mevcut: d);
                  if (x == 'sil') _kayitSil(d);
                },
                itemBuilder: (context) => [
                  if (dosyaVar)
                    const PopupMenuItem(value: 'ac', child: Text('Aç')),
                  if (dosyaVar)
                    const PopupMenuItem(value: 'indir', child: Text('İndir')),
                  const PopupMenuItem(value: 'paylas', child: Text('Paylaş')),
                  const PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
                  const PopupMenuItem(value: 'sil', child: Text('Sil')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bosDurum() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open, size: 68, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            _yol.length > 1 ? 'Bu klasör boş' : 'Henüz içerik yok',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            'Sağ alttan klasör veya kayıt ekleyin',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
