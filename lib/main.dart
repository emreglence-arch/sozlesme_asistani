import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'ana_kabuk.dart';
import 'giris_ekrani.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'kullanici_servisi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SozlesmeApp());
}

class AppRenk {
  static const indigo = Color(0xFF6366F1);
  static const amber = Color(0xFFF59E0B);
  static const emerald = Color(0xFF10B981);
  static const arkaPlan = Color(0xFFF8FAFC);
}

class SozlesmeApp extends StatelessWidget {
  const SozlesmeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sözleşme Asistanı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppRenk.indigo,
          primary: AppRenk.indigo,
        ),
        scaffoldBackgroundColor: AppRenk.arkaPlan,
        useMaterial3: true,
        fontFamily: 'Segoe UI',
      ),
      home: const AuthKapisi(),
    );
  }
}

/// Giriş yapılmış mı diye bakar:
/// - Yapılmışsa AnaKabuk (uygulama)
/// - Yapılmamışsa GirisEkrani
class AuthKapisi extends StatelessWidget {
  const AuthKapisi({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppRenk.arkaPlan,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Giriş yapılmamış → giriş ekranı
        final user = snapshot.data;
        if (user == null) {
          return const GirisEkrani();
        }

        // Giriş yapılmış → onaylı mı diye bak
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: KullaniciServisi.benimKaydim(user.uid),
          builder: (context, kayitSnap) {
            if (kayitSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppRenk.arkaPlan,
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final veri = kayitSnap.data?.data();
            final onayli = veri?['onayli'] == true;

            if (onayli) {
              return const AnaKabuk();
            }
            return const OnayBekleniyorEkrani();
          },
        );
      },
    );
  }
}

/// Kayıt olmuş ama henüz onaylanmamış kullanıcıya gösterilir.
class OnayBekleniyorEkrani extends StatelessWidget {
  const OnayBekleniyorEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final eposta = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: AppRenk.arkaPlan,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppRenk.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.hourglass_top,
                    color: AppRenk.amber,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Onay Bekleniyor',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  'Hesabınız oluşturuldu ($eposta), ancak erişim için '
                  'yönetici onayı gerekiyor. Onaylandığında giriş '
                  'yapabileceksiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Çıkış Yap'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
