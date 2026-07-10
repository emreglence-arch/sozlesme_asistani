import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'ayarlar_servisi.dart';
import 'ozel_sayfalar_servisi.dart';

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
                'Anahtar yalnızca bu cihazda saklanır.',
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
  }

  // ---------- ÖZEL SAYFA ----------
  Future<void> _sayfaDialog({
    DocumentSnapshot<Map<String, dynamic>>? mevcut,
    int sira = 0,
  }) async {
    final v = mevcut?.data() ?? {};
    final adC = TextEditingController(text: (v['ad'] ?? '').toString());
    String ikon = (v['ikon'] ?? 'folder').toString();
    int renk = (v['renk'] ?? AppRenk.indigo.value) as int;

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text(mevcut == null ? 'Yeni Sayfa' : 'Sayfayı Düzenle'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: adC,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Sayfa adı',
                      hintText: 'Örn. Mevzuat',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Simge',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ozelIkonlar.entries.map((e) {
                      final aktif = ikon == e.key;
                      return InkWell(
                        onTap: () => setSt(() => ikon = e.key),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: aktif
                                ? Color(renk).withOpacity(0.15)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: aktif
                                ? Border.all(color: Color(renk), width: 2)
                                : null,
                          ),
                          child: Icon(
                            e.value,
                            size: 21,
                            color: aktif ? Color(renk) : Colors.grey.shade600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Renk',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: ozelRenkler.map((c) {
                      final aktif = renk == c.value;
                      return InkWell(
                        onTap: () => setSt(() => renk = c.value),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: aktif
                                ? Border.all(color: Colors.black87, width: 2.5)
                                : null,
                          ),
                          child: aktif
                              ? const Icon(
                                  Icons.check,
                                  size: 17,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(mevcut == null ? 'Oluştur' : 'Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (kaydet != true || adC.text.trim().isEmpty) return;

    if (mevcut == null) {
      await OzelSayfalarServisi.ekle(
        ad: adC.text.trim(),
        ikonAdi: ikon,
        renk: renk,
        sira: sira,
      );
    } else {
      await OzelSayfalarServisi.guncelle(mevcut.id, {
        'ad': adC.text.trim(),
        'ikon': ikon,
        'renk': renk,
      });
    }
  }

  Future<void> _sayfaSil(String id, String ad) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sayfayı sil'),
        content: Text(
          '"$ad" sayfası ve içindeki tüm klasör/kayıtlar silinsin mi? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (onay == true) await OzelSayfalarServisi.sil(id);
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

          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 20),
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

          // ---- Özel sayfalar ----
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: OzelSayfalarServisi.akis(),
            builder: (context, snap) {
              final sayfalar = snap.data?.docs ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Özel Sayfalar',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _sayfaDialog(sira: sayfalar.length),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Sayfa Oluştur'),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 2),
                    child: Text(
                      'Kendi sayfalarınızı oluşturun; sol menüde görünür.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  if (sayfalar.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 26,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.dashboard_customize_outlined,
                            size: 44,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Henüz özel sayfa yok',
                            style: TextStyle(
                              fontSize: 14.5,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Örn. Mevzuat, Toplantılar, Eğitimler',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...sayfalar.map((s) {
                      final v = s.data();
                      final ad = (v['ad'] ?? '').toString();
                      final renk = Color(
                        (v['renk'] ?? AppRenk.indigo.value) as int,
                      );
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: renk.withOpacity(0.12),
                            child: Icon(
                              ikonBul(v['ikon']?.toString()),
                              color: renk,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            ad,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (x) {
                              if (x == 'duzenle') _sayfaDialog(mevcut: s);
                              if (x == 'sil') _sayfaSil(s.id, ad);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'duzenle',
                                child: Text('Düzenle'),
                              ),
                              PopupMenuItem(value: 'sil', child: Text('Sil')),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),

          const SizedBox(height: 20),
          _yakinda(
            Icons.table_chart_outlined,
            'Tabloya Dönüştür',
            'Sözleşme bilgilerini Excel/PDF olarak çıkar',
          ),
          _yakinda(Icons.lock_outline, 'Güvenli Giriş', 'Şifre ile koruma'),
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
