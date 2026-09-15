import 'package:shared_preferences/shared_preferences.dart';

/// API anahtarını cihazda saklar (buluta gitmez).
class AyarlarServisi {
  static const _anahtarKey = 'gemini_api_anahtari';

  static Future<String?> anahtarAl() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_anahtarKey);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  static Future<void> anahtarKaydet(String anahtar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_anahtarKey, anahtar.trim());
  }

  static Future<void> anahtarSil() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_anahtarKey);
  }

  // ---------- Kayıt metni yazı boyutu ----------
  static const _yaziBoyutuKey = 'kayit_yazi_boyutu';
  static const yaziBoyutuVarsayilan = 13.0;
  static const yaziBoyutuEnAz = 11.0;
  static const yaziBoyutuEnCok = 24.0;

  static Future<double> yaziBoyutuAl() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble(_yaziBoyutuKey) ?? yaziBoyutuVarsayilan;
    return v.clamp(yaziBoyutuEnAz, yaziBoyutuEnCok);
  }

  static Future<void> yaziBoyutuKaydet(double boyut) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      _yaziBoyutuKey,
      boyut.clamp(yaziBoyutuEnAz, yaziBoyutuEnCok),
    );
  }
}
