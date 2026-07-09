import 'package:flutter/material.dart';
import 'main.dart';

class AyarlarEkrani extends StatelessWidget {
  const AyarlarEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppRenk.arkaPlan,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Ayarlar',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          _yakinda(
            Icons.table_chart_outlined,
            'Tabloya Dönüştür',
            'Sözleşme bilgilerini Excel/PDF olarak çıkar',
          ),
          _yakinda(
            Icons.smart_toy_outlined,
            'Yapay Zekâ Asistanı',
            'Sözleşmelere soru sor',
          ),
          _yakinda(Icons.lock_outline, 'Güvenli Giriş', 'Şifre ile koruma'),
          _yakinda(
            Icons.backup_outlined,
            'Yedekleme',
            'Otomatik yedek ve dışa aktarma',
          ),
        ],
      ),
    );
  }

  Widget _yakinda(IconData ikon, String baslik, String alt) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(ikon, color: AppRenk.indigo),
        title: Text(
          baslik,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(alt, style: const TextStyle(fontSize: 12.5)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: AppRenk.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'yakında',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppRenk.amber,
            ),
          ),
        ),
      ),
    );
  }
}
