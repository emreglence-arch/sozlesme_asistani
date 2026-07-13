import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'isyeri_genel_sekmesi.dart';
import 'isyeri_kisiler_sekmesi.dart';
import 'isyeri_notlar_sekmesi.dart';
import 'ozel_sayfa_ekrani.dart';

class IsyeriSayfasi extends StatelessWidget {
  final String isyeriId;
  final String isyeriAdi;

  const IsyeriSayfasi({
    super.key,
    required this.isyeriId,
    required this.isyeriAdi,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('isyerleri')
          .doc(isyeriId)
          .snapshots(),
      builder: (context, snapshot) {
        final ad = (snapshot.data?.data()?['ad'] ?? isyeriAdi).toString();

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(ad),
              backgroundColor: AppRenk.indigo,
              foregroundColor: Colors.white,
              bottom: const TabBar(
                isScrollable: true,
                indicatorColor: AppRenk.amber,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(icon: Icon(Icons.business_outlined), text: 'Genel'),
                  Tab(icon: Icon(Icons.contacts_outlined), text: 'Detay'),
                  Tab(icon: Icon(Icons.folder_outlined), text: 'Belgeler'),
                  Tab(icon: Icon(Icons.sticky_note_2_outlined), text: 'Notlar'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                IsyeriGenelSekmesi(isyeriId: isyeriId, isyeriAdi: isyeriAdi),
                IsyeriKisilerSekmesi(isyeriId: isyeriId),
                OzelSayfaEkrani(
                  sayfaId: isyeriId,
                  sayfaAdi: 'Belgeler',
                  renk: AppRenk.indigo,
                  ikon: Icons.folder_outlined,
                  basligiGoster: false,
                  kokRef: FirebaseFirestore.instance
                      .collection('isyerleri')
                      .doc(isyeriId)
                      .collection('belgeAlani')
                      .doc('kok'),
                ),
                IsyeriNotlarSekmesi(isyeriId: isyeriId),
              ],
            ),
          ),
        );
      },
    );
  }
}
