import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'isyerleri_ekrani.dart';
import 'guncel_tisler_ekrani.dart';
import 'ayarlar_ekrani.dart';
import 'ozel_sayfalar_servisi.dart';
import 'ozel_sayfa_ekrani.dart';

class AnaKabuk extends StatefulWidget {
  const AnaKabuk({super.key});

  @override
  State<AnaKabuk> createState() => _AnaKabukState();
}

class _AnaKabukState extends State<AnaKabuk> {
  // 0: İşyerleri, 1: Güncel TİS'ler, 2..n: özel sayfalar, son: Ayarlar
  int _secili = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: OzelSayfalarServisi.akis(),
      builder: (context, snap) {
        final ozelSayfalar = snap.data?.docs ?? [];
        final ayarlarIndex = 2 + ozelSayfalar.length;
        final secili = _secili.clamp(0, ayarlarIndex);

        String baslik;
        Widget icerik;

        if (secili == 0) {
          baslik = 'İşyerleri';
          icerik = const IsyerleriEkrani();
        } else if (secili == 1) {
          baslik = 'Güncel TİS\'ler';
          icerik = const GuncelTislerEkrani();
        } else if (secili == ayarlarIndex) {
          baslik = 'Ayarlar';
          icerik = const AyarlarEkrani();
        } else {
          final s = ozelSayfalar[secili - 2];
          final v = s.data();
          final ad = (v['ad'] ?? '').toString();
          baslik = ad;
          icerik = OzelSayfaEkrani(
            key: ValueKey(s.id),
            sayfaId: s.id,
            sayfaAdi: ad,
            renk: Color((v['renk'] ?? AppRenk.indigo.value) as int),
            ikon: ikonBul(v['ikon']?.toString()),
          );
        }

        final genis = MediaQuery.of(context).size.width >= 800;

        final menu = _YanMenu(
          secili: secili,
          ozelSayfalar: ozelSayfalar,
          ayarlarIndex: ayarlarIndex,
          onSec: (i) {
            setState(() => _secili = i);
            if (!genis) Navigator.pop(context);
          },
        );

        return Scaffold(
          appBar: genis
              ? null
              : AppBar(
                  title: Text(baslik),
                  backgroundColor: AppRenk.indigo,
                  foregroundColor: Colors.white,
                ),
          drawer: genis ? null : Drawer(child: menu),
          body: genis
              ? Row(
                  children: [
                    SizedBox(width: 250, child: menu),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: icerik),
                  ],
                )
              : icerik,
        );
      },
    );
  }
}

class _YanMenu extends StatelessWidget {
  final int secili;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> ozelSayfalar;
  final int ayarlarIndex;
  final ValueChanged<int> onSec;

  const _YanMenu({
    required this.secili,
    required this.ozelSayfalar,
    required this.ayarlarIndex,
    required this.onSec,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppRenk.indigo,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.gavel,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sözleşme',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'Asistanı',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppRenk.indigo,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _menuOge(
                    ikon: Icons.business_outlined,
                    seciliIkon: Icons.business,
                    baslik: 'İşyerleri',
                    index: 0,
                    renk: AppRenk.indigo,
                  ),
                  _menuOge(
                    ikon: Icons.verified_outlined,
                    seciliIkon: Icons.verified,
                    baslik: 'Güncel TİS\'ler',
                    index: 1,
                    renk: AppRenk.indigo,
                  ),

                  if (ozelSayfalar.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 6, 20, 6),
                      child: Text(
                        'SAYFALARIM',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                    for (var i = 0; i < ozelSayfalar.length; i++)
                      _menuOge(
                        ikon: ikonBul(
                          ozelSayfalar[i].data()['ikon']?.toString(),
                        ),
                        seciliIkon: ikonBul(
                          ozelSayfalar[i].data()['ikon']?.toString(),
                        ),
                        baslik: (ozelSayfalar[i].data()['ad'] ?? '').toString(),
                        index: 2 + i,
                        renk: Color(
                          (ozelSayfalar[i].data()['renk'] ??
                                  AppRenk.indigo.value)
                              as int,
                        ),
                      ),
                  ],

                  const SizedBox(height: 10),
                  const Divider(indent: 20, endIndent: 20),
                  const SizedBox(height: 4),
                  _menuOge(
                    ikon: Icons.settings_outlined,
                    seciliIkon: Icons.settings,
                    baslik: 'Ayarlar',
                    index: ayarlarIndex,
                    renk: AppRenk.indigo,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'TÜMTİS',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade400,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuOge({
    required IconData ikon,
    required IconData seciliIkon,
    required String baslik,
    required int index,
    required Color renk,
  }) {
    final aktif = secili == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: aktif ? renk.withOpacity(0.09) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSec(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  aktif ? seciliIkon : ikon,
                  size: 21,
                  color: aktif ? renk : Colors.grey.shade600,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    baslik,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                      color: aktif ? renk : Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
