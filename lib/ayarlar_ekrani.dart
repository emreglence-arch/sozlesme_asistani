import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'ayarlar_servisi.dart';
import 'ozel_sayfalar_servisi.dart';
import 'asistan_ayarlari_servisi.dart';
import 'kullanici_servisi.dart';

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

  // ---------- ASİSTAN ÖRNEK SORULARI ----------
  Future<void> _soruDialog(List<String> mevcut, {int? index}) async {
    final duzenle = index != null;
    final c = TextEditingController(text: duzenle ? mevcut[index] : '');
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(duzenle ? 'Soruyu Düzenle' : 'Örnek Soru Ekle'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: c,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Soru',
              hintText: 'Örn. Yakacak yardımı ne kadar?',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dc, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (kaydet != true || c.text.trim().isEmpty) return;
    final yeni = List<String>.from(mevcut);
    if (duzenle) {
      yeni[index] = c.text.trim();
    } else {
      yeni.add(c.text.trim());
    }
    await AsistanAyarlariServisi.tisSorulariKaydet(yeni);
  }

  Future<void> _soruSil(List<String> mevcut, int index) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Soruyu sil'),
        content: Text('"${mevcut[index]}" silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dc, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (onay != true) return;
    final yeni = List<String>.from(mevcut)..removeAt(index);
    await AsistanAyarlariServisi.tisSorulariKaydet(yeni);
  }

  Future<void> _soruTasi(List<String> mevcut, int index, int yon) async {
    final hedef = index + yon;
    if (hedef < 0 || hedef >= mevcut.length) return;
    final yeni = List<String>.from(mevcut);
    final t = yeni[index];
    yeni[index] = yeni[hedef];
    yeni[hedef] = t;
    await AsistanAyarlariServisi.tisSorulariKaydet(yeni);
  }

  // ---------- KULLANICI ONAYI ----------
  Future<void> _kullaniciOnayla(String uid, String eposta) async {
    await KullaniciServisi.onayla(uid);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$eposta onaylandı')));
    }
  }

  Future<void> _kullaniciReddet(String uid, String eposta) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Reddet'),
        content: Text(
          '"$eposta" kayıt talebi silinsin mi? (Kişi tekrar kayıt olabilir)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dc, true),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
    if (onay != true) return;
    await KullaniciServisi.reddet(uid);
  }

  Future<void> _erisimiKaldir(String uid, String eposta) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Erişimi kaldır'),
        content: Text(
          '"$eposta" kullanıcısının erişimi kaldırılsın mı? Tekrar onay bekler.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dc, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (onay != true) return;
    await KullaniciServisi.onayiKaldir(uid);
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

          // ---- Hesap ----
          const Text(
            'Hesap',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.account_circle_outlined,
                color: AppRenk.indigo,
              ),
              title: Text(
                FirebaseAuth.instance.currentUser?.email ?? 'Giriş yapıldı',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Oturum açık',
                style: TextStyle(fontSize: 12.5),
              ),
              trailing: TextButton.icon(
                onPressed: () async {
                  final onay = await showDialog<bool>(
                    context: context,
                    builder: (dc) => AlertDialog(
                      title: const Text('Çıkış yap'),
                      content: const Text(
                        'Oturumu kapatmak istediğinize emin misiniz?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dc, false),
                          child: const Text('Vazgeç'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dc, true),
                          child: const Text('Çıkış Yap'),
                        ),
                      ],
                    ),
                  );
                  if (onay == true) {
                    await FirebaseAuth.instance.signOut();
                  }
                },
                icon: const Icon(Icons.logout, size: 18, color: Colors.red),
                label: const Text('Çıkış', style: TextStyle(color: Colors.red)),
              ),
            ),
          ),

          // ---- Kullanıcı Yönetimi (sadece yönetici) ----
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: KullaniciServisi.benimKaydim(
              FirebaseAuth.instance.currentUser?.uid ?? '_',
            ),
            builder: (context, benSnap) {
              final yonetici = benSnap.data?.data()?['yonetici'] == true;
              if (!yonetici) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kullanıcı Yönetimi',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),

                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: KullaniciServisi.bekleyenler(),
                    builder: (context, snap) {
                      final bekleyen = snap.data?.docs ?? [];
                      if (bekleyen.isEmpty) return const SizedBox.shrink();
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_add_alt_1,
                                    size: 19,
                                    color: AppRenk.amber,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Onay Bekleyenler (${bekleyen.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ...bekleyen.map((d) {
                                final eposta = (d.data()['eposta'] ?? '')
                                    .toString();
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          eposta,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () =>
                                            _kullaniciOnayla(d.id, eposta),
                                        icon: const Icon(
                                          Icons.check,
                                          size: 17,
                                          color: AppRenk.emerald,
                                        ),
                                        label: const Text(
                                          'Onayla',
                                          style: TextStyle(
                                            color: AppRenk.emerald,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Reddet',
                                        icon: const Icon(
                                          Icons.close,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _kullaniciReddet(d.id, eposta),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: KullaniciServisi.onaylilar(),
                    builder: (context, snap) {
                      final onayli = snap.data?.docs ?? [];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.group_outlined,
                                    size: 19,
                                    color: AppRenk.indigo,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Onaylı Kullanıcılar (${onayli.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (onayli.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    'Henüz yok',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                )
                              else
                                ...onayli.map((d) {
                                  final eposta = (d.data()['eposta'] ?? '')
                                      .toString();
                                  final yon = d.data()['yonetici'] == true;
                                  final benMiyim =
                                      d.id ==
                                      FirebaseAuth.instance.currentUser?.uid;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  eposta,
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (yon) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppRenk.indigo
                                                        .withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'yönetici',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppRenk.indigo,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (!benMiyim && !yon)
                                          TextButton(
                                            onPressed: () =>
                                                _erisimiKaldir(d.id, eposta),
                                            child: const Text(
                                              'Erişimi kaldır',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 12,
                                              ),
                                            ),
                                          )
                                        else if (benMiyim)
                                          Text(
                                            '(siz)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),

          // ---- Asistan Ayarları ----
          const Text(
            'Asistan Ayarları',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),

          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
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

          StreamBuilder<List<String>>(
            stream: AsistanAyarlariServisi.tisSorulariAkis(),
            builder: (context, snap) {
              final sorular = snap.data ?? [];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.help_outline,
                            size: 20,
                            color: AppRenk.indigo,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'TİS Asistanı Örnek Soruları',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _soruDialog(sorular),
                            icon: const Icon(Icons.add, size: 17),
                            label: const Text(
                              'Ekle',
                              style: TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 4),
                        child: Text(
                          'Bu sorular tüm sözleşme asistanlarında öneri olarak görünür.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (sorular.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'Henüz örnek soru yok',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        )
                      else
                        ...List.generate(sorular.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    sorular[i],
                                    style: const TextStyle(fontSize: 13.5),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Yukarı',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 30,
                                    minHeight: 30,
                                  ),
                                  icon: Icon(
                                    Icons.keyboard_arrow_up,
                                    size: 19,
                                    color: i == 0
                                        ? Colors.grey.shade300
                                        : Colors.grey,
                                  ),
                                  onPressed: i == 0
                                      ? null
                                      : () => _soruTasi(sorular, i, -1),
                                ),
                                IconButton(
                                  tooltip: 'Aşağı',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 30,
                                    minHeight: 30,
                                  ),
                                  icon: Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 19,
                                    color: i == sorular.length - 1
                                        ? Colors.grey.shade300
                                        : Colors.grey,
                                  ),
                                  onPressed: i == sorular.length - 1
                                      ? null
                                      : () => _soruTasi(sorular, i, 1),
                                ),
                                IconButton(
                                  tooltip: 'Düzenle',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 30,
                                    minHeight: 30,
                                  ),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 17,
                                    color: AppRenk.indigo,
                                  ),
                                  onPressed: () =>
                                      _soruDialog(sorular, index: i),
                                ),
                                IconButton(
                                  tooltip: 'Sil',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 30,
                                    minHeight: 30,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 17,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _soruSil(sorular, i),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              );
            },
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
                    ...List.generate(sayfalar.length, (i) {
                      final s = sayfalar[i];
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Yukarı',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: Icon(
                                  Icons.keyboard_arrow_up,
                                  size: 20,
                                  color: i == 0
                                      ? Colors.grey.shade300
                                      : Colors.grey,
                                ),
                                onPressed: i == 0
                                    ? null
                                    : () => OzelSayfalarServisi.yerDegistir(
                                        sayfalar[i],
                                        sayfalar[i - 1],
                                        i,
                                        i - 1,
                                      ),
                              ),
                              IconButton(
                                tooltip: 'Aşağı',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 20,
                                  color: i == sayfalar.length - 1
                                      ? Colors.grey.shade300
                                      : Colors.grey,
                                ),
                                onPressed: i == sayfalar.length - 1
                                    ? null
                                    : () => OzelSayfalarServisi.yerDegistir(
                                        sayfalar[i],
                                        sayfalar[i + 1],
                                        i,
                                        i + 1,
                                      ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (x) {
                                  if (x == 'duzenle') _sayfaDialog(mevcut: s);
                                  if (x == 'sil') _sayfaSil(s.id, ad);
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'duzenle',
                                    child: Text('Düzenle'),
                                  ),
                                  PopupMenuItem(
                                    value: 'sil',
                                    child: Text('Sil'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
