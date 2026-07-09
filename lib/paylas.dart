import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';

class Paylas {
  static Future<bool> whatsapp(String metin) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(metin)}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> eposta(String metin) async {
    final uri = Uri.parse('mailto:?body=${Uri.encodeComponent(metin)}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> kopyala(BuildContext context, String metin) async {
    await Clipboard.setData(ClipboardData(text: metin));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Panoya kopyalandı')));
    }
  }

  static void menu(BuildContext context, String metin) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF25D366),
                child: Icon(Icons.chat, color: Colors.white, size: 20),
              ),
              title: const Text('WhatsApp ile paylaş'),
              onTap: () async {
                Navigator.pop(sheet);
                final ok = await whatsapp(metin);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('WhatsApp açılamadı')),
                  );
                }
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppRenk.indigo.withOpacity(0.12),
                child: const Icon(
                  Icons.mail_outline,
                  color: AppRenk.indigo,
                  size: 20,
                ),
              ),
              title: const Text('E-posta ile gönder'),
              onTap: () async {
                Navigator.pop(sheet);
                await eposta(metin);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey.shade200,
                child: Icon(Icons.copy, color: Colors.grey.shade700, size: 20),
              ),
              title: const Text('Panoya kopyala'),
              onTap: () {
                Navigator.pop(sheet);
                kopyala(context, metin);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
