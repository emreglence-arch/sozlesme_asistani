import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'pdf_goruntuleyici.dart';
import 'paylas.dart';

const _paletRenkler = [
  AppRenk.emerald,
  AppRenk.indigo,
  AppRenk.amber,
  Colors.red,
  Colors.purple,
  Colors.teal,
  Colors.blueGrey,
];

Color turRenk(String tur) {
  if (tur.isEmpty) return Colors.blueGrey;
  var h = 0;
  for (final c in tur.codeUnits) {
    h = (h + c) % 1000;
  }
  return _paletRenkler[h % _paletRenkler.length];
}

class DonemEkBelgeler extends StatefulWidget {
  final String isyeriId;
  final String donemId;

  const DonemEkBelgeler({
    super.key,
    required this.isyeriId,
    required this.donemId,
  });

  @override
  State<DonemEkBelgeler> createState() => _DonemEkBelgelerState();
}

class _DonemEkBelgelerState extends State<DonemEkBelgeler> {
  bool _yukleniyor = false;
  List<String> _ustBaslikOneri = [];
  List<String> _turOneri = [];

  static const _genel = 'Genel';

  CollectionReference<Map<String, dynamic>> _ref() => FirebaseFirestore.instance
      .collection('isyerleri')
      .doc(widget.isyeriId)
      .collection('donemler')
      .doc(widget.donemId)
      .collection('ekBelgeler');

  String _boyut(int? b) {
    if (b == null || b == 0) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).round()} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _tarih(Timestamp? t) {
    if (t == null) return '';
    final d = t.toDate();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _ct(String ad) {
    final n = ad.toLowerCase();
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.doc')) return 'application/msword';
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

  IconData _ikon(String ad) {
    final n = ad.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (n.endsWith('.doc') || n.endsWith('.docx')) return Icons.description;
    if (n.endsWith('.xlsx') || n.endsWith('.xls')) return Icons.table_chart;
    if (n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png')) {
      return Icons.image;
    }
    return Icons.insert_drive_file;
  }

  // ---------- ORTAK: öneri çipli metin alanı ----------
  Widget _oneriliAlan({
    required TextEditingController controller,
    required String etiket,
    required String ipucu,
    required List<String> oneriler,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: etiket,
            hintText: ipucu,
            border: const OutlineInputBorder(),
          ),
        ),
        if (oneriler.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: oneriler
                .map(
                  (o) => ActionChip(
                    label: Text(o, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => controller.text = o,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Future<Map<String, String>?> _bilgiDialog({
    required String baslik,
    required String onayMetni,
    String ustBaslik = '',
    String tur = '',
    String aciklama = '',
  }) {
    final ustC = TextEditingController(text: ustBaslik);
    final turC = TextEditingController(text: tur);
    final aciklamaC = TextEditingController(text: aciklama);

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(baslik),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _oneriliAlan(
                  controller: ustC,
                  etiket: 'Üst başlık (opsiyonel)',
                  ipucu: 'Örn. Disiplin Kurulu Kararları',
                  oneriler: _ustBaslikOneri,
                ),
                const SizedBox(height: 14),
                _oneriliAlan(
                  controller: turC,
                  etiket: 'Belge türü',
                  ipucu: 'Örn. Ek Protokol',
                  oneriler: _turOneri,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: aciklamaC,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (opsiyonel)',
                    hintText: 'Örn. 15.03.2026 tarihli karar',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'ustBaslik': ustC.text.trim(),
              'tur': turC.text.trim(),
              'aciklama': aciklamaC.text.trim(),
            }),
            child: Text(onayMetni),
          ),
        ],
      ),
    );
  }

  // ---------- EKLE ----------
  Future<void> _belgeEkle() async {
    final bilgi = await _bilgiDialog(
      baslik: 'Belge Ekle',
      onayMetni: 'Dosya Seç',
    );
    if (bilgi == null) return;

    final result = await FilePicker.pickFiles(withData: true);
    if (result == null) return;
    final f = result.files.first;
    if (f.bytes == null) return;

    setState(() => _yukleniyor = true);
    try {
      final belgeId = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance.ref(
        'sozlesmeler/${widget.isyeriId}/${widget.donemId}/ek/$belgeId',
      );
      await ref.putData(f.bytes!, SettableMetadata(contentType: _ct(f.name)));
      final url = await ref.getDownloadURL();

      await _ref().doc(belgeId).set({
        'ustBaslik': bilgi['ustBaslik'],
        'tur': bilgi['tur'],
        'aciklama': bilgi['aciklama'],
        'dosyaAdi': f.name,
        'boyut': f.size,
        'url': url,
        'depoYolu': ref.fullPath,
        'tarih': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Yükleme hatası: $e')));
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _belgeDuzenle(DocumentSnapshot<Map<String, dynamic>> d) async {
    final v = d.data()!;
    final bilgi = await _bilgiDialog(
      baslik: 'Belgeyi Düzenle',
      onayMetni: 'Kaydet',
      ustBaslik: (v['ustBaslik'] ?? '').toString(),
      tur: (v['tur'] ?? '').toString(),
      aciklama: (v['aciklama'] ?? '').toString(),
    );
    if (bilgi == null) return;
    await _ref().doc(d.id).update(bilgi);
  }

  // ---------- AÇ / İNDİR / SİL ----------
  Future<void> _belgeAc(Map<String, dynamic> v) async {
    final url = (v['url'] ?? '').toString();
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

  Future<void> _belgeIndir(Map<String, dynamic> v) async {
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

  Future<void> _belgeSil(DocumentSnapshot<Map<String, dynamic>> d) async {
    final v = d.data()!;
    final ad = (v['dosyaAdi'] ?? '').toString();
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Belgeyi sil'),
        content: Text('"$ad" silinsin mi?'),
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
      final yol = (v['depoYolu'] ?? '').toString();
      if (yol.isNotEmpty) await FirebaseStorage.instance.ref(yol).delete();
    } catch (_) {}
    await _ref().doc(d.id).delete();
  }

  // ---------- EKRAN ----------
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ek Belgeler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            _yukleniyor
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _belgeEkle,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Belge Ekle'),
                  ),
          ],
        ),
        const SizedBox(height: 4),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _ref().orderBy('tarih', descending: true).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final belgeler = snap.data!.docs;

            // Önerileri güncelle (mevcut değerlerden)
            _ustBaslikOneri =
                belgeler
                    .map((d) => (d.data()['ustBaslik'] ?? '').toString())
                    .where((s) => s.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
            _turOneri =
                belgeler
                    .map((d) => (d.data()['tur'] ?? '').toString())
                    .where((s) => s.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();

            if (belgeler.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 26,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 44,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Henüz ek belge yok',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Üst başlık ve tür vererek belge ekleyebilirsiniz',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Üst başlığa göre grupla
            final gruplar =
                <String, List<DocumentSnapshot<Map<String, dynamic>>>>{};
            for (final d in belgeler) {
              final u = (d.data()['ustBaslik'] ?? '').toString().trim();
              gruplar.putIfAbsent(u.isEmpty ? _genel : u, () => []).add(d);
            }
            final sirali = gruplar.keys.toList()
              ..sort((a, b) {
                if (a == _genel) return 1;
                if (b == _genel) return -1;
                return a.compareTo(b);
              });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final g in sirali) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                    child: Row(
                      children: [
                        Text(
                          g.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: g == _genel
                                ? Colors.grey.shade500
                                : AppRenk.indigo,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${gruplar[g]!.length}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...gruplar[g]!.map((d) => _belgeKarti(d)),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _belgeKarti(DocumentSnapshot<Map<String, dynamic>> d) {
    final v = d.data()!;
    final tur = (v['tur'] ?? '').toString();
    final aciklama = (v['aciklama'] ?? '').toString();
    final dosyaAdi = (v['dosyaAdi'] ?? '').toString();
    final boyut = _boyut(v['boyut'] as int?);
    final tarih = _tarih(v['tarih'] as Timestamp?);
    final renk = turRenk(tur);

    final altSatir = [
      if (tarih.isNotEmpty) tarih,
      if (boyut.isNotEmpty) boyut,
    ].join('  •  ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _belgeAc(v),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            children: [
              Icon(_ikon(dosyaAdi), color: renk, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tur.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: renk.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tur,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: renk,
                          ),
                        ),
                      ),
                    const SizedBox(height: 5),
                    Text(
                      aciklama.isNotEmpty ? aciklama : dosyaAdi,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (aciklama.isNotEmpty)
                      Text(
                        dosyaAdi,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (altSatir.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        altSatir,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'İndir',
                icon: const Icon(
                  Icons.download,
                  color: AppRenk.emerald,
                  size: 20,
                ),
                onPressed: () => _belgeIndir(v),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                onSelected: (x) {
                  if (x == 'ac') _belgeAc(v);
                  if (x == 'indir') _belgeIndir(v);
                  if (x == 'paylas') {
                    final url = (v['url'] ?? '').toString();
                    final baslik = aciklama.isNotEmpty ? aciklama : dosyaAdi;
                    Paylas.menu(context, '$baslik\n$url');
                  }
                  if (x == 'duzenle') _belgeDuzenle(d);
                  if (x == 'sil') _belgeSil(d);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'ac', child: Text('Aç')),
                  PopupMenuItem(value: 'indir', child: Text('İndir')),
                  PopupMenuItem(value: 'paylas', child: Text('Paylaş')),
                  PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
                  PopupMenuItem(value: 'sil', child: Text('Sil')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
