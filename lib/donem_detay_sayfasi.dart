import 'package:flutter/material.dart';
import 'main.dart';
import 'donem_bilgiler_sekmesi.dart';
import 'donem_maddeler_sekmesi.dart';

class DonemDetaySayfasi extends StatelessWidget {
  final String isyeriId;
  final String donemId;
  final String donemBaslik;

  const DonemDetaySayfasi({
    super.key,
    required this.isyeriId,
    required this.donemId,
    required this.donemBaslik,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
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
              Tab(icon: Icon(Icons.info_outline), text: 'Bilgiler'),
              Tab(icon: Icon(Icons.article_outlined), text: 'TİS Metni'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DonemBilgilerSekmesi(isyeriId: isyeriId, donemId: donemId),
            DonemMaddelerSekmesi(isyeriId: isyeriId, donemId: donemId),
          ],
        ),
      ),
    );
  }
}
