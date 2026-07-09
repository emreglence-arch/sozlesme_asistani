import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'isyeri_sayfasi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SozlesmeAsistaniApp());
}

// Renkleri tek yerden yönetiyoruz; sonra her ekranda aynısını kullanacağız.
class AppRenk {
  static const indigo = Color(0xFF6366F1);
  static const amber = Color(0xFFF59E0B);
  static const emerald = Color(0xFF10B981);
  static const arkaPlan = Color(0xFFF8FAFC);
}

class SozlesmeAsistaniApp extends StatelessWidget {
  const SozlesmeAsistaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sözleşme Asistanı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppRenk.indigo),
        scaffoldBackgroundColor: AppRenk.arkaPlan,
        useMaterial3: true,
      ),
      home: const AnaEkran(),
    );
  }
}

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  String _aramaMetni = '';

  // Yeni işyeri ekleme penceresi
  Future<void> _isyeriEkle() async {
    final controller = TextEditingController();
    final ad = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni İşyeri'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'İşyeri adı',
            hintText: 'Örn. DHL Supply Chain Lojistik Hizmetler A.Ş.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (ad != null && ad.isNotEmpty) {
      await FirebaseFirestore.instance.collection('isyerleri').add({
        'ad': ad,
        'olusturmaTarihi': FieldValue.serverTimestamp(),
      });
    }
  }

  // İşyeri silme (onay isteyerek)
  Future<void> _isyeriSil(String id, String ad) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İşyerini sil'),
        content: Text('"$ad" silinsin mi? Bu işlem geri alınamaz.'),
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
    if (onay == true) {
      await FirebaseFirestore.instance.collection('isyerleri').doc(id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sözleşme Asistanı'),
        backgroundColor: AppRenk.indigo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isyeriEkle,
        backgroundColor: AppRenk.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('İşyeri Ekle'),
      ),
      body: Column(
        children: [
          // Arama çubuğu
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _aramaMetni = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'İşyeri ara (örn. Kühne Nagel)',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // İşyeri listesi (buluttan canlı gelir)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('isyerleri')
                  .orderBy('ad')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Hata: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tumu = snapshot.data!.docs;
                if (tumu.isEmpty) {
                  return _bosDurum();
                }

                // Arama filtresi
                final liste = tumu.where((d) {
                  final ad = (d['ad'] as String).toLowerCase();
                  return ad.contains(_aramaMetni);
                }).toList();

                if (liste.isEmpty) {
                  return const Center(child: Text('Sonuç bulunamadı'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  itemCount: liste.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final belge = liste[i];
                    final ad = belge['ad'] as String;
                    final ilkHarf = ad.isNotEmpty ? ad[0].toUpperCase() : '?';

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppRenk.indigo,
                          child: Text(
                            ilkHarf,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          ad,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (deger) {
                            if (deger == 'sil') {
                              _isyeriSil(belge.id, ad);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'sil', child: Text('Sil')),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => IsyeriSayfasi(
                                isyeriId: belge.id,
                                isyeriAdi: ad,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Liste bomboşken gösterilen ekran
  Widget _bosDurum() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.business_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Henüz işyeri eklenmedi',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            'Sağ alttaki "İşyeri Ekle" ile başla',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
