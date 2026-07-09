import 'package:flutter/material.dart';
import 'main.dart';
import 'ayarlar_servisi.dart';

class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({super.key});

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  String? _anahtar;
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _anahtarYukle();
  }

  Future<void> _anahtarYukle() async {
    final a = await AyarlarServisi.anahtarAl();
    if (mounted) {
      setState(() {
        _anahtar = a;
        _yukleniyor = false;
      });
    }
  }

  String _maskele(String a) {
    if (a.length <= 10) return '••••••';
    return '${a.substring(0, 6)}••••••${a.substring(a.length - 4)}';
  }

  Future<void> _anahtarDuzenle() async {
    final c = TextEditingController(text: _anahtar ?? '');
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gemini API Anahtarı'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: c,
                autofocus: true,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'API anahtarı',
                  hintText: 'AIza... ile başlayan anahtarı yapıştırın',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Anahtarı aistudio.google.com/apikey adresinden alabilirsiniz. '
                'Anahtar yalnızca bu cihazda saklanır, buluta gönderilmez.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (kaydet != true) return;
    final yeni = c.text.trim();
    if (yeni.isEmpty) {
      await AyarlarServisi.anahtarSil();
    } else {
      await AyarlarServisi.anahtarKaydet(yeni);
    }
    await _anahtarYukle();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            yeni.isEmpty ? 'Anahtar silindi' : 'Anahtar kaydedildi',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final varMi = _anahtar != null;

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

          // API anahtarı kartı
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: Icon(
                Icons.key,
                color: varMi ? AppRenk.emerald : Colors.grey,
              ),
              title: const Text(
                'AI API Anahtarı',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: _yukleniyor
                  ? const Text('Yükleniyor...')
                  : Text(
                      varMi ? _maskele(_anahtar!) : 'Henüz girilmedi',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: varMi ? AppRenk.emerald : Colors.grey,
                      ),
                    ),
              trailing: TextButton(
                onPressed: _yukleniyor ? null : _anahtarDuzenle,
                child: Text(varMi ? 'Değiştir' : 'Ekle'),
              ),
            ),
          ),

          const SizedBox(height: 8),
          _yakinda(
            Icons.table_chart_outlined,
            'Tabloya Dönüştür',
            'Sözleşme bilgilerini Excel/PDF olarak çıkar',
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
