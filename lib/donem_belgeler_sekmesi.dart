import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'pdf_goruntuleyici.dart';
import 'donem_ek_belgeler.dart';

class DonemBelgelerSekmesi extends StatefulWidget {
  final String isyeriId;
  final String donemId;

  const DonemBelgelerSekmesi({
    super.key,
    required this.isyeriId,
    required this.donemId,
  });

  @override
  State<DonemBelgelerSekmesi> createState() => _DonemBelgelerSekmesiState();
}

class _DonemBelgelerSekmesiState extends State<DonemBelgelerSekmesi> {
  String? _yukleniyor;

  DocumentReference<Map<String, dynamic>> _donemRef() => FirebaseFirestore
      .instance
      .collection('isyerleri')
      .doc(widget.isyeriId)
      .collection('donemler')
      .doc(widget.donemId);

  String _depoYolu(String tur) =>
      'sozlesmeler/${widget.isyeriId}/${widget.donemId}/$tur';

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
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dosya açılamadı')));
      }
    }
  }

  Future<void> _belgeSil(String tur) async {
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
    await _donemRef().update({
      '${tur}Url': FieldValue.delete(),
      '${tur}Ad': FieldValue.delete(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _donemRef().snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final veri = snapshot.data!.data() ?? {};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Sözleşme Belgeleri',
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
                              baslik: ad ?? 'Sözleşme',
                            ),
                          ),
                        );
                      } else {
                        _ac(url);
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
