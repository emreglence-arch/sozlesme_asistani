import 'package:cloud_firestore/cloud_firestore.dart';

/// Asistan örnek sorularını global olarak Firestore'da tutar.
/// Konum: ayarlar/asistan  ->  { tisSorulari: [...] }
class AsistanAyarlariServisi {
  static DocumentReference<Map<String, dynamic>> _ref() =>
      FirebaseFirestore.instance.collection('ayarlar').doc('asistan');

  static const varsayilanTisSorulari = [
    'Yemek ücreti ne kadar?',
    'Temsilci izinleri nasıl düzenlenmiş?',
    'Doğum izni ne kadar?',
    'İkramiye kaç maaş?',
  ];

  /// Canlı dinleme
  static Stream<List<String>> tisSorulariAkis() {
    return _ref().snapshots().map((snap) {
      final raw = snap.data()?['tisSorulari'];
      if (raw is List && raw.isNotEmpty) {
        return raw.map((e) => e.toString()).toList();
      }
      return varsayilanTisSorulari;
    });
  }

  static Future<void> tisSorulariKaydet(List<String> sorular) async {
    await _ref().set({'tisSorulari': sorular}, SetOptions(merge: true));
  }
}
