import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'kullanici_servisi.dart';

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final _epostaC = TextEditingController();
  final _sifreC = TextEditingController();
  bool _yukleniyor = false;
  bool _sifreGizli = true;
  bool _kayitModu = false; // false: giriş, true: kayıt
  String? _hata;
  String? _bilgi;

  Future<void> _gonder() async {
    final eposta = _epostaC.text.trim();
    final sifre = _sifreC.text;
    if (eposta.isEmpty || sifre.isEmpty) {
      setState(() => _hata = 'E-posta ve şifre girin.');
      return;
    }
    if (_kayitModu && sifre.length < 6) {
      setState(() => _hata = 'Şifre en az 6 karakter olmalı.');
      return;
    }

    setState(() {
      _yukleniyor = true;
      _hata = null;
      _bilgi = null;
    });

    try {
      if (_kayitModu) {
        // KAYIT
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: eposta,
          password: sifre,
        );
        if (cred.user != null) {
          await KullaniciServisi.kayitOlustur(cred.user!);
        }
        // Kayıt sonrası kullanıcı otomatik giriş yapmış olur;
        // AuthKapisi onaysız olduğu için "Onay Bekleniyor" ekranına gider.
      } else {
        // GİRİŞ
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: eposta,
          password: sifre,
        );
      }
    } on FirebaseAuthException catch (e) {
      String mesaj;
      switch (e.code) {
        case 'invalid-email':
          mesaj = 'Geçersiz e-posta adresi.';
          break;
        case 'email-already-in-use':
          mesaj = 'Bu e-posta zaten kayıtlı. Giriş yapmayı deneyin.';
          break;
        case 'weak-password':
          mesaj = 'Şifre çok zayıf. En az 6 karakter kullanın.';
          break;
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          mesaj = 'E-posta veya şifre hatalı.';
          break;
        case 'user-disabled':
          mesaj = 'Bu hesap devre dışı bırakılmış.';
          break;
        case 'too-many-requests':
          mesaj = 'Çok fazla deneme. Biraz bekleyip tekrar deneyin.';
          break;
        default:
          mesaj = 'İşlem başarısız: ${e.code}';
      }
      setState(() => _hata = mesaj);
    } catch (e) {
      setState(() => _hata = 'Bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _moduDegistir() {
    setState(() {
      _kayitModu = !_kayitModu;
      _hata = null;
      _bilgi = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppRenk.arkaPlan,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppRenk.indigo,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.gavel, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Sözleşme Asistanı',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  _kayitModu
                      ? 'Yeni hesap oluşturun'
                      : 'Devam etmek için giriş yapın',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        TextField(
                          controller: _epostaC,
                          keyboardType: TextInputType.emailAddress,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'E-posta',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _gonder(),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _sifreC,
                          obscureText: _sifreGizli,
                          decoration: InputDecoration(
                            labelText: 'Şifre',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            helperText: _kayitModu ? 'En az 6 karakter' : null,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _sifreGizli
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _sifreGizli = !_sifreGizli),
                            ),
                          ),
                          onSubmitted: (_) => _gonder(),
                        ),
                        if (_hata != null) ...[
                          const SizedBox(height: 16),
                          _kutu(_hata!, Colors.red),
                        ],
                        if (_bilgi != null) ...[
                          const SizedBox(height: 16),
                          _kutu(_bilgi!, AppRenk.emerald),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            onPressed: _yukleniyor ? null : _gonder,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppRenk.indigo,
                            ),
                            child: _yukleniyor
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _kayitModu ? 'Hesap Oluştur' : 'Giriş Yap',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _yukleniyor ? null : _moduDegistir,
                          child: Text(
                            _kayitModu
                                ? 'Zaten hesabım var — Giriş yap'
                                : 'Hesabın yok mu? Kayıt ol',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_kayitModu) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Kayıt sonrası hesabınız yönetici onayı bekler. '
                    'Onaylandığında giriş yapabilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kutu(String metin, Color renk) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: renk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(metin, style: TextStyle(fontSize: 13, color: renk)),
          ),
        ],
      ),
    );
  }
}
