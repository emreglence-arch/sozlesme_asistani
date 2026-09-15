import 'package:flutter/material.dart';

/// Hücre renkleri için ortak palet ve seçim penceresi.
/// Hem özel sayfa tabloları hem dönem özet ızgarası bunu kullanır.

/// Eski tablolarda renkler ad olarak saklanıyordu; artık '#RRGGBB' kullanılıyor.
/// Bu eşleme eski kayıtların doğru açılmasını sağlar.
const Map<String, String> eskiRenkler = {
  'yesil': 'D9EAD3',
  'turuncu': 'FCE5CD',
  'sari': 'FFE599',
  'gri': 'DDDDDD',
  'mavi': 'CFE2F3',
  'kirmizi': 'F4CCCC',
};

/// Palet ana renkleri (Excel'in standart renklerine yakın).
const List<String> paletAnaRenkler = [
  'C00000',
  'FF0000',
  'FFC000',
  'FFFF00',
  '92D050',
  '00B050',
  '00B0F0',
  '0070C0',
  '002060',
  '7030A0',
];

/// Gri tonları satırı.
const List<String> paletGriler = [
  '000000',
  '404040',
  '808080',
  'BFBFBF',
  'D9D9D9',
  'F2F2F2',
  'FFFFFF',
];

/// Rengi beyaza doğru açar (0 = aynı renk, 1 = beyaz).
String renkAc(String hex, double oran) {
  final v = int.parse(hex, radix: 16);
  int kanal(int kaydir) {
    final c = (v >> kaydir) & 0xFF;
    return (c + (255 - c) * oran).round().clamp(0, 255);
  }

  return [kanal(16), kanal(8), kanal(0)]
      .map((c) => c.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
}

/// Saklanan renk değerini 'RRGGBB' hex'e çevirir (boşsa null).
String? renkHex(String saklanan) {
  if (saklanan.isEmpty) return null;
  if (saklanan.startsWith('#')) {
    final h = saklanan.substring(1).toUpperCase();
    return RegExp(r'^[0-9A-F]{6}$').hasMatch(h) ? h : null;
  }
  return eskiRenkler[saklanan];
}

/// Saklanan rengi ekrana çizmek için Color'a çevirir.
Color? renkCoz(String saklanan) {
  final h = renkHex(saklanan);
  if (h == null) return null;
  return Color(0xFF000000 | int.parse(h, radix: 16));
}

/// Rengin üzerinde okunur yazı rengi (koyu zeminde beyaz).
Color yaziRengi(Color zemin) {
  final parlaklik =
      (0.299 * (zemin.r * 255) +
          0.587 * (zemin.g * 255) +
          0.114 * (zemin.b * 255)) /
      255;
  return parlaklik > 0.6 ? Colors.black87 : Colors.white;
}

/// Renk seçme penceresi. Seçilen rengi '#RRGGBB' olarak döndürür,
/// "Renksiz" için boş metin, vazgeçilirse null.
Future<String?> renkSecDialog(
  BuildContext context, {
  required String mevcutSaklanan,
  required Color vurguRenk,
}) {
  final mevcut = renkHex(mevcutSaklanan);
  final ozelC = TextEditingController(text: mevcut ?? '');

  return showDialog<String>(
    context: context,
    builder: (dc) => StatefulBuilder(
      builder: (sc, setSt) {
        final ozelGecerli = RegExp(
          r'^[0-9A-Fa-f]{6}$',
        ).hasMatch(ozelC.text.trim());

        Widget kutu(String hex) {
          final secildi = mevcut == hex;
          return InkWell(
            onTap: () => Navigator.pop(dc, '#$hex'),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Color(0xFF000000 | int.parse(hex, radix: 16)),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: secildi ? vurguRenk : Colors.grey.shade400,
                  width: secildi ? 2.5 : 0.8,
                ),
              ),
            ),
          );
        }

        return AlertDialog(
          title: const Text('Arka plan rengi'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gri tonları',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [for (final g in paletGriler) kutu(g)],
                ),
                const SizedBox(height: 14),
                Text(
                  'Renkler (üstten alta açılır)',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                for (final oran in [0.0, 0.4, 0.6, 0.8])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (final t in paletAnaRenkler) kutu(renkAc(t, oran)),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Özel renk  #', style: TextStyle(fontSize: 13)),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: ozelC,
                        maxLength: 6,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          isDense: true,
                          counterText: '',
                          hintText: 'D9EAD3',
                        ),
                        onChanged: (_) => setSt(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 30,
                      height: 24,
                      decoration: BoxDecoration(
                        color: ozelGecerli
                            ? Color(
                                0xFF000000 |
                                    int.parse(ozelC.text.trim(), radix: 16),
                              )
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: ozelGecerli
                          ? () => Navigator.pop(
                              dc,
                              '#${ozelC.text.trim().toUpperCase()}',
                            )
                          : null,
                      child: const Text('Uygula'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dc, ''),
              child: const Text('Renksiz'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dc),
              child: const Text('Vazgeç'),
            ),
          ],
        );
      },
    ),
  );
}
