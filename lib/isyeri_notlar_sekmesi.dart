import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';

class IsyeriNotlarSekmesi extends StatefulWidget {
  final String isyeriId;
  const IsyeriNotlarSekmesi({super.key, required this.isyeriId});

  @override
  State<IsyeriNotlarSekmesi> createState() => _IsyeriNotlarSekmesiState();
}

class _IsyeriNotlarSekmesiState extends State<IsyeriNotlarSekmesi> {
  // Daha önce kullanılmış etiketler (öneri olarak sunulur)
  List<String> _etiketOneri = [];

  static const _palet = [
    AppRenk.indigo,
    AppRenk.emerald,
    AppRenk.amber,
    Colors.red,
    Colors.purple,
    Colors.teal,
    Colors.blueGrey,
  ];

  DocumentReference<Map<String, dynamic>> _isyeriRef() =>
      FirebaseFirestore.instance.collection('isyerleri').doc(widget.isyeriId);

  CollectionReference<Map<String, dynamic>> _gunlukRef() =>
      _isyeriRef().collection('gunluk');

  Color _etiketRenk(String e) {
    if (e.isEmpty) return Colors.grey;
    var h = 0;
    for (final c in e.codeUnits) {
      h = (h + c) % 1000;
    }
    return _palet[h % _palet.length];
  }

  String _tarihMetni(DateTime t) {
    const aylar = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return '${t.day} ${aylar[t.month - 1]} ${t.year}';
  }

  // ---------- GENEL NOTLAR ----------
  Future<void> _genelNotDuzenle(String mevcut) async {
    final c = TextEditingController(text: mevcut);
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Genel Notlar'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: c,
            autofocus: true,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText:
                  'Bu işyerine dair kalıcı notlar...\nÖrn. özel uygulamalar, dikkat edilecek maddeler',
              border: OutlineInputBorder(),
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
    await _isyeriRef().update({'notlar': c.text.trim()});
  }

  // ---------- GÜNLÜK ----------
  Future<void> _girdiDialog({
    DocumentSnapshot<Map<String, dynamic>>? mevcut,
  }) async {
    final v = mevcut?.data() ?? {};
    final baslikC = TextEditingController(text: v['baslik']?.toString() ?? '');
    final icerikC = TextEditingController(text: v['icerik']?.toString() ?? '');
    final etiketC = TextEditingController(text: v['etiket']?.toString() ?? '');
    DateTime tarih = (v['tarih'] as Timestamp?)?.toDate() ?? DateTime.now();

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text(mevcut == null ? 'Yeni Not' : 'Notu Düzenle'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final secilen = await showDatePicker(
                              context: context,
                              initialDate: tarih,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (secilen != null) setSt(() => tarih = secilen);
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(_tarihMetni(tarih)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: etiketC,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Etiket',
                            hintText: 'Örn. Görüşme',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_etiketOneri.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _etiketOneri
                          .map(
                            (o) => ActionChip(
                              label: Text(
                                o,
                                style: const TextStyle(fontSize: 12),
                              ),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => etiketC.text = o,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: baslikC,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Başlık',
                      hintText: 'Örn. İK ile ikramiye görüşmesi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: icerikC,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Not',
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

    if (kaydet != true) return;
    if (baslikC.text.trim().isEmpty && icerikC.text.trim().isEmpty) return;

    final kayit = {
      'baslik': baslikC.text.trim(),
      'icerik': icerikC.text.trim(),
      'etiket': etiketC.text.trim(),
      'tarih': Timestamp.fromDate(tarih),
    };
    if (mevcut == null) {
      await _gunlukRef().add(kayit);
    } else {
      await _gunlukRef().doc(mevcut.id).update(kayit);
    }
  }

  Future<void> _girdiSil(String id, String baslik) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notu sil'),
        content: Text(
          baslik.isEmpty ? 'Bu not silinsin mi?' : '"$baslik" silinsin mi?',
        ),
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
    if (ok == true) await _gunlukRef().doc(id).delete();
  }

  // ---------- EKRAN ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _girdiDialog(),
        backgroundColor: AppRenk.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Not Ekle'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _isyeriRef().snapshots(),
            builder: (context, snap) {
              final notlar = (snap.data?.data()?['notlar'] ?? '').toString();
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.push_pin_outlined,
                            size: 18,
                            color: AppRenk.amber,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Genel Notlar',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 19,
                              color: AppRenk.indigo,
                            ),
                            onPressed: () => _genelNotDuzenle(notlar),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8, top: 2),
                        child: notlar.isEmpty
                            ? Text(
                                'Henüz genel not yok — kalem simgesine dokunun',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              )
                            : SelectableText(
                                notlar,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 26),
          const Text(
            'Günlük',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _gunlukRef().orderBy('tarih', descending: true).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final girdiler = snap.data!.docs;

              // Öneri listesini güncelle
              _etiketOneri =
                  girdiler
                      .map((g) => (g.data()['etiket'] ?? '').toString())
                      .where((s) => s.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();

              if (girdiler.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 34,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_note_outlined,
                        size: 54,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Henüz kayıt yok',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Görüşme, toplantı ve gelişmeleri buraya kaydedin',
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
              return Column(
                children: girdiler.map((g) => _girdiKarti(g)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _girdiKarti(DocumentSnapshot<Map<String, dynamic>> g) {
    final v = g.data()!;
    final baslik = (v['baslik'] ?? '').toString();
    final icerik = (v['icerik'] ?? '').toString();
    final etiket = (v['etiket'] ?? '').toString();
    final tarih = (v['tarih'] as Timestamp?)?.toDate();
    final renk = _etiketRenk(etiket);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 6, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (etiket.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: renk.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      etiket,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: renk,
                      ),
                    ),
                  ),
                if (etiket.isNotEmpty) const SizedBox(width: 10),
                if (tarih != null)
                  Text(
                    _tarihMetni(tarih),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                const Spacer(),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_vert,
                    size: 19,
                    color: Colors.grey,
                  ),
                  onSelected: (d) {
                    if (d == 'duzenle') _girdiDialog(mevcut: g);
                    if (d == 'sil') _girdiSil(g.id, baslik);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
                    PopupMenuItem(value: 'sil', child: Text('Sil')),
                  ],
                ),
              ],
            ),
            if (baslik.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                baslik,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (icerik.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SelectableText(
                  icerik,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
