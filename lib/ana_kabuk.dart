import 'package:flutter/material.dart';
import 'main.dart';
import 'isyerleri_ekrani.dart';
import 'guncel_tisler_ekrani.dart';
import 'ayarlar_ekrani.dart';

class AnaKabuk extends StatefulWidget {
  const AnaKabuk({super.key});

  @override
  State<AnaKabuk> createState() => _AnaKabukState();
}

class _AnaKabukState extends State<AnaKabuk> {
  int _secili = 0;

  static const _basliklar = ['İşyerleri', 'Güncel TİS\'ler', 'Ayarlar'];

  Widget _icerik() {
    switch (_secili) {
      case 1:
        return const GuncelTislerEkrani();
      case 2:
        return const AyarlarEkrani();
      default:
        return const IsyerleriEkrani();
    }
  }

  @override
  Widget build(BuildContext context) {
    final genis = MediaQuery.of(context).size.width >= 800;

    final menu = _YanMenu(
      secili: _secili,
      onSec: (i) {
        setState(() => _secili = i);
        if (!genis) Navigator.pop(context);
      },
    );

    return Scaffold(
      appBar: genis
          ? null
          : AppBar(
              title: Text(_basliklar[_secili]),
              backgroundColor: AppRenk.indigo,
              foregroundColor: Colors.white,
            ),
      drawer: genis ? null : Drawer(child: menu),
      body: genis
          ? Row(
              children: [
                SizedBox(width: 250, child: menu),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: _icerik()),
              ],
            )
          : _icerik(),
    );
  }
}

class _YanMenu extends StatelessWidget {
  final int secili;
  final ValueChanged<int> onSec;

  const _YanMenu({required this.secili, required this.onSec});

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
            _menuOge(
              ikon: Icons.business_outlined,
              seciliIkon: Icons.business,
              baslik: 'İşyerleri',
              index: 0,
            ),
            _menuOge(
              ikon: Icons.verified_outlined,
              seciliIkon: Icons.verified,
              baslik: 'Güncel TİS\'ler',
              index: 1,
            ),
            _menuOge(
              ikon: Icons.settings_outlined,
              seciliIkon: Icons.settings,
              baslik: 'Ayarlar',
              index: 2,
            ),
            const Spacer(),
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
  }) {
    final aktif = secili == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: aktif ? AppRenk.indigo.withOpacity(0.09) : Colors.transparent,
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
                  color: aktif ? AppRenk.indigo : Colors.grey.shade600,
                ),
                const SizedBox(width: 14),
                Text(
                  baslik,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                    color: aktif ? AppRenk.indigo : Colors.grey.shade800,
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
