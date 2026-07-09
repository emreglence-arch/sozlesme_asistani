import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'isyeri_sayfasi.dart';

class IsyerleriEkrani extends StatefulWidget {
  const IsyerleriEkrani({super.key});

  @override
  State<IsyerleriEkrani> createState() => _IsyerleriEkraniState();
}

class _IsyerleriEkraniState extends State<IsyerleriEkrani> {
  String _arama = '';
  String _anaFiltre = 'Tümü';
  String _altFiltre = 'Tümü';

  static const _kategorisiz = 'Kategorisiz';

  Future<void> _isyeriDialog({
    String? id,
    String ad = '',
    String ana = '',
    String alt = '',
    List<String> anaOneriler = const [],
  }) async {
    final adC = TextEditingController(text: ad);
    final anaC = TextEditingController(text: ana);
    final altC = TextEditingController(text: alt);

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(id == null ? 'Yeni İşyeri' : 'İşyerini Düzenle'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: adC,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'İşyeri adı',
                    hintText: 'Örn. DHL Supply Chain Lojistik Hizmetler A.Ş.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                _oneriliAlan(
                  controller: anaC,
                  etiket: 'Ana kategori',
                  ipucu: 'Örn. Ambar İşyerleri',
                  oneriler: anaOneriler,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: altC,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Alt kategori (opsiyonel)',
                    hintText: 'Örn. Ankara',
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
            child: Text(id == null ? 'Ekle' : 'Kaydet'),
          ),
        ],
      ),
    );

    if (kaydet != true || adC.text.trim().isEmpty) return;
    final veri = {
      'ad': adC.text.trim(),
      'anaKategori': anaC.text.trim(),
      'altKategori': altC.text.trim(),
    };
    final ref = FirebaseFirestore.instance.collection('isyerleri');
    if (id == null) {
      await ref.add({...veri, 'olusturmaTarihi': FieldValue.serverTimestamp()});
    } else {
      await ref.doc(id).update(veri);
    }
  }

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

  Future<void> _isyeriSil(String id, String ad) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İşyerini sil'),
        content: Text('"$ad" silinsin mi? Bu işlem geri alınamaz.'),
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
    if (onay == true) {
      await FirebaseFirestore.instance.collection('isyerleri').doc(id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppRenk.arkaPlan,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('isyerleri')
            .orderBy('ad')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tumu = snapshot.data!.docs;

          String anaAl(QueryDocumentSnapshot d) {
            final v = (d.data() as Map<String, dynamic>)['anaKategori'];
            final s = (v ?? '').toString().trim();
            return s.isEmpty ? _kategorisiz : s;
          }

          String altAl(QueryDocumentSnapshot d) {
            final v = (d.data() as Map<String, dynamic>)['altKategori'];
            return (v ?? '').toString().trim();
          }

          final anaKategoriler = tumu.map(anaAl).toSet().toList()..sort();
          final altKategoriler =
              tumu
                  .where((d) => _anaFiltre == 'Tümü' || anaAl(d) == _anaFiltre)
                  .map(altAl)
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();

          final liste = tumu.where((d) {
            final ad = (d['ad'] as String).toLowerCase();
            if (!ad.contains(_arama)) return false;
            if (_anaFiltre != 'Tümü' && anaAl(d) != _anaFiltre) return false;
            if (_altFiltre != 'Tümü' && altAl(d) != _altFiltre) return false;
            return true;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'İşyerleri',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppRenk.indigo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${tumu.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppRenk.indigo,
                            ),
                          ),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () => _isyeriDialog(
                            anaOneriler: anaKategoriler
                                .where((e) => e != _kategorisiz)
                                .toList(),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppRenk.indigo,
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('İşyeri Ekle'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (v) =>
                          setState(() => _arama = v.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'İşyeri ara (örn. Kühne Nagel)',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _cipSatiri(
                      secili: _anaFiltre,
                      secenekler: anaKategoriler,
                      onSec: (s) => setState(() {
                        _anaFiltre = s;
                        _altFiltre = 'Tümü';
                      }),
                    ),
                    if (_anaFiltre != 'Tümü' && altKategoriler.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _cipSatiri(
                        secili: _altFiltre,
                        secenekler: altKategoriler,
                        onSec: (s) => setState(() => _altFiltre = s),
                        kucuk: true,
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: tumu.isEmpty
                    ? _bosDurum()
                    : liste.isEmpty
                    ? const Center(child: Text('Sonuç bulunamadı'))
                    : _gruplanmisListe(liste, anaAl, altAl, anaKategoriler),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _cipSatiri({
    required String secili,
    required List<String> secenekler,
    required ValueChanged<String> onSec,
    bool kucuk = false,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['Tümü', ...secenekler].map((s) {
          final aktif = secili == s;
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: Text(s, style: TextStyle(fontSize: kucuk ? 12 : 13)),
              selected: aktif,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              selectedColor: kucuk ? AppRenk.amber : AppRenk.indigo,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: aktif ? Colors.white : Colors.black87,
              ),
              side: BorderSide(color: Colors.grey.shade300),
              onSelected: (_) => onSec(s),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _gruplanmisListe(
    List<QueryDocumentSnapshot> liste,
    String Function(QueryDocumentSnapshot) anaAl,
    String Function(QueryDocumentSnapshot) altAl,
    List<String> anaKategoriler,
  ) {
    final gruplar = <String, List<QueryDocumentSnapshot>>{};
    for (final d in liste) {
      gruplar.putIfAbsent(anaAl(d), () => []).add(d);
    }
    final sirali = gruplar.keys.toList()
      ..sort((a, b) {
        if (a == _kategorisiz) return 1;
        if (b == _kategorisiz) return -1;
        return a.compareTo(b);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        for (final grup in sirali) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Row(
              children: [
                Text(
                  grup.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: grup == _kategorisiz
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
                    '${gruplar[grup]!.length}',
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
          ...gruplar[grup]!.map(
            (d) => _isyeriKarti(d, altAl(d), anaKategoriler),
          ),
        ],
      ],
    );
  }

  Widget _isyeriKarti(
    QueryDocumentSnapshot d,
    String alt,
    List<String> anaOneriler,
  ) {
    final ad = d['ad'] as String;
    final ilkHarf = ad.isNotEmpty ? ad[0].toUpperCase() : '?';
    final veri = d.data() as Map<String, dynamic>;
    final logoUrl = (veri['logoUrl'] ?? '').toString();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppRenk.indigo,
          backgroundImage: logoUrl.isEmpty ? null : NetworkImage(logoUrl),
          child: logoUrl.isEmpty
              ? Text(ilkHarf, style: const TextStyle(color: Colors.white))
              : null,
        ),
        title: Text(ad, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: alt.isEmpty
            ? null
            : Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 13,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 3),
                  Text(alt, style: const TextStyle(fontSize: 12.5)),
                ],
              ),
        trailing: PopupMenuButton<String>(
          onSelected: (deger) {
            if (deger == 'duzenle') {
              _isyeriDialog(
                id: d.id,
                ad: ad,
                ana: (veri['anaKategori'] ?? '').toString(),
                alt: (veri['altKategori'] ?? '').toString(),
                anaOneriler: anaOneriler
                    .where((e) => e != _kategorisiz)
                    .toList(),
              );
            }
            if (deger == 'sil') _isyeriSil(d.id, ad);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'duzenle', child: Text('Düzenle / Kategori')),
            PopupMenuItem(value: 'sil', child: Text('Sil')),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IsyeriSayfasi(isyeriId: d.id, isyeriAdi: ad),
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
          Icon(Icons.business_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Henüz işyeri eklenmedi',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            'Üstteki "İşyeri Ekle" ile başla',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
