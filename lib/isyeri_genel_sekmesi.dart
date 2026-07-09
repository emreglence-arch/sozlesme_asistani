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

  String _tarihMetni(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';

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

  // ---------- LOGO ----------
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

  // ---------- TEMEL BİLGİLER ----------
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

  // ---------- DÖNEM EKLE / DÜZENLE ----------
  Future<void> _donemDialog({
    DocumentSnapshot<Map<String, dynamic>>? mevcut,
  }) async {
    final v = mevcut?.data() ?? {};
    final donemNoC = TextEditingController(
      text: (v['donemNo'] ?? '').toString(),
    );
    DateTime? baslangic = (v['baslangicTarihi'] as Timestamp?)?.toDate();
    DateTime? bitis = (v['bitisTarihi'] as Timestamp?)?.toDate();

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text(
            mevcut == null ? 'Yeni Sözleşme Dönemi' : 'Dönemi Düzenle',
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: donemNoC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kaçıncı dönem',
                    hintText: 'Örn. 5',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final s = await showDatePicker(
                        context: context,
                        initialDate: baslangic ?? DateTime.now(),
                        firstDate: DateTime(1990),
                        lastDate: DateTime(2100),
                      );
                      if (s != null) setSt(() => baslangic = s);
                    },
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(
                      baslangic == null
                          ? 'Yürürlük başlangıcı seç'
                          : 'Başlangıç: ${_tarihMetni(baslangic!)}',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final s = await showDatePicker(
                        context: context,
                        initialDate: bitis ?? baslangic ?? DateTime.now(),
                        firstDate: DateTime(1990),
                        lastDate: DateTime(2100),
                      );
                      if (s != null) setSt(() => bitis = s);
                    },
                    icon: const Icon(Icons.event_available, size: 18),
                    label: Text(
                      bitis == null
                          ? 'Yürürlük bitişi seç'
                          : 'Bitiş: ${_tarihMetni(bitis!)}',
                    ),
                  ),
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
              child: Text(mevcut == null ? 'Ekle' : 'Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (kaydet != true || baslangic == null || bitis == null) return;

    final kayit = {
      'donemNo': donemNoC.text.trim(),
      'baslangicTarihi': Timestamp.fromDate(baslangic!),
      'bitisTarihi': Timestamp.fromDate(bitis!),
      'baslangicYili': baslangic!.year.toString(),
      'bitisYili': bitis!.year.toString(),
    };

    if (mevcut == null) {
      await _donemlerRef().add({
        ...kayit,
        'guncelMi': false,
        'olusturmaTarihi': FieldValue.serverTimestamp(),
      });
    } else {
      await _donemlerRef().doc(mevcut.id).update(kayit);
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

  // ---------- EKRAN ----------
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _isyeriRef().snapshots(),
      builder: (context, isyeriSnap) {
        final veri = isyeriSnap.data?.data() ?? {};
        final ad = (veri['ad'] ?? widget.isyeriAdi).toString();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _donemlerRef().snapshots(),
          builder: (context, donemSnap) {
            final donemler = donemSnap.data?.docs.toList() ?? [];

            // Dönem numarasına göre büyükten küçüğe sırala
            donemler.sort((a, b) {
              final na =
                  int.tryParse((a.data()['donemNo'] ?? '').toString()) ?? -1;
              final nb =
                  int.tryParse((b.data()['donemNo'] ?? '').toString()) ?? -1;
              if (na != nb) return nb.compareTo(na);
              final ya =
                  int.tryParse((a.data()['baslangicYili'] ?? '').toString()) ??
                  0;
              final yb =
                  int.tryParse((b.data()['baslangicYili'] ?? '').toString()) ??
                  0;
              return yb.compareTo(ya);
            });

            // Otomatik yürürlük: bitiş tarihi geçmemiş, en yüksek numaralı dönem
            final simdi = DateTime.now();
            DocumentSnapshot<Map<String, dynamic>>? guncel;
            for (final d in donemler) {
              final v = d.data();
              final bitT = (v['bitisTarihi'] as Timestamp?)?.toDate();
              final bitYil = int.tryParse((v['bitisYili'] ?? '').toString());
              final son =
                  bitT ?? (bitYil != null ? DateTime(bitYil, 12, 31) : null);
              if (son != null && son.isAfter(simdi)) {
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
                      onPressed: () => _donemDialog(),
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
                  ...donemler.map((d) => _donemKarti(d, d.id == guncel?.id)),
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

  Widget _guncelOzet(DocumentSnapshot<Map<String, dynamic>> d) {
    final veri = d.data()!;
    final donemNo = (veri['donemNo'] ?? '').toString();
    final bas = (veri['baslangicYili'] ?? '').toString();
    final bit = (veri['bitisYili'] ?? '').toString();
    final basT = (veri['baslangicTarihi'] as Timestamp?)?.toDate();
    final bitT = (veri['bitisTarihi'] as Timestamp?)?.toDate();
    final bitYil = int.tryParse(bit);

    final baslik = donemNo.isNotEmpty ? '$donemNo. Dönem' : '$bas - $bit';
    final tarihMetni = (basT != null && bitT != null)
        ? '${_tarihMetni(basT)} - ${_tarihMetni(bitT)}'
        : '$bas - $bit';

    String kalanMetin = '';
    Color kalanRenk = AppRenk.emerald;
    final son = bitT ?? (bitYil != null ? DateTime(bitYil, 12, 31) : null);
    if (son != null) {
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
              donemBaslik: donemNo.isNotEmpty
                  ? '$donemNo. Dönem ($bas-$bit)'
                  : '$bas - $bit',
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
                      baslik,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tarihMetni,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                    if (kalanMetin.isNotEmpty) ...[
                      const SizedBox(height: 6),
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

  Widget _donemKarti(DocumentSnapshot<Map<String, dynamic>> d, bool guncelMi) {
    final veri = d.data()!;
    final donemNo = (veri['donemNo'] ?? '').toString();
    final bas = (veri['baslangicYili'] ?? '').toString();
    final bit = (veri['bitisYili'] ?? '').toString();
    final basT = (veri['baslangicTarihi'] as Timestamp?)?.toDate();
    final bitT = (veri['bitisTarihi'] as Timestamp?)?.toDate();

    final baslik = donemNo.isNotEmpty ? '$donemNo. Dönem' : '$bas - $bit';
    final tarihMetni = (basT != null && bitT != null)
        ? '${_tarihMetni(basT)} - ${_tarihMetni(bitT)}'
        : '$bas - $bit';

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
          baslik,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(tarihMetni, style: const TextStyle(fontSize: 12.5)),
            if (guncelMi)
              const Text(
                'Yürürlükte',
                style: TextStyle(
                  color: AppRenk.emerald,
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (deger) {
            if (deger == 'duzenle') _donemDialog(mevcut: d);
            if (deger == 'sil') _donemSil(d.id);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
            PopupMenuItem(value: 'sil', child: Text('Sil')),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DonemDetaySayfasi(
              isyeriId: widget.isyeriId,
              donemId: d.id,
              donemBaslik: donemNo.isNotEmpty
                  ? '$donemNo. Dönem ($bas-$bit)'
                  : '$bas - $bit',
            ),
          ),
        ),
      ),
    );
  }
}
