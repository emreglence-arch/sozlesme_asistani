import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';

class PdfGoruntuleyici extends StatefulWidget {
  final String url;
  final String baslik;

  const PdfGoruntuleyici({super.key, required this.url, required this.baslik});

  @override
  State<PdfGoruntuleyici> createState() => _PdfGoruntuleyiciState();
}

class _PdfGoruntuleyiciState extends State<PdfGoruntuleyici> {
  final _kontrol = PdfViewerController();
  int _toplamSayfa = 0;
  bool _hazir = false;

  Future<void> _disaridaAc() async {
    await launchUrl(
      Uri.parse(widget.url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppRenk.indigo,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.baslik,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_hazir && _toplamSayfa > 0)
              Text(
                'Sayfa ${_kontrol.pageNumber} / $_toplamSayfa',
                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Uzaklaştır',
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _kontrol.zoomLevel = (_kontrol.zoomLevel - 0.25)
                .clamp(1.0, 3.0),
          ),
          IconButton(
            tooltip: 'Yakınlaştır',
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _kontrol.zoomLevel = (_kontrol.zoomLevel + 0.25)
                .clamp(1.0, 3.0),
          ),
          IconButton(
            tooltip: 'Dışarıda aç',
            icon: const Icon(Icons.open_in_new),
            onPressed: _disaridaAc,
          ),
        ],
      ),
      body: SfPdfViewer.network(
        widget.url,
        controller: _kontrol,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        onDocumentLoaded: (d) {
          setState(() {
            _toplamSayfa = d.document.pages.count;
            _hazir = true;
          });
        },
        onPageChanged: (_) => setState(() {}),
        onDocumentLoadFailed: (hata) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF açılamadı: ${hata.description}')),
          );
        },
      ),
    );
  }
}
