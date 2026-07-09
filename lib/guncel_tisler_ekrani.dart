import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'donem_detay_sayfasi.dart';

class _GuncelTis {
  final String isyeriId;
  final String isyeriAdi;
  final String logoUrl;
  final String donemId;
  final String donemNo;
  final String bas;
  final String bit;
  final DateTime? bitTarihi;
  final DateTime? basTarihi;

  _GuncelTis({
    required this.isyeriId,
    required this.isyeriAdi,
    required this.logoUrl,
    required this.donemId,
    required this.donemNo,
    required this.bas,
    required this.bit,
    this.bitTarihi,
    this.basTarihi,
  });
}

class GuncelTislerEkrani extends StatefulWidget {
  const GuncelTislerEkrani({super.key});

  @override
  State<GuncelTislerEkrani> createState() => _GuncelTislerEkraniState();
}

class _GuncelTislerEkraniState extends State<GuncelTislerEkrani> {
  String _arama = '';
  bool _yukleniyor = true;
  List<_GuncelTis> _liste = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  String _tarihMetni(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    final sonuc = <_GuncelTis>[];
    final simdi = DateTime.now();

    try {
      final isyerleri = await FirebaseFirestore.instance
          .collection('isyerleri')
          .get();

      for (final isyeri in isyerleri.docs) {
        final donemler = await isyeri.reference.collection('donemler').get();
        if (donemler.docs.isEmpty) continue;

        // Yürürlükteki dönemi bul: bitişi geçmemiş, en yüksek dönem no
        final adaylar = donemler.docs.where((d) {
          final v = d.data();
          final bitT = (v['bitisTarihi'] as Timestamp?)?.toDate();
          final bitYil = int.tryParse((v['bitisYili'] ?? '').toString());
          final son =
              bitT ?? (bitYil != null ? DateTime(bitYil, 12, 31) : null);
          return son != null && son.isAfter(simdi);
        }).toList();

        if (adaylar.isEmpty) continue;

        adaylar.sort((a, b) {
          final na = int.tryParse((a.data()['donemNo'] ?? '').toString()) ?? -1;
          final nb = int.tryParse((b.data()['donemNo'] ?? '').toString()) ?? -1;
          return nb.compareTo(na);
        });

        final d = adaylar.first;
        final v = d.data();
        final iv = isyeri.data();

        sonuc.add(
          _GuncelTis(
            isyeriId: isyeri.id,
            isyeriAdi: (iv['ad'] ?? '').toString(),
            logoUrl: (iv['logoUrl'] ?? '').toString(),
            donemId: d.id,
            donemNo: (v['donemNo'] ?? '').toString(),
            bas: (v['baslangicYili'] ?? '').toString(),
            bit: (v['bitisYili'] ?? '').toString(),
            basTarihi: (v['baslangicTarihi'] as Timestamp?)?.toDate(),
            bitTarihi: (v['bitisTarihi'] as Timestamp?)?.toDate(),
          ),
        );
      }

      sonuc.sort((a, b) => a.isyeriAdi.compareTo(b.isyeriAdi));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }

    if (mounted) {
      setState(() {
        _liste = sonuc;
        _yukleniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtreli = _liste
        .where((t) => t.isyeriAdi.toLowerCase().contains(_arama))
        .toList();

    return Scaffold(
      backgroundColor: AppRenk.arkaPlan,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Güncel TİS\'ler',
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
                        color: AppRenk.emerald.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_liste.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppRenk.emerald,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Yenile',
                      icon: const Icon(Icons.refresh),
                      onPressed: _yukleniyor ? null : _yukle,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Yalnızca yürürlükteki sözleşmeler',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _arama = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'İşyeri ara (örn. Aras)',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : filtreli.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _liste.isEmpty
                              ? 'Yürürlükte sözleşme bulunamadı'
                              : 'Sonuç bulunamadı',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    itemCount: filtreli.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _kart(filtreli[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _kart(_GuncelTis t) {
    final ilkHarf = t.isyeriAdi.isNotEmpty ? t.isyeriAdi[0].toUpperCase() : '?';
    final baslik = t.donemNo.isNotEmpty
        ? '${t.donemNo}. Dönem'
        : '${t.bas} - ${t.bit}';
    final tarih = (t.basTarihi != null && t.bitTarihi != null)
        ? '${_tarihMetni(t.basTarihi!)} - ${_tarihMetni(t.bitTarihi!)}'
        : '${t.bas} - ${t.bit}';

    String kalan = '';
    Color kalanRenk = AppRenk.emerald;
    if (t.bitTarihi != null) {
      final g = t.bitTarihi!.difference(DateTime.now()).inDays;
      kalan = '$g gün';
      if (g <= 120) kalanRenk = AppRenk.amber;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppRenk.emerald, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: AppRenk.indigo,
          backgroundImage: t.logoUrl.isEmpty ? null : NetworkImage(t.logoUrl),
          child: t.logoUrl.isEmpty
              ? Text(ilkHarf, style: const TextStyle(color: Colors.white))
              : null,
        ),
        title: Text(
          t.isyeriAdi,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  baslik,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppRenk.indigo,
                  ),
                ),
                const Text('  •  ', style: TextStyle(color: Colors.grey)),
                Flexible(
                  child: Text(
                    tarih,
                    style: const TextStyle(fontSize: 12.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (kalan.isNotEmpty) ...[
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: kalanRenk.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Bitişe $kalan',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: kalanRenk,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: AppRenk.indigo),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DonemDetaySayfasi(
              isyeriId: t.isyeriId,
              donemId: t.donemId,
              isyeriAdi: t.isyeriAdi,
              donemBaslik: t.donemNo.isNotEmpty
                  ? '${t.isyeriAdi} — ${t.donemNo}. Dönem'
                  : '${t.isyeriAdi} — ${t.bas}-${t.bit}',
            ),
          ),
        ),
      ),
    );
  }
}
