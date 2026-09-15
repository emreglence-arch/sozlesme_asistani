import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Gerçek bir .xlsx dosyası üretir.
///
/// .xlsx aslında içinde XML dosyaları olan bir ZIP arşividir; projede zaten
/// bulunan `archive` paketiyle bunu kendimiz yazıyoruz (ek paket gerekmez).
/// Korunanlar: değerler, kalın yazı, arka plan rengi, hizalama,
/// birleştirilmiş hücreler, sütun genişlikleri, satır yükseklikleri, kenarlık.

class XlsxHucre {
  final String deger;
  final bool kalin;
  final bool italik;

  /// 'RRGGBB' biçiminde renk; null ise dolgu yok.
  final String? arkaPlan;

  /// 'sol' | 'orta' | 'sag'
  final String hizalama;

  final int satirKapla;
  final int sutunKapla;

  const XlsxHucre({
    required this.deger,
    this.kalin = false,
    this.italik = false,
    this.arkaPlan,
    this.hizalama = 'sol',
    this.satirKapla = 1,
    this.sutunKapla = 1,
  });
}

/// Sütun harfi: 1 -> A, 27 -> AA
String sutunHarfi(int sutun) {
  var n = sutun;
  var s = '';
  while (n > 0) {
    final kalan = (n - 1) % 26;
    s = String.fromCharCode(65 + kalan) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

String _kacis(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;')
    // XML'de geçersiz kontrol karakterlerini at
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

/// Türkçe biçimli sayıyı tanır: 11.866,40 / 2026 / -5,5
/// Tarih (01.06.2026) ve yüzde (%20) gibi değerler metin kalır.
final RegExp _sayiKalibi = RegExp(
  r'^-?\d{1,3}(\.\d{3})+(,\d+)?$|^-?\d+(,\d+)?$',
);

double? _sayiCevir(String s) {
  final t = s.trim();
  if (t.isEmpty || !_sayiKalibi.hasMatch(t)) return null;
  return double.tryParse(t.replaceAll('.', '').replaceAll(',', '.'));
}

/// Excel sayfa adı kısıtları: en fazla 31 karakter, bazı işaretler yasak.
String _sayfaAdiTemizle(String ad) {
  var s = ad.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
  if (s.isEmpty) s = 'Tablo';
  return s.length > 31 ? s.substring(0, 31) : s;
}

/// Biçim anahtarı: aynı görünüme sahip hücreler tek stili paylaşır.
String _stilAnahtar(bool kalin, bool italik, String? renk, String hizalama) =>
    '${kalin ? 1 : 0}|${italik ? 1 : 0}|${renk ?? ''}|$hizalama';

Uint8List xlsxUret({
  required String sayfaAdi,
  required List<double> sutunGenislikleri,
  required List<double> satirYukseklikleri,
  required List<List<XlsxHucre?>> satirlar,
}) {
  // ---- Stilleri topla ----
  final stilIndeks = <String, int>{};
  final stiller = <List<String>>[]; // [kalin, renk, hizalama]
  int stilAl(bool kalin, bool italik, String? renk, String hizalama) {
    final k = _stilAnahtar(kalin, italik, renk, hizalama);
    final mevcut = stilIndeks[k];
    if (mevcut != null) return mevcut;
    stiller.add([kalin ? '1' : '0', italik ? '1' : '0', renk ?? '', hizalama]);
    final i = stiller.length; // 0. stil varsayılan, bizimkiler 1'den başlar
    stilIndeks[k] = i;
    return i;
  }

  for (final satir in satirlar) {
    for (final h in satir) {
      if (h == null) continue;
      stilAl(h.kalin, h.italik, h.arkaPlan, h.hizalama);
    }
  }

  // Dolgu renkleri (0 ve 1 numaralı dolgular Excel tarafından ayrılmıştır)
  final renkler = <String>[];
  for (final s in stiller) {
    if (s[2].isNotEmpty && !renkler.contains(s[2])) renkler.add(s[2]);
  }

  // ---- styles.xml ----
  final fills = StringBuffer()
    ..write('<fill><patternFill patternType="none"/></fill>')
    ..write('<fill><patternFill patternType="gray125"/></fill>');
  for (final r in renkler) {
    fills.write(
      '<fill><patternFill patternType="solid">'
      '<fgColor rgb="FF$r"/><bgColor indexed="64"/>'
      '</patternFill></fill>',
    );
  }

  final xfs = StringBuffer()
    ..write(
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>',
    );
  for (final s in stiller) {
    final fontId = (s[0] == '1' ? 1 : 0) + (s[1] == '1' ? 2 : 0);
    final fillId = s[2].isEmpty ? 0 : 2 + renkler.indexOf(s[2]);
    final hiza = switch (s[3]) {
      'orta' => 'center',
      'sag' => 'right',
      _ => 'left',
    };
    xfs.write(
      '<xf numFmtId="0" fontId="$fontId" fillId="$fillId" borderId="1" xfId="0" '
      'applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
      '<alignment horizontal="$hiza" vertical="center" wrapText="1"/>'
      '</xf>',
    );
  }

  final stylesXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="4">'
      '<font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font>'
      '<font><i/><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><i/><sz val="11"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="${2 + renkler.length}">$fills</fills>'
      '<borders count="2">'
      '<border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border>'
      '<left style="thin"><color rgb="FF9E9E9E"/></left>'
      '<right style="thin"><color rgb="FF9E9E9E"/></right>'
      '<top style="thin"><color rgb="FF9E9E9E"/></top>'
      '<bottom style="thin"><color rgb="FF9E9E9E"/></bottom>'
      '<diagonal/></border>'
      '</borders>'
      '<cellStyleXfs count="1">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>'
      '</cellStyleXfs>'
      '<cellXfs count="${stiller.length + 1}">$xfs</cellXfs>'
      '<cellStyles count="1">'
      '<cellStyle name="Normal" xfId="0" builtinId="0"/>'
      '</cellStyles>'
      '</styleSheet>';

  // ---- sheet1.xml ----
  final cols = StringBuffer();
  for (var i = 0; i < sutunGenislikleri.length; i++) {
    // Piksel -> Excel sütun genişliği (yaklaşık karakter sayısı)
    final w = ((sutunGenislikleri[i] - 5) / 7).clamp(2.0, 255.0);
    cols.write(
      '<col min="${i + 1}" max="${i + 1}" width="${w.toStringAsFixed(2)}" customWidth="1"/>',
    );
  }

  final sheetData = StringBuffer();
  final birlesmeler = <String>[];

  for (var r = 0; r < satirlar.length; r++) {
    final yukseklikPt = (r < satirYukseklikleri.length)
        ? (satirYukseklikleri[r] * 0.75).clamp(12.0, 409.0)
        : 15.0;
    sheetData.write(
      '<row r="${r + 1}" ht="${yukseklikPt.toStringAsFixed(2)}" customHeight="1">',
    );
    for (var c = 0; c < satirlar[r].length; c++) {
      final h = satirlar[r][c];
      if (h == null) continue; // birleştirmeyle kapanan göz
      final ref = '${sutunHarfi(c + 1)}${r + 1}';
      final s = stilAl(h.kalin, h.italik, h.arkaPlan, h.hizalama);

      if (h.satirKapla > 1 || h.sutunKapla > 1) {
        final sonRef =
            '${sutunHarfi(c + h.sutunKapla)}${r + h.satirKapla}';
        birlesmeler.add('$ref:$sonRef');
      }

      final sayi = _sayiCevir(h.deger);
      if (sayi != null) {
        final metin = sayi == sayi.roundToDouble()
            ? sayi.toStringAsFixed(0)
            : sayi.toString();
        sheetData.write('<c r="$ref" s="$s"><v>$metin</v></c>');
      } else if (h.deger.isEmpty) {
        sheetData.write('<c r="$ref" s="$s"/>');
      } else {
        sheetData.write(
          '<c r="$ref" s="$s" t="inlineStr"><is>'
          '<t xml:space="preserve">${_kacis(h.deger)}</t>'
          '</is></c>',
        );
      }
    }
    sheetData.write('</row>');
  }

  final birlesmeXml = birlesmeler.isEmpty
      ? ''
      : '<mergeCells count="${birlesmeler.length}">'
            '${birlesmeler.map((b) => '<mergeCell ref="$b"/>').join()}'
            '</mergeCells>';

  final sheetXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '${cols.isEmpty ? '' : '<cols>$cols</cols>'}'
      '<sheetData>$sheetData</sheetData>'
      '$birlesmeXml'
      '</worksheet>';

  // ---- workbook.xml ----
  final workbookXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets>'
      '<sheet name="${_kacis(_sayfaAdiTemizle(sayfaAdi))}" sheetId="1" r:id="rId1"/>'
      '</sheets>'
      '</workbook>';

  const workbookRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
      'Target="styles.xml"/>'
      '</Relationships>';

  const kokRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="xl/workbook.xml"/>'
      '</Relationships>';

  const contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" '
      'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';

  // ---- ZIP ----
  final arsiv = Archive()
    ..addFile(ArchiveFile.string('[Content_Types].xml', contentTypes))
    ..addFile(ArchiveFile.string('_rels/.rels', kokRels))
    ..addFile(ArchiveFile.string('xl/workbook.xml', workbookXml))
    ..addFile(ArchiveFile.string('xl/_rels/workbook.xml.rels', workbookRels))
    ..addFile(ArchiveFile.string('xl/styles.xml', stylesXml))
    ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', sheetXml));

  return ZipEncoder().encodeBytes(arsiv);
}
