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
}
