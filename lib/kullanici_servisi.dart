import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Kullanıcı onay ve yönetici bilgisini Firestore'da tutar.
/// Konum: kullanicilar/{uid} -> { eposta, onayli, yonetici, olusturma }
class KullaniciServisi {
  static CollectionReference<Map<String, dynamic>> _ref() =>
      FirebaseFirestore.instance.collection('kullanicilar');

  /// Kayıt anında çağrılır: onaysız bir kullanıcı kaydı oluşturur.
  static Future<void> kayitOlustur(User user) async {
    final doc = _ref().doc(user.uid);
    final mevcut = await doc.get();
    if (mevcut.exists) return; // zaten var, dokunma
    await doc.set({
      'eposta': user.email ?? '',
      'onayli': false,
      'yonetici': false,
      'olusturma': FieldValue.serverTimestamp(),
    });
  }

  /// Bu kullanıcının kaydını canlı dinler (onaylı mı, yönetici mi?)
  static Stream<DocumentSnapshot<Map<String, dynamic>>> benimKaydim(
    String uid,
  ) {
    return _ref().doc(uid).snapshots();
  }

  /// Onay bekleyenler (onayli == false)
  static Stream<QuerySnapshot<Map<String, dynamic>>> bekleyenler() {
    return _ref().where('onayli', isEqualTo: false).snapshots();
  }

  /// Onaylı kullanıcılar
  static Stream<QuerySnapshot<Map<String, dynamic>>> onaylilar() {
    return _ref().where('onayli', isEqualTo: true).snapshots();
  }

  static Future<void> onayla(String uid) =>
      _ref().doc(uid).update({'onayli': true});

  static Future<void> reddet(String uid) => _ref().doc(uid).delete();

  /// Onaylı bir kullanıcının erişimini geri al
  static Future<void> onayiKaldir(String uid) =>
      _ref().doc(uid).update({'onayli': false});
}
