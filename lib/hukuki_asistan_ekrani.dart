import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'yasa_detay_sayfasi.dart';

class HukukiAsistanEkrani extends StatefulWidget {
  const HukukiAsistanEkrani({super.key});

  @override
  State<HukukiAsistanEkrani> createState() => _HukukiAsistanEkraniState();
}

class _Kirinti {
  final String? id;
  final String ad;
  _Kirinti(this.id, this.ad);
}

class _HukukiAsistanEkraniState extends State<HukukiAsistanEkrani> {
  late List<_Kirinti> _yol;

  @override
  void initState() {
    super.initState();
    _yol = [_Kirinti(null, 'Hukuki Asistan')];
  }

  String get _aktifKlasorKey => _yol.last.id ?? '_kok';

  CollectionReference<Map<String, dynamic>> _kokRef() =>
      FirebaseFirestore.instance.collection('hukuk');

  CollectionReference<Map<String, dynamic>> _klasorlerRef() =>
      _kokRef().doc('_ana').collection('klasorler');

  CollectionReference<Map<String, dynamic>> _yasalarRef() =>
      _kokRef().doc('_ana').collection('yasalar');

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
              hintText: 'Örn. Sendika Mevzuatı',
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
        'ustKlasorId': _aktifKlasorKey,
        'sira': DateTime.now().millisecondsSinceEpoch,
        'olusturma': FieldValue.serverTimestamp(),
      });
    } else {
      await _klasorlerRef().doc(mevcut.id).update({'ad': c.text.trim()});
    }
  }

  Future<void> _klasorSil(String id, String ad) async {
    final onay = await _silOnay(
      'Klasörü sil',
      '"$ad" ve içindeki tüm klasör/yasalar silinsin mi?',
    );
    if (onay != true) return;

    Future<void> silAgac(String klasorId) async {
      final altlar = await _klasorlerRef()
          .where('ustKlasorId', isEqualTo: klasorId)
          .get();
      for (final a in altlar.docs) {
        await silAgac(a.id);
      }
      final yasalar = await _yasalarRef()
          .where('klasorId', isEqualTo: klasorId)
          .get();
      for (final y in yasalar.docs) {
        await y.reference.delete();
      }
      await _klasorlerRef().doc(klasorId).delete();
    }

    await silAgac(id);
  }

  // ---------- YASA ----------
  Future<void> _yasaDialog({
    DocumentSnapshot<Map<String, dynamic>>? mevcut,
  }) async {
    final adC = TextEditingController(
      text: (mevcut?.data()?['ad'] ?? '').toString(),
    );
    final noC = TextEditingController(
      text: (mevcut?.data()?['no'] ?? '').toString(),
    );

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(mevcut == null ? 'Yeni Yasa' : 'Yasayı Düzenle'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: adC,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Yasa adı',
                  hintText: 'Örn. İş Kanunu',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noC,
                decoration: const InputDecoration(
                  labelText: 'Yasa no (opsiyonel)',
                  hintText: 'Örn. 4857',
                  border: OutlineInputBorder(),
                ),
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
            child: Text(mevcut == null ? 'Oluştur' : 'Kaydet'),
          ),
        ],
      ),
    );

    if (kaydet != true || adC.text.trim().isEmpty) return;
    if (mevcut == null) {
      await _yasalarRef().add({
        'ad': adC.text.trim(),
        'no': noC.text.trim(),
        'klasorId': _aktifKlasorKey,
        'sira': DateTime.now().millisecondsSinceEpoch,
        'olusturma': FieldValue.serverTimestamp(),
      });
    } else {
      await _yasalarRef().doc(mevcut.id).update({
        'ad': adC.text.trim(),
        'no': noC.text.trim(),
      });
    }
  }

  Future<void> _yasaSil(String id, String ad) async {
    final onay = await _silOnay(
      'Yasayı sil',
      '"$ad" yasası, tüm maddeleri ve belgeleriyle silinsin mi?',
    );
    if (onay != true) return;
    await _yasalarRef().doc(id).delete();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppRenk.arkaPlan,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'hklasor',
            onPressed: () => _klasorDialog(),
            backgroundColor: Colors.white,
            foregroundColor: AppRenk.indigo,
            tooltip: 'Klasör Ekle',
            child: const Icon(Icons.create_new_folder_outlined),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'hyasa',
            onPressed: () => _yasaDialog(),
            backgroundColor: AppRenk.indigo,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Yasa Ekle'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppRenk.indigo.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.balance,
                    color: AppRenk.indigo,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Hukuki Asistan',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
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
                        onTap: i == _yol.length - 1 ? null : () => _yolaGit(i),
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
                                  : AppRenk.indigo,
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
    );
  }

  Widget _icerik() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _klasorlerRef()
          .where('ustKlasorId', isEqualTo: _aktifKlasorKey)
          .snapshots(),
      builder: (context, klasorSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _yasalarRef()
              .where('klasorId', isEqualTo: _aktifKlasorKey)
              .snapshots(),
          builder: (context, yasaSnap) {
            if (!klasorSnap.hasData || !yasaSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            int siraAl(DocumentSnapshot<Map<String, dynamic>> d) {
              final s = d.data()?['sira'];
              return (s is int) ? s : 1 << 30;
            }

            final klasorler = klasorSnap.data!.docs.toList()
              ..sort((a, b) => siraAl(a).compareTo(siraAl(b)));
            final yasalar = yasaSnap.data!.docs.toList()
              ..sort((a, b) => siraAl(a).compareTo(siraAl(b)));

            if (klasorler.isEmpty && yasalar.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gavel, size: 68, color: Colors.grey.shade400),
                    const SizedBox(height: 14),
                    Text(
                      _yol.length > 1 ? 'Bu klasör boş' : 'Henüz içerik yok',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sağ alttan klasör veya yasa ekleyin',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
              children: [
                ...klasorler.map((k) => _klasorKarti(k)),
                if (klasorler.isNotEmpty && yasalar.isNotEmpty)
                  const SizedBox(height: 14),
                ...yasalar.map((y) => _yasaKarti(y)),
              ],
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
        leading: const Icon(Icons.folder, color: AppRenk.indigo, size: 32),
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

  Widget _yasaKarti(DocumentSnapshot<Map<String, dynamic>> y) {
    final v = y.data()!;
    final ad = (v['ad'] ?? '').toString();
    final no = (v['no'] ?? '').toString();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppRenk.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.gavel, color: AppRenk.amber, size: 21),
        ),
        title: Text(ad, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: no.isEmpty
            ? null
            : Text('No: $no', style: const TextStyle(fontSize: 12.5)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
              onSelected: (x) {
                if (x == 'duzenle') _yasaDialog(mevcut: y);
                if (x == 'sil') _yasaSil(y.id, ad);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
                PopupMenuItem(value: 'sil', child: Text('Sil')),
              ],
            ),
            const Icon(Icons.chevron_right, color: AppRenk.indigo),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => YasaDetaySayfasi(
              yasaRef: _yasalarRef().doc(y.id),
              yasaAdi: no.isEmpty ? ad : '$no - $ad',
            ),
          ),
        ),
      ),
    );
  }
}
