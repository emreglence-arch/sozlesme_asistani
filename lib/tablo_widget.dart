import 'package:flutter/material.dart';

class TabloWidget extends StatelessWidget {
  final Map<String, dynamic> tablo;
  final Color renk;
  final Future<void> Function(Map<String, dynamic> yeniTablo) onDegisti;
  final VoidCallback? onBaslikDuzenle;
  final VoidCallback? onTabloSil;

  const TabloWidget({
    super.key,
    required this.tablo,
    required this.renk,
    required this.onDegisti,
    this.onBaslikDuzenle,
    this.onTabloSil,
  });

  static const double _hucreGenislik = 130;

  List<Map<String, dynamic>> get _sutunlar {
    final raw = tablo['sutunlar'];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Satırlar Firestore'da {'h': [...]} olarak saklanır (iç içe dizi yasak).
  List<List<String>> get _satirlar {
    final n = _sutunlar.length;
    final raw = tablo['satirlar'];
    if (raw is! List) return [];
    return raw.map<List<String>>((r) {
      List<String> liste;
      if (r is Map && r['h'] is List) {
        liste = (r['h'] as List).map((c) => c.toString()).toList();
      } else if (r is List) {
        liste = r.map((c) => c.toString()).toList();
      } else {
        liste = <String>[];
      }
      while (liste.length < n) {
        liste.add('');
      }
      return liste.length > n ? liste.sublist(0, n) : liste;
    }).toList();
  }

  /// Yazmaya hazır kopya
  Map<String, dynamic> _kopya() => {
    'baslik': (tablo['baslik'] ?? 'Tablo').toString(),
    'sutunlar': _sutunlar.map((s) => Map<String, dynamic>.from(s)).toList(),
    'satirlar': _satirlar.map((r) => {'h': List<String>.from(r)}).toList(),
  };

  String _tip(int i) => (_sutunlar[i]['tip'] ?? 'metin').toString();
  String _ad(int i) => (_sutunlar[i]['ad'] ?? '').toString();

  String _tarihMetni(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';

  // ---------- SÜTUN ----------
  Future<void> _sutunDialog(BuildContext context, {int? index}) async {
    final duzenle = index != null;
    final adC = TextEditingController(text: duzenle ? _ad(index) : '');
    String tip = duzenle ? _tip(index) : 'metin';

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          title: Text(duzenle ? 'Sütunu Düzenle' : 'Sütun Ekle'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: adC,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Sütun adı',
                    hintText: 'Örn. TÜFE Aylık',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sütun tipi',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in ['metin', 'sayi', 'tarih'])
                      ChoiceChip(
                        label: Text(
                          t == 'metin'
                              ? 'Metin'
                              : (t == 'sayi' ? 'Sayı' : 'Tarih'),
                        ),
                        selected: tip == t,
                        showCheckmark: false,
                        selectedColor: renk,
                        labelStyle: TextStyle(
                          color: tip == t ? Colors.white : Colors.black87,
                        ),
                        onSelected: (_) => setSt(() => tip = t),
                      ),
                  ],
                ),
              ],
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
      ),
    );

    if (kaydet != true || adC.text.trim().isEmpty) return;

    final yeni = _kopya();
    final sutunlar = yeni['sutunlar'] as List;
    final satirlar = yeni['satirlar'] as List;

    if (duzenle) {
      sutunlar[index] = {'ad': adC.text.trim(), 'tip': tip};
    } else {
      sutunlar.add({'ad': adC.text.trim(), 'tip': tip});
      for (var i = 0; i < satirlar.length; i++) {
        ((satirlar[i] as Map)['h'] as List).add('');
      }
    }
    await onDegisti(yeni);
  }

  Future<void> _sutunSil(BuildContext context, int index) async {
    final onay = await _onay(
      context,
      'Sütunu sil',
      '"${_ad(index)}" sütunu ve verileri silinsin mi?',
    );
    if (onay != true) return;
    final yeni = _kopya();
    (yeni['sutunlar'] as List).removeAt(index);
    for (final r in (yeni['satirlar'] as List)) {
      final h = (r as Map)['h'] as List;
      if (h.length > index) h.removeAt(index);
    }
    await onDegisti(yeni);
  }

  // ---------- SATIR ----------
  Future<void> _satirDialog(BuildContext context, {int? index}) async {
    final sutunlar = _sutunlar;
    if (sutunlar.isEmpty) return;
    final satirlar = _satirlar;
    final duzenle = index != null && index < satirlar.length;

    final controllers = List<TextEditingController>.generate(
      sutunlar.length,
      (i) => TextEditingController(text: duzenle ? satirlar[index][i] : ''),
    );

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(duzenle ? 'Satırı Düzenle' : 'Satır Ekle'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(sutunlar.length, (i) {
                final tip = _tip(i);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controllers[i],
                          keyboardType: tip == 'sayi'
                              ? const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                )
                              : TextInputType.text,
                          decoration: InputDecoration(
                            labelText: _ad(i),
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      if (tip == 'tarih') ...[
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Tarih seç',
                          icon: const Icon(Icons.event),
                          onPressed: () async {
                            final s = await showDatePicker(
                              context: dc,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(1950),
                              lastDate: DateTime(2100),
                            );
                            if (s != null) {
                              controllers[i].text = _tarihMetni(s);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                );
              }),
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

    if (kaydet != true) return;
    final degerler = controllers.map((c) => c.text.trim()).toList();
    if (degerler.every((d) => d.isEmpty)) return;

    final yeni = _kopya();
    final yeniSatirlar = yeni['satirlar'] as List;
    if (duzenle) {
      yeniSatirlar[index] = {'h': degerler};
    } else {
      yeniSatirlar.add({'h': degerler});
    }
    await onDegisti(yeni);
  }

  Future<void> _satirSil(BuildContext context, int index) async {
    final onay = await _onay(context, 'Satırı sil', 'Bu satır silinsin mi?');
    if (onay != true) return;
    final yeni = _kopya();
    (yeni['satirlar'] as List).removeAt(index);
    await onDegisti(yeni);
  }

  Future<bool?> _onay(BuildContext context, String baslik, String metin) =>
      showDialog<bool>(
        context: context,
        builder: (dc) => AlertDialog(
          title: Text(baslik),
          content: Text(metin),
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

  // ---------- EKRAN ----------
  @override
  Widget build(BuildContext context) {
    final sutunlar = _sutunlar;
    final satirlar = _satirlar;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart_outlined, size: 19, color: renk),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (tablo['baslik'] ?? 'Tablo').toString(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _sutunDialog(context),
                  icon: const Icon(Icons.view_column_outlined, size: 17),
                  label: const Text('Sütun', style: TextStyle(fontSize: 12.5)),
                ),
                if (sutunlar.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _satirDialog(context),
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text(
                      'Satır',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 19,
                    color: Colors.grey,
                  ),
                  onSelected: (x) {
                    if (x == 'baslik') onBaslikDuzenle?.call();
                    if (x == 'sil') onTabloSil?.call();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'baslik',
                      child: Text('Başlığı düzenle'),
                    ),
                    PopupMenuItem(value: 'sil', child: Text('Tabloyu sil')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (sutunlar.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Önce "Sütun" ile sütunları tanımlayın',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ),
              )
            else ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık satırı
                    Container(
                      decoration: BoxDecoration(
                        color: renk.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          for (var i = 0; i < sutunlar.length; i++)
                            InkWell(
                              onTap: () => _sutunDialog(context, index: i),
                              onLongPress: () => _sutunSil(context, i),
                              child: Container(
                                width: _hucreGenislik,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _ad(i),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                          color: renk,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.edit,
                                      size: 11,
                                      color: Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(width: 44),
                        ],
                      ),
                    ),
                    // Veri satırları
                    for (var r = 0; r < satirlar.length; r++)
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            for (var c = 0; c < sutunlar.length; c++)
                              InkWell(
                                onTap: () => _satirDialog(context, index: r),
                                child: Container(
                                  width: _hucreGenislik,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 13,
                                  ),
                                  child: Text(
                                    satirlar[r][c].isEmpty
                                        ? '—'
                                        : satirlar[r][c],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: satirlar[r][c].isEmpty
                                          ? Colors.grey.shade400
                                          : Colors.black87,
                                      fontWeight: _tip(c) == 'sayi'
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: 44,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 17,
                                  color: Colors.red,
                                ),
                                onPressed: () => _satirSil(context, r),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (satirlar.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Center(
                    child: Text(
                      'Henüz satır yok — "Satır" ile ekleyin',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 2),
                child: Text(
                  'Sütun başlığına dokun: düzenle • uzun bas: sil  |  Hücreye dokun: satırı düzenle',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
