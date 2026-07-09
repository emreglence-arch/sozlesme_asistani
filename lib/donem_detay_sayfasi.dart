import 'package:flutter/material.dart';
import 'main.dart';
import 'donem_bilgiler_sekmesi.dart';
import 'donem_asistan_sekmesi.dart';
import 'donem_maddeler_sekmesi.dart';
import 'donem_belgeler_sekmesi.dart';

class DonemDetaySayfasi extends StatelessWidget {
  final String isyeriId;
  final String donemId;
  final String donemBaslik;
  final String isyeriAdi;

  const DonemDetaySayfasi({
    super.key,
    required this.isyeriId,
    required this.donemId,
    required this.donemBaslik,
    this.isyeriAdi = '',
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(donemBaslik),
          backgroundColor: AppRenk.indigo,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: AppRenk.amber,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Özet'),
              Tab(icon: Icon(Icons.auto_awesome), text: 'Asistan'),
              Tab(icon: Icon(Icons.article_outlined), text: 'TİS Metni'),
              Tab(icon: Icon(Icons.folder_outlined), text: 'Belgeler'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DonemBilgilerSekmesi(isyeriId: isyeriId, donemId: donemId),
            DonemAsistanSekmesi(
              isyeriId: isyeriId,
              donemId: donemId,
              isyeriAdi: isyeriAdi,
              donemBaslik: donemBaslik,
            ),
            DonemMaddelerSekmesi(isyeriId: isyeriId, donemId: donemId),
            DonemBelgelerSekmesi(isyeriId: isyeriId, donemId: donemId),
          ],
        ),
      ),
    );
  }
}
