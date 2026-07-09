import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';

class IsyeriKisilerSekmesi extends StatefulWidget {
  final String isyeriId;
  const IsyeriKisilerSekmesi({super.key, required this.isyeriId});

  @override
  State<IsyeriKisilerSekmesi> createState() => _IsyeriKisilerSekmesiState();
}

class _IsyeriKisilerSekmesiState extends State<IsyeriKisilerSekmesi> {
  CollectionReference<Map<String, dynamic>> _kisilerRef() => FirebaseFirestore
      .instance
      .collection('isyerleri')
      .doc(widget.isyeriId)
      .collection('kisiler');

  CollectionReference<Map<String, dynamic>> _adreslerRef() => FirebaseFirestore
      .instance
      .collection('isyerleri')
      .doc(widget.isyeriId)
      .collection('adresler');

  int? _tamSayi(String? s) {
    if (s == null) return null;
    final t = s.replaceAll(RegExp(r'[^0-9]'), '');
    return t.isEmpty ? null : int.tryParse(t);
  }

  Future<void> _ara(String tel) async =>
      launchUrl(Uri.parse('tel:${tel.replaceAll(RegExp(r'\s'), '')}'));

  Future<void> _mail(String e) async => launchUrl(Uri.parse('mailto:$e'));

  Future<bool?> _silOnay(String metin) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sil'),
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

  // ---------- KİŞİ ----------
  Future<void> _kisiDialog({
    DocumentSnapshot<Map<String, dynamic>>? mevcut,
  }) async {
    final v = mevcut?.data() ?? {};
    final adC = TextEditingController(text: v['ad']?.toString() ?? '');
    final telC = TextEditingController(text: v['telefon']?.toString() ?? '');
    final epostaC = TextEditingController(text: v['eposta']?.toString() ?? '');
    final gorevC = TextEditingController(text: v['gorev']?.toString() ?? '');
    String rol = (v['rol'] ?? 'temsilci').toString();

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text(mevcut == null ? 'Kişi Ekle' : 'Kişiyi Düzenle'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Temsilci',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: 'temsilci',
                          groupValue: rol,
                          onChanged: (x) => setSt(() => rol = x!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'İK Yetkilisi',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: 'ik',
                          groupValue: rol,
                          onChanged: (x) => setSt(() => rol = x!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: adC,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: gorevC,
                    decoration: const InputDecoration(
                      labelText: 'Görev / unvan (opsiyonel)',
                      hintText: 'Örn. Baş Temsilci, İK Müdürü',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: telC,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: epostaC,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
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
      ),
    );

    if (kaydet != true || adC.text.trim().isEmpty) return;
    final kayit = {
      'rol': rol,
      'ad': adC.text.trim(),
      'gorev': gorevC.text.trim(),
      'telefon': telC.text.trim(),
      'eposta': epostaC.text.trim(),
    };
    if (mevcut == null) {
      await _kisilerRef().add({
        ...kayit,
        'olusturma': FieldValue.serverTimestamp(),
      });
    } else {
      await _kisilerRef().doc(mevcut.id).update(kayit);
    }
  }

  // ---------- ADRES ----------
  Future<void> _adresDialog({
    DocumentSnapshot<Map<String, dynamic>>? mevcut,
  }) async {
    final v = mevcut?.data() ?? {};
    final adC = TextEditingController(text: v['ad']?.toString() ?? '');
    final adresC = TextEditingController(text: v['adres']?.toString() ?? '');
    final calisanC = TextEditingController(
      text: v['calisanSayisi']?.toString() ?? '',
    );

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(mevcut == null ? 'İşyeri Birimi Ekle' : 'Birimi Düzenle'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: adC,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Birim adı',
                    hintText: 'Örn. Gebze Deposu',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: adresC,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Adres',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: calisanC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Çalışan sayısı (opsiyonel)',
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

    if (kaydet != true || adC.text.trim().isEmpty) return;
    final kayit = {
      'ad': adC.text.trim(),
      'adres': adresC.text.trim(),
      'calisanSayisi': calisanC.text.trim(),
    };
    if (mevcut == null) {
      await _adreslerRef().add({
        ...kayit,
        'olusturma': FieldValue.serverTimestamp(),
      });
    } else {
      await _adreslerRef().doc(mevcut.id).update(kayit);
    }
  }

  // ---------- EKRAN ----------
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _baslik('Kişiler', () => _kisiDialog()),
        const SizedBox(height: 4),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _kisilerRef().orderBy('rol').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final kisiler = snap.data!.docs;
            if (kisiler.isEmpty) {
              return _bosKutu(
                'Henüz kişi eklenmedi',
                '"Ekle" ile temsilci veya İK yetkilisi ekleyin',
              );
            }
            final temsilciler = kisiler
                .where((k) => (k['rol'] ?? '') == 'temsilci')
                .toList();
            final ikler = kisiler
                .where((k) => (k['rol'] ?? '') == 'ik')
                .toList();

            return Column(
              children: [
                if (ikler.isNotEmpty) ...[
                  _altBaslik('İşveren / İK', ikler.length),
                  ...ikler.map((k) => _kisiKarti(k)),
                ],
                if (temsilciler.isNotEmpty) ...[
                  _altBaslik('Sendika Temsilcileri', temsilciler.length),
                  ...temsilciler.map((k) => _kisiKarti(k)),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        _baslik('İşyeri Birimleri / Adresler', () => _adresDialog()),
        const SizedBox(height: 4),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _adreslerRef().orderBy('ad').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final adresler = snap.data!.docs;
            if (adresler.isEmpty) {
              return _bosKutu(
                'Henüz birim eklenmedi',
                'Bir işletmenin birden fazla deposu/şubesi olabilir',
              );
            }
            var toplam = 0;
            for (final a in adresler) {
              toplam += _tamSayi(a['calisanSayisi']?.toString()) ?? 0;
            }
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppRenk.indigo.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.apartment,
                        size: 18,
                        color: AppRenk.indigo,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${adresler.length} birim',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (toplam > 0) ...[
                        const Text(
                          '  •  ',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          '$toplam çalışan',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ...adresler.map((a) => _adresKarti(a)),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _baslik(String metin, VoidCallback onEkle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          metin,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        TextButton.icon(
          onPressed: onEkle,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Ekle'),
        ),
      ],
    );
  }

  Widget _altBaslik(String metin, int adet) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Row(
        children: [
          Text(
            metin.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppRenk.indigo,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: AppRenk.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$adet',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppRenk.indigo,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bosKutu(String baslik, String alt) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            baslik,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            alt,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _kisiKarti(DocumentSnapshot<Map<String, dynamic>> k) {
    final v = k.data()!;
    final ad = (v['ad'] ?? '').toString();
    final gorev = (v['gorev'] ?? '').toString();
    final tel = (v['telefon'] ?? '').toString();
    final eposta = (v['eposta'] ?? '').toString();
    final ik = (v['rol'] ?? '') == 'ik';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: (ik ? AppRenk.amber : AppRenk.emerald)
                  .withOpacity(0.15),
              child: Icon(
                ik ? Icons.badge : Icons.groups,
                size: 20,
                color: ik ? AppRenk.amber : AppRenk.emerald,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (gorev.isNotEmpty)
                    Text(
                      gorev,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  if (tel.isNotEmpty)
                    Text(
                      tel,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  if (eposta.isNotEmpty)
                    Text(
                      eposta,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                ],
              ),
            ),
            if (tel.isNotEmpty)
              IconButton(
                tooltip: 'Ara',
                icon: const Icon(Icons.call, color: AppRenk.emerald, size: 20),
                onPressed: () => _ara(tel),
              ),
            if (eposta.isNotEmpty)
              IconButton(
                tooltip: 'E-posta',
                icon: const Icon(
                  Icons.mail_outline,
                  color: AppRenk.indigo,
                  size: 20,
                ),
                onPressed: () => _mail(eposta),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
              onSelected: (d) async {
                if (d == 'duzenle') _kisiDialog(mevcut: k);
                if (d == 'sil') {
                  final ok = await _silOnay('"$ad" silinsin mi?');
                  if (ok == true) await _kisilerRef().doc(k.id).delete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
                PopupMenuItem(value: 'sil', child: Text('Sil')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _adresKarti(DocumentSnapshot<Map<String, dynamic>> a) {
    final v = a.data()!;
    final ad = (v['ad'] ?? '').toString();
    final adres = (v['adres'] ?? '').toString();
    final calisan = (v['calisanSayisi'] ?? '').toString();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.location_on_outlined,
                color: AppRenk.amber,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          ad,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (calisan.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppRenk.indigo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$calisan çalışan',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppRenk.indigo,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (adres.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    SelectableText(
                      adres,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
              onSelected: (d) async {
                if (d == 'duzenle') _adresDialog(mevcut: a);
                if (d == 'sil') {
                  final ok = await _silOnay('"$ad" birimi silinsin mi?');
                  if (ok == true) await _adreslerRef().doc(a.id).delete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
                PopupMenuItem(value: 'sil', child: Text('Sil')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
