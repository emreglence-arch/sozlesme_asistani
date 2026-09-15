import 'package:flutter/material.dart';

/// Birleştirilebilir hücreleri olan ızgara çizici.
///
/// Hücreler hesaplanmış konumlara yerleştirilir; böylece dikey/yatay
/// birleştirme mümkün olur. Satır yükseklikleri metne göre ölçülür.
/// (DataTable Windows'ta çöktüğü için kullanılmıyor.)

class IzgaraHucre {
  final String metin;
  final bool kalin;
  final bool italik;
  final bool ustuCizili;
  final Color? zemin;
  final Color? yazi;
  final TextAlign hiza;
  final double yaziBoyutu;

  /// Kaç satır / sütun kaplıyor (1 = birleştirme yok).
  final int satirKapla;
  final int sutunKapla;

  final VoidCallback? onTap;
  final void Function(Offset globalKonum)? onMenu;

  /// Doluysa metin yerine bu çizilir (düzenleme alanı, rozetli içerik vb.).
  final Widget? icerik;

  /// Düzenlenen hücrenin çerçevesi vurgulanır.
  final bool vurgulu;

  /// İçerik widget'ı için en az yükseklik.
  final double enAzYukseklik;

  final String? ipucu;

  const IzgaraHucre({
    this.metin = '',
    this.kalin = false,
    this.italik = false,
    this.ustuCizili = false,
    this.zemin,
    this.yazi,
    this.hiza = TextAlign.left,
    this.yaziBoyutu = 13,
    this.satirKapla = 1,
    this.sutunKapla = 1,
    this.onTap,
    this.onMenu,
    this.icerik,
    this.vurgulu = false,
    this.enAzYukseklik = 0,
    this.ipucu,
  });

  TextStyle get stil => TextStyle(
    fontSize: yaziBoyutu,
    height: 1.3,
    fontWeight: kalin ? FontWeight.w700 : FontWeight.normal,
    fontStyle: italik ? FontStyle.italic : FontStyle.normal,
    decoration: ustuCizili ? TextDecoration.lineThrough : null,
    color: yazi ?? Colors.black87,
  );
}

class IzgaraTablo extends StatefulWidget {
  final List<double> sutunGenislikleri;

  /// Satırlar; null hücre = birleştirmeyle kapanan göz.
  final List<List<IzgaraHucre?>> satirlar;

  final Color vurguRenk;
  final double enAzSatirYuksekligi;

  /// Doluysa sütun kenarları fareyle çekilebilir.
  final void Function(int sutun, double yeniGenislik)? onGenislikDegisti;

  const IzgaraTablo({
    super.key,
    required this.sutunGenislikleri,
    required this.satirlar,
    required this.vurguRenk,
    this.enAzSatirYuksekligi = 38,
    this.onGenislikDegisti,
  });

  @override
  State<IzgaraTablo> createState() => _IzgaraTabloState();
}

class _IzgaraTabloState extends State<IzgaraTablo> {
  static const double yatayBosluk = 8;
  static const double dikeyBosluk = 7;
  static const double _cizgi = 0.8;

  int? _surukleSutun;
  double _surukleGenislik = 0;

  double _genislik(int i) =>
      _surukleSutun == i ? _surukleGenislik : widget.sutunGenislikleri[i];

  double _metinYukseklik(String metin, double genislik, TextStyle stil) {
    final tp = TextPainter(
      text: TextSpan(text: metin.isEmpty ? ' ' : metin, style: stil),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: (genislik - yatayBosluk * 2).clamp(10.0, 4000.0));
    return tp.height + dikeyBosluk * 2;
  }

  double _blokGenislik(int c, int yk) {
    var t = 0.0;
    for (var i = c; i < c + yk && i < widget.sutunGenislikleri.length; i++) {
      t += _genislik(i);
    }
    return t;
  }

  /// Birleştirme yüzünden çizilmeyecek gözleri işaretler.
  List<List<bool>> _kapaliGozler() {
    final n = widget.sutunGenislikleri.length;
    final satirlar = widget.satirlar;
    final kapali = List.generate(satirlar.length, (_) => List.filled(n, false));
    for (var r = 0; r < satirlar.length; r++) {
      for (var c = 0; c < n; c++) {
        if (kapali[r][c]) continue;
        final h = (c < satirlar[r].length) ? satirlar[r][c] : null;
        if (h == null) continue;
        final sk = h.satirKapla.clamp(1, satirlar.length - r);
        final yk = h.sutunKapla.clamp(1, n - c);
        for (var i = r; i < r + sk; i++) {
          for (var j = c; j < c + yk; j++) {
            if (i == r && j == c) continue;
            kapali[i][j] = true;
          }
        }
      }
    }
    return kapali;
  }

  List<double> _satirYukseklikleri(List<List<bool>> kapali) {
    final satirlar = widget.satirlar;
    final n = widget.sutunGenislikleri.length;
    final yuk = List<double>.filled(
      satirlar.length,
      widget.enAzSatirYuksekligi,
    );

    double hucreYuk(IzgaraHucre h, int c) {
      final g = _blokGenislik(c, h.sutunKapla.clamp(1, n - c));
      final y = _metinYukseklik(h.metin, g, h.stil);
      return y > h.enAzYukseklik ? y : h.enAzYukseklik;
    }

    for (var r = 0; r < satirlar.length; r++) {
      for (var c = 0; c < n && c < satirlar[r].length; c++) {
        if (kapali[r][c]) continue;
        final h = satirlar[r][c];
        if (h == null || h.satirKapla != 1) continue;
        final y = hucreYuk(h, c);
        if (y > yuk[r]) yuk[r] = y;
      }
    }
    // Birleştirilmiş hücreler sığmıyorsa son satırı büyüt
    for (var r = 0; r < satirlar.length; r++) {
      for (var c = 0; c < n && c < satirlar[r].length; c++) {
        if (kapali[r][c]) continue;
        final h = satirlar[r][c];
        if (h == null || h.satirKapla <= 1) continue;
        final y = hucreYuk(h, c);
        final sk = h.satirKapla.clamp(1, satirlar.length - r);
        var toplam = 0.0;
        for (var i = r; i < r + sk; i++) {
          toplam += yuk[i];
        }
        if (y > toplam) {
          final son = (r + sk - 1).clamp(0, yuk.length - 1);
          yuk[son] += y - toplam;
        }
      }
    }
    return yuk;
  }

  Alignment _hizaKonum(TextAlign h) => switch (h) {
    TextAlign.center => Alignment.center,
    TextAlign.right => Alignment.centerRight,
    _ => Alignment.centerLeft,
  };

  Widget _hucreCiz(IzgaraHucre h, double g, double y) {
    Widget govde = Container(
      width: g,
      height: y,
      padding: const EdgeInsets.symmetric(
        horizontal: yatayBosluk,
        vertical: dikeyBosluk,
      ),
      decoration: BoxDecoration(
        color: h.zemin ?? Colors.white,
        border: Border.all(
          color: h.vurgulu ? widget.vurguRenk : Colors.grey.shade300,
          width: h.vurgulu ? 1.6 : _cizgi,
        ),
      ),
      alignment: _hizaKonum(h.hiza),
      child: h.icerik ?? Text(h.metin, style: h.stil, textAlign: h.hiza),
    );

    if (h.ipucu != null && h.ipucu!.isNotEmpty) {
      govde = Tooltip(message: h.ipucu!, child: govde);
    }

    if (h.onTap == null && h.onMenu == null) return govde;

    return GestureDetector(
      onTap: h.onTap,
      onSecondaryTapDown: h.onMenu == null
          ? null
          : (d) => h.onMenu!(d.globalPosition),
      onLongPressStart: h.onMenu == null
          ? null
          : (d) => h.onMenu!(d.globalPosition),
      child: govde,
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.sutunGenislikleri.length;
    if (n == 0 || widget.satirlar.isEmpty) return const SizedBox.shrink();

    final genislikler = List.generate(n, (i) => _genislik(i));
    final toplamGenislik = genislikler.fold<double>(0, (a, b) => a + b);

    final x = List<double>.filled(n + 1, 0);
    for (var i = 0; i < n; i++) {
      x[i + 1] = x[i] + genislikler[i];
    }

    final kapali = _kapaliGozler();
    final yukseklikler = _satirYukseklikleri(kapali);

    final y = List<double>.filled(widget.satirlar.length + 1, 0);
    for (var i = 0; i < widget.satirlar.length; i++) {
      y[i + 1] = y[i] + yukseklikler[i];
    }
    final toplamYukseklik = y[widget.satirlar.length];

    return SizedBox(
      width: toplamGenislik,
      height: toplamYukseklik,
      child: Stack(
        children: [
          for (var r = 0; r < widget.satirlar.length; r++)
            for (var c = 0; c < n && c < widget.satirlar[r].length; c++)
              if (!kapali[r][c] && widget.satirlar[r][c] != null)
                Positioned(
                  left: x[c],
                  top: y[r],
                  child: _hucreCiz(
                    widget.satirlar[r][c]!,
                    _blokGenislik(
                      c,
                      widget.satirlar[r][c]!.sutunKapla.clamp(1, n - c),
                    ),
                    y[(r + widget.satirlar[r][c]!.satirKapla).clamp(
                          0,
                          widget.satirlar.length,
                        )] -
                        y[r],
                  ),
                ),
          // Sütun genişliği tutamakları
          if (widget.onGenislikDegisti != null)
            for (var c = 0; c < n; c++)
              Positioned(
                left: x[c + 1] - 5,
                top: 0,
                width: 10,
                height: toplamYukseklik,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (_) => setState(() {
                      _surukleSutun = c;
                      _surukleGenislik = widget.sutunGenislikleri[c];
                    }),
                    onHorizontalDragUpdate: (d) => setState(() {
                      _surukleGenislik = (_surukleGenislik + d.delta.dx).clamp(
                        60.0,
                        900.0,
                      );
                    }),
                    onHorizontalDragEnd: (_) {
                      final g = _surukleGenislik;
                      setState(() => _surukleSutun = null);
                      widget.onGenislikDegisti!(c, g);
                    },
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
