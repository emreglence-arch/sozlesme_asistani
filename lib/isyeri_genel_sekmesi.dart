import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'main.dart';
import 'donem_detay_sayfasi.dart';

class IsyeriGenelSekmesi extends StatefulWidget {
  final String isyeriId;
  final String isyeriAdi;

  const IsyeriGenelSekmesi({
    super.key,
    required this.isyeriId,
    required this.isyeriAdi,
  });

  @override
  State<IsyeriGenelSekmesi> createState() => _IsyeriGenelSekmesiState();
}

class _IsyeriGenelSekmesiState extends State<IsyeriGenelSekmesi> {
  bool _logoYukleniyor = false;

  DocumentReference<Map<String, dynamic>> _isyeriRef() =>
      FirebaseFirestore.instance.collection('isyerleri').doc(widget.isyeriId);

  CollectionReference<Map<String, dynamic>> _donemlerRef() =>
      _isyeriRef().collection('donemler');

  int? _tamSayi(String? s) {
    if (s == null) return null;
    final t = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  String _imgCt(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> _logoYukle() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null) return;
    final f = result.files.first;
    if (f.bytes == null) return;

    setState(() => _logoYukleniyor = true);
    try {
      final ref = FirebaseStorage.instance.ref(
        'isyerleri/${widget.isyeriId}/logo',
      );
      await ref.putData(
        f.bytes!,
        SettableMetadata(contentType: _imgCt(f.name)),
      );
      final url = await ref.getDownloadURL();
      await _isyeriRef().update({'logoUrl': url});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logo hatası: $e')));
      }
    } finally {
      if (mounted) setState(() => _logoYukleniyor = false);
    }
  }

  Future<void> _temelDuzenle(Map<String, dynamic> veri) async {
    final adC = TextEditingController(
      text: veri['ad']?.toString() ?? widget.isyeriAdi,
    );
    final subeC = TextEditingController(text: veri['sube']?.toString() ?? '');
    final calisanC = TextEditingController(
      text: veri['calisanSayisi']?.toString() ?? '',
    );
    final uyeC = TextEditingController(
      text: veri['uyeSayisi']?.toString() ?? '',
    );

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Temel Bilgiler'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: adC,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'İşyeri adı',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subeC,
                decoration: const InputDecoration(
                  labelText: 'Bağlı şube',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: calisanC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Çalışan sayısı',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: uyeC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Üye sayısı',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
    await _isyeriRef().update({
      'ad': adC.text.trim(),
      'sube': subeC.text.trim(),
      'calisanSayisi': calisanC.text.trim(),
      'uyeSayisi': uyeC.text.trim(),
    });
  }

  Future<void> _donemEkle() async {
    final baslangicC = TextEditingController();
    final bitisC = TextEditingController();
    final sonuc = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Sözleşme Dönemi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: baslangicC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Başlangıç yılı',
                hintText: 'Örn. 2026',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bitisC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Bitiş yılı',
                hintText: 'Örn. 2027',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'baslangic': baslangicC.text.trim(),
              'bitis': bitisC.text.trim(),
            }),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    if (sonuc != null &&
        sonuc['baslangic']!.isNotEmpty &&
        sonuc['bitis']!.isNotEmpty) {
      await _donemlerRef().add({
        'baslangicYili': sonuc['baslangic'],
        'bitisYili': sonuc['bitis'],
        'guncelMi': false,
        'olusturmaTarihi': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _guncelYap(String donemId) async {
    final hepsi = await _donemlerRef().get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in hepsi.docs) {
      batch.update(d.reference, {'guncelMi': d.id == donemId});
    }
    await batch.commit();
  }

  Future<void> _donemSil(String donemId) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dönemi sil'),
        content: const Text('Bu sözleşme dönemi silinsin mi?'),
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
    if (onay == true) await _donemlerRef().doc(donemId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _isyeriRef().snapshots(),
      builder: (context, isyeriSnap) {
        final veri = isyeriSnap.data?.data() ?? {};
        final ad = (veri['ad'] ?? widget.isyeriAdi).toString();

        return StreamBuilder<QuerySnapshot>(
          stream: _donemlerRef()
              .orderBy('baslangicYili', descending: true)
              .snapshots(),
          builder: (context, donemSnap) {
            final donemler = donemSnap.data?.docs ?? [];
            QueryDocumentSnapshot? guncel;
            for (final d in donemler) {
              if ((d['guncelMi'] ?? false) == true) {
                guncel = d;
                break;
              }
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _baslikAlani(ad, veri),
                const SizedBox(height: 18),
                _istatistikSeridi(veri),
                if (guncel != null) ...[
                  const SizedBox(height: 16),
                  _guncelOzet(guncel),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sözleşmeler',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _donemEkle,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Dönem Ekle'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (donemler.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Henüz sözleşme dönemi yok',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                else
                  ...donemler.map((d) => _donemKarti(d)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _baslikAlani(String ad, Map<String, dynamic> veri) {
    final logoUrl = veri['logoUrl']?.toString();
    final sube = (veri['sube'] ?? '').toString();
    final ilkHarf = ad.isNotEmpty ? ad[0].toUpperCase() : '?';

    return Row(
      children: [
        GestureDetector(
          onTap: _logoYukleniyor ? null : _logoYukle,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppRenk.indigo.withOpacity(0.1),
                  shape: BoxShape.circle,
                  image: (logoUrl != null && !_logoYukleniyor)
                      ? DecorationImage(
                          image: NetworkImage(logoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: (logoUrl == null && !_logoYukleniyor)
                    ? Text(
                        ilkHarf,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppRenk.indigo,
                        ),
                      )
                    : null,
              ),
              if (_logoYukleniyor)
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppRenk.indigo,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ad,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (sube.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  sube,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: 'Temel bilgileri düzenle',
          icon: const Icon(Icons.edit_outlined, color: AppRenk.indigo),
          onPressed: () => _temelDuzenle(veri),
        ),
      ],
    );
  }

  Widget _istatistikSeridi(Map<String, dynamic> veri) {
    final c = _tamSayi(veri['calisanSayisi']?.toString());
    final u = _tamSayi(veri['uyeSayisi']?.toString());
    String oran = '—';
    if (c != null && u != null && c > 0) oran = '%${(u / c * 100).round()}';
    return Row(
      children: [
        _statKart('Çalışan', c?.toString() ?? '—', AppRenk.indigo),
        const SizedBox(width: 10),
        _statKart('Üye', u?.toString() ?? '—', AppRenk.amber),
        const SizedBox(width: 10),
        _statKart('Örgütlenme', oran, AppRenk.emerald),
      ],
    );
  }

  Widget _statKart(String baslik, String deger, Color renk) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: renk.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              deger,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: renk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              baslik,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guncelOzet(QueryDocumentSnapshot d) {
    final bas = (d['baslangicYili'] ?? '').toString();
    final bit = (d['bitisYili'] ?? '').toString();
    final bitYil = int.tryParse(bit);
    String kalanMetin = '';
    Color kalanRenk = AppRenk.emerald;
    if (bitYil != null) {
      final son = DateTime(bitYil, 12, 31);
      final kalan = son.difference(DateTime.now()).inDays;
      if (kalan < 0) {
        kalanMetin = 'Süresi doldu';
        kalanRenk = Colors.red;
      } else if (kalan <= 120) {
        kalanMetin = 'Bitişe $kalan gün — yenileme yaklaşıyor';
        kalanRenk = AppRenk.amber;
      } else {
        kalanMetin = 'Bitişe $kalan gün';
      }
    }

    return Card(
      elevation: 0,
      color: AppRenk.indigo,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DonemDetaySayfasi(
              isyeriId: widget.isyeriId,
              donemId: d.id,
              donemBaslik: '$bas - $bit',
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 34,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Yürürlükteki Sözleşme',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$bas - $bit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (kalanMetin.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: kalanRenk,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          kalanMetin,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  Widget _donemKarti(QueryDocumentSnapshot d) {
    final bas = (d['baslangicYili'] ?? '').toString();
    final bit = (d['bitisYili'] ?? '').toString();
    final guncelMi = (d['guncelMi'] ?? false) as bool;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: guncelMi
            ? const BorderSide(color: AppRenk.emerald, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(
          Icons.folder,
          color: guncelMi ? AppRenk.emerald : AppRenk.amber,
          size: 34,
        ),
        title: Text(
          '$bas - $bit',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: guncelMi
            ? const Text(
                'Yürürlükte',
                style: TextStyle(
                  color: AppRenk.emerald,
                  fontWeight: FontWeight.w500,
                ),
              )
            : const Text('Geçmiş dönem'),
        trailing: PopupMenuButton<String>(
          onSelected: (deger) {
            if (deger == 'guncel') _guncelYap(d.id);
            if (deger == 'sil') _donemSil(d.id);
          },
          itemBuilder: (context) => [
            if (!guncelMi)
              const PopupMenuItem(
                value: 'guncel',
                child: Text('Yürürlükte işaretle'),
              ),
            const PopupMenuItem(value: 'sil', child: Text('Sil')),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DonemDetaySayfasi(
              isyeriId: widget.isyeriId,
              donemId: d.id,
              donemBaslik: '$bas - $bit',
            ),
          ),
        ),
      ),
    );
  }
}
