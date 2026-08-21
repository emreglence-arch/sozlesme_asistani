import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Platforma göre dosya kaydeder.
/// - Windows/masaüstü: "nereye kaydedeyim?" penceresi açar.
/// - Android/iOS: doğrudan İndirilenler (ya da erişilebilir) klasöre yazar.
///
/// [context] SnackBar mesajı için, [bytes] dosya içeriği, [dosyaAdi] uzantılı ad.
Future<void> dosyaKaydet({
  required BuildContext context,
  required List<int> bytes,
  required String dosyaAdi,
  String dialogBaslik = 'Dosyayı kaydet',
}) async {
  try {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // MOBİL: İndirilenler klasörüne yaz
      Directory? hedefKlasor;

      if (Platform.isAndroid) {
        // Android'de genel İndirilenler klasörü
        hedefKlasor = Directory('/storage/emulated/0/Download');
        if (!await hedefKlasor.exists()) {
          // Bulunamazsa uygulamanın kendi indirme/dokuman klasörüne düş
          hedefKlasor =
              await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory();
        }
      } else {
        // iOS: uygulama dokuman klasörü
        hedefKlasor = await getApplicationDocumentsDirectory();
      }

      // Aynı isim varsa üzerine yazmamak için numara ekle
      var hedefYol = '${hedefKlasor.path}/$dosyaAdi';
      hedefYol = await _benzersizYol(hedefYol);

      final dosya = File(hedefYol);
      await dosya.writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'İndirilenler klasörüne kaydedildi: '
              '${hedefYol.split('/').last}',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else {
      // MASAÜSTÜ (Windows/macOS/Linux): konum sor
      final hedef = await FilePicker.saveFile(
        dialogTitle: dialogBaslik,
        fileName: dosyaAdi,
      );
      if (hedef == null) return; // kullanıcı vazgeçti
      await File(hedef).writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydedildi: ${hedef.split('\\').last}')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kaydetme hatası: $e')));
    }
  }
}

/// Aynı isimde dosya varsa "ad (1).uzanti" gibi benzersiz yol üretir.
Future<String> _benzersizYol(String yol) async {
  if (!await File(yol).exists()) return yol;

  final nokta = yol.lastIndexOf('.');
  final taban = nokta == -1 ? yol : yol.substring(0, nokta);
  final uzanti = nokta == -1 ? '' : yol.substring(nokta);

  var i = 1;
  while (await File('$taban ($i)$uzanti').exists()) {
    i++;
  }
  return '$taban ($i)$uzanti';
}
