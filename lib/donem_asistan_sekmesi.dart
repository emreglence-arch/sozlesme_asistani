import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'ayarlar_servisi.dart';
import 'paylas.dart';

class DonemAsistanSekmesi extends StatefulWidget {
  final String isyeriId;
  final String donemId;
  final String isyeriAdi;
  final String donemBaslik;

  const DonemAsistanSekmesi({
    super.key,
    required this.isyeriId,
    required this.donemId,
    required this.isyeriAdi,
    required this.donemBaslik,
  });

  @override
  State<DonemAsistanSekmesi> createState() => _DonemAsistanSekmesiState();
}

class _Mesaj {
  final String metin;
  final bool benden;
  _Mesaj(this.metin, this.benden);
}

class _DonemAsistanSekmesiState extends State<DonemAsistanSekmesi> {
  final _soruC = TextEditingController();
  final _kaydirma = ScrollController();
  final List<_Mesaj> _mesajlar = [];
  bool _bekleniyor = false;
  String? _anahtar;
  bool _hazir = false;

  static const _ornekSorular = [
    'Yemek ücreti ne kadar?',
    'Temsilci izinleri nasıl düzenlenmiş?',
    'Doğum izni ne kadar?',
    'İkramiye kaç maaş?',
  ];

  @override
  void initState() {
    super.initState();
    _anahtarKontrol();
  }

  Future<void> _anahtarKontrol() async {
    final a = await AyarlarServisi.anahtarAl();
    if (mounted)
      setState(() {
        _anahtar = a;
        _hazir = true;
      });
  }

  DocumentReference<Map<String, dynamic>> _donemRef() => FirebaseFirestore
      .instance
      .collection('isyerleri')
      .doc(widget.isyeriId)
      .collection('donemler')
      .doc(widget.donemId);

  // Sözleşme bağlamını hazırla (maddeler + özet tablosu)
  Future<String> _baglamHazirla() async {
    final snap = await _donemRef().get();
    final veri = snap.data() ?? {};
    final buf = StringBuffer();

    buf.writeln('İŞYERİ: ${widget.isyeriAdi}');
    buf.writeln('SÖZLEŞME DÖNEMİ: ${widget.donemBaslik}');
    final bas = (veri['baslangicYili'] ?? '').toString();
    final bit = (veri['bitisYili'] ?? '').toString();
    if (bas.isNotEmpty) buf.writeln('YÜRÜRLÜK: $bas - $bit');
    buf.writeln();

    // Özet tablosu
    final kategoriler = veri['kategoriler'];
    if (kategoriler is List && kategoriler.isNotEmpty) {
      buf.writeln('=== ÖZET TABLOSU (girilen rakamlar) ===');
      for (final k in kategoriler) {
        final kat = Map<String, dynamic>.from(k as Map);
        buf.writeln('\n[${kat['ad']}]');
        final not = (kat['not'] ?? '').toString();
        if (not.isNotEmpty) buf.writeln('Not: $not');
        final zamlar = kat['zamlar'];
        if (zamlar is Map) {
          zamlar.forEach((yil, kural) {
            if (kural.toString().isNotEmpty) {
              buf.writeln('$yil. yıl zam kuralı: $kural');
            }
          });
        }
        final kalemler = kat['kalemler'];
        if (kalemler is List) {
          for (final x in kalemler) {
            final kal = Map<String, dynamic>.from(x as Map);
            final ad = kal['ad'];
            final yil1 = (kal['yil1'] ?? '').toString();
            buf.write('- $ad: 1. yıl = ${yil1.isEmpty ? "girilmemiş" : yil1}');
            final ov = kal['overrides'];
            if (ov is Map) {
              ov.forEach((yil, deger) {
                if (deger.toString().isNotEmpty) {
                  buf.write(' | $yil. yıl = $deger');
                }
              });
            }
            buf.writeln();
          }
        }
      }
      buf.writeln();
    }

    // TİS metni
    final maddeler = veri['maddeler'];
    if (maddeler is List && maddeler.isNotEmpty) {
      buf.writeln('=== SÖZLEŞME METNİ ===');
      for (final m in maddeler) {
        final mad = Map<String, dynamic>.from(m as Map);
        final bolum = (mad['bolum'] ?? '').toString();
        final baslik = (mad['baslik'] ?? '').toString();
        final icerik = (mad['icerik'] ?? '').toString();
        buf.writeln('\n--- $baslik ${bolum.isNotEmpty ? "($bolum)" : ""}');
        buf.writeln(icerik);
      }
    }

    return buf.toString();
  }

  Future<void> _sor(String soru) async {
    if (soru.trim().isEmpty || _bekleniyor) return;
    if (_anahtar == null) return;

    setState(() {
      _mesajlar.add(_Mesaj(soru.trim(), true));
      _bekleniyor = true;
    });
    _soruC.clear();
    _asagiKaydir();

    try {
      final baglam = await _baglamHazirla();

      final sistem =
          '''
Sen bir toplu iş sözleşmesi (TİS) uzmanısın. Aşağıda bir sözleşmenin özet tablosu ve tam metni verilmiştir. Kullanıcının sorularını SADECE bu belgeye dayanarak yanıtla.

KURALLAR:
- Cevabını verirken mutlaka dayandığın madde numarasını belirt. Örnek: "(Madde 37)"
- Rakamlar için önce özet tablosuna, yoksa metne bak.
- Belgede olmayan bir şey sorulursa açıkça "Bu sözleşmede bu konuda hüküm bulamadım" de. Asla tahmin etme veya genel bilgi verme.
- Türkçe, kısa ve net yanıtla.

=== BELGE ===
$baglam
=== BELGE SONU ===
''';

      // Sohbet geçmişi
      final contents = <Map<String, dynamic>>[];
      for (var i = 0; i < _mesajlar.length; i++) {
        final m = _mesajlar[i];
        contents.add({
          'role': m.benden ? 'user' : 'model',
          'parts': [
            {'text': m.metin},
          ],
        });
      }

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_anahtar',
      );

      final yanit = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {
            'parts': [
              {'text': sistem},
            ],
          },
          'contents': contents,
          'generationConfig': {'temperature': 0.2},
        }),
      );

      if (yanit.statusCode != 200) {
        throw 'API hatası (${yanit.statusCode}): ${yanit.body}';
      }

      final json = jsonDecode(utf8.decode(yanit.bodyBytes));
      final metin =
          json['candidates']?[0]?['content']?['parts']?[0]?['text']
              ?.toString() ??
          'Yanıt alınamadı.';

      if (mounted) {
        setState(() => _mesajlar.add(_Mesaj(metin.trim(), false)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _mesajlar.add(_Mesaj('Hata: $e', false)));
      }
    } finally {
      if (mounted) setState(() => _bekleniyor = false);
      _asagiKaydir();
    }
  }

  void _asagiKaydir() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_kaydirma.hasClients) {
        _kaydirma.animateTo(
          _kaydirma.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hazir) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_anahtar == null) return _anahtarYok();

    return Column(
      children: [
        Expanded(
          child: _mesajlar.isEmpty
              ? _bosDurum()
              : ListView.builder(
                  controller: _kaydirma,
                  padding: const EdgeInsets.all(16),
                  itemCount: _mesajlar.length + (_bekleniyor ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == _mesajlar.length) return _yazilyor();
                    return _balon(_mesajlar[i]);
                  },
                ),
        ),
        _girisAlani(),
      ],
    );
  }

  Widget _anahtarYok() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.key_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'API anahtarı gerekli',
              style: TextStyle(fontSize: 17, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 6),
            Text(
              'Asistanı kullanmak için Ayarlar > AI API Anahtarı bölümünden\nGemini anahtarınızı girin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _anahtarKontrol,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Yeniden kontrol et'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bosDurum() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        Icon(
          Icons.auto_awesome,
          size: 56,
          color: AppRenk.indigo.withOpacity(0.5),
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'Sözleşme Asistanı',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Bu sözleşme hakkında soru sorun.\nCevaplar madde numaralarıyla birlikte gelir.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Örnek sorular',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 10),
        ..._ornekSorular.map(
          (s) => Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              dense: true,
              leading: const Icon(
                Icons.help_outline,
                size: 19,
                color: AppRenk.indigo,
              ),
              title: Text(s, style: const TextStyle(fontSize: 13.5)),
              onTap: () => _sor(s),
            ),
          ),
        ),
      ],
    );
  }

  Widget _balon(_Mesaj m) {
    return Align(
      alignment: m.benden ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: m.benden ? AppRenk.indigo : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              m.metin,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: m.benden ? Colors.white : Colors.black87,
              ),
            ),
            if (!m.benden)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => Paylas.menu(context, m.metin),
                      child: Row(
                        children: [
                          Icon(
                            Icons.share_outlined,
                            size: 15,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Paylaş',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _yazilyor() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Sözleşme inceleniyor...',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _girisAlani() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      color: AppRenk.arkaPlan,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _soruC,
              enabled: !_bekleniyor,
              onSubmitted: _sor,
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: 'Sözleşmeye dair bir soru sorun...',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _bekleniyor ? null : () => _sor(_soruC.text),
            style: FilledButton.styleFrom(
              backgroundColor: AppRenk.indigo,
              padding: const EdgeInsets.all(16),
            ),
            child: const Icon(Icons.send, size: 20),
          ),
        ],
      ),
    );
  }
}
