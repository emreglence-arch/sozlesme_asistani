import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';

/// Özel sayfa tanımlarını yöneten servis.
class OzelSayfalarServisi {
  static CollectionReference<Map<String, dynamic>> ref() =>
      FirebaseFirestore.instance.collection('ozelSayfalar');

  static Stream<QuerySnapshot<Map<String, dynamic>>> akis() =>
      ref().orderBy('sira').snapshots();

  static Future<void> ekle({
    required String ad,
    required String ikonAdi,
    required int renk,
    required int sira,
  }) => ref().add({
    'ad': ad,
    'ikon': ikonAdi,
    'renk': renk,
    'sira': sira,
    'olusturma': FieldValue.serverTimestamp(),
  });

  static Future<void> guncelle(String id, Map<String, dynamic> veri) =>
      ref().doc(id).update(veri);

  static Future<void> sil(String id) => ref().doc(id).delete();
}

/// Seçilebilir ikonlar (ad -> IconData)
const Map<String, IconData> ozelIkonlar = {
  'folder': Icons.folder_outlined,
  'gavel': Icons.gavel,
  'book': Icons.menu_book_outlined,
  'balance': Icons.balance,
  'school': Icons.school_outlined,
  'groups': Icons.groups_outlined,
  'event': Icons.event_note_outlined,
  'campaign': Icons.campaign_outlined,
  'assignment': Icons.assignment_outlined,
  'archive': Icons.archive_outlined,
  'flag': Icons.flag_outlined,
  'star': Icons.star_outline,
};

/// Seçilebilir renkler
const List<Color> ozelRenkler = [
  AppRenk.indigo,
  AppRenk.emerald,
  AppRenk.amber,
  Color(0xFFEF4444), // kırmızı
  Color(0xFF8B5CF6), // mor
  Color(0xFF0EA5E9), // gök mavisi
  Color(0xFF64748B), // gri
];

IconData ikonBul(String? ad) =>
    ozelIkonlar[ad ?? 'folder'] ?? Icons.folder_outlined;
