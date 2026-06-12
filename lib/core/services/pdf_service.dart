import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as plain;
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

import '../errors/app_exception.dart';
import 'file_service.dart';

enum PdfCompressionMode { low, medium, high }

class PdfService {
  PdfService(this._files);

  final FileService _files;

  Future<String> textToPdf({
    required String text,
    required double fontSize,
    required bool bold,
    required bool italic,
  }) async {
    if (text.trim().isEmpty) throw const AppException('Enter some text first.');
    final fonts = await _loadDocumentFonts();
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(42)),
        build: (_) => [
          pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
              lineSpacing: 3,
              font: fonts.regular,
              fontFallback: [fonts.devanagari],
            ),
          ),
        ],
      ),
    );
    return _files.writePdf(await document.save(), 'Text document');
  }

  Future<String> imagesToPdf(List<String> paths, {required int quality}) async {
    if (paths.isEmpty) throw const AppException('Select at least one image.');
    final document = pw.Document();
    for (final path in paths) {
      final source = await File(path).readAsBytes();
      final decoded = img.decodeImage(source);
      if (decoded == null) continue;
      final maxEdge = quality >= 85 ? 2400 : (quality >= 60 ? 1800 : 1200);
      final resized = decoded.width > maxEdge || decoded.height > maxEdge
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? maxEdge : null,
              height: decoded.height > decoded.width ? maxEdge : null,
            )
          : decoded;
      final encoded = img.encodeJpg(resized, quality: quality);
      final image = pw.MemoryImage(Uint8List.fromList(encoded));
      document.addPage(
        pw.Page(
          pageFormat: plain.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (_) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }
    return _files.writePdf(await document.save(), 'Images');
  }

  Future<String> docxToPdf(String path) async {
    final data = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(data);
    final entry = archive.findFile('word/document.xml');
    if (entry == null) throw const AppException('This DOCX file is invalid.');
    final xml = XmlDocument.parse(utf8.decode(entry.content as List<int>));
    final body = xml.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'body')
        .firstOrNull;
    if (body == null) {
      throw const AppException('This DOCX has no document body.');
    }

    final fonts = await _loadDocumentFonts();
    final blocks = <pw.Widget>[];
    for (final child in body.childElements) {
      switch (child.name.local) {
        case 'p':
          final paragraph = _parseDocxParagraph(child, fonts);
          if (paragraph != null) blocks.add(paragraph);
        case 'tbl':
          final table = _parseDocxTable(child, fonts);
          if (table != null) blocks.add(table);
      }
    }
    if (blocks.isEmpty) {
      throw const AppException('No readable content was found in this DOCX.');
    }

    final document = pw.Document();
    document.addPage(
      pw.MultiPage(pageTheme: _docxPageTheme(body), build: (_) => blocks),
    );
    return _files.writePdf(await document.save(), 'Converted document');
  }

  Future<({pw.Font regular, pw.Font devanagari})> _loadDocumentFonts() async {
    final regular = await rootBundle.load('assets/fonts/NotoSans-Variable.ttf');
    final devanagari = await rootBundle.load(
      'assets/fonts/NotoSansDevanagari-Variable.ttf',
    );
    return (regular: pw.Font.ttf(regular), devanagari: pw.Font.ttf(devanagari));
  }

  pw.Widget? _parseDocxParagraph(
    XmlElement paragraph,
    ({pw.Font regular, pw.Font devanagari}) fonts,
  ) {
    final properties = _firstChild(paragraph, 'pPr');
    final styleName =
        _attribute(_firstChild(properties, 'pStyle'), 'val') ?? '';
    final alignment = _attribute(_firstChild(properties, 'jc'), 'val');
    final spacing = _firstChild(properties, 'spacing');
    final indentation = _firstChild(properties, 'ind');
    final isList = _firstChild(properties, 'numPr') != null;
    final isHeading = styleName.toLowerCase().startsWith('heading');
    final headingLevel =
        int.tryParse(styleName.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final baseSize = isHeading
        ? (24 - (headingLevel - 1) * 2).clamp(14, 24)
        : 11;

    final spans = <pw.InlineSpan>[];
    if (isList) {
      spans.add(
        pw.TextSpan(
          text: '• ',
          style: pw.TextStyle(
            font: fonts.regular,
            fontFallback: [fonts.devanagari],
            fontSize: baseSize.toDouble(),
          ),
        ),
      );
    }

    for (final run in paragraph.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'r',
    )) {
      final text = _runText(run);
      if (text.isEmpty) continue;
      final runProperties = _firstChild(run, 'rPr');
      final sizeValue = double.tryParse(
        _attribute(_firstChild(runProperties, 'sz'), 'val') ?? '',
      );
      final decorations = <pw.TextDecoration>[
        if (_firstChild(runProperties, 'u') != null)
          pw.TextDecoration.underline,
        if (_firstChild(runProperties, 'strike') != null)
          pw.TextDecoration.lineThrough,
      ];
      spans.add(
        pw.TextSpan(
          text: text,
          style: pw.TextStyle(
            font: fonts.regular,
            fontFallback: [fonts.devanagari],
            fontSize: sizeValue == null ? baseSize.toDouble() : sizeValue / 2,
            fontWeight: isHeading || _firstChild(runProperties, 'b') != null
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            fontStyle: _firstChild(runProperties, 'i') != null
                ? pw.FontStyle.italic
                : pw.FontStyle.normal,
            decoration: decorations.isEmpty
                ? pw.TextDecoration.none
                : pw.TextDecoration.combine(decorations),
          ),
        ),
      );
    }
    if (spans.isEmpty) return pw.SizedBox(height: 7);
    return pw.Padding(
      padding: pw.EdgeInsets.only(
        left:
            (isList ? 18 : 0) +
            _twips(_attribute(indentation, 'left')) +
            _twips(_attribute(indentation, 'start')),
        right:
            _twips(_attribute(indentation, 'right')) +
            _twips(_attribute(indentation, 'end')),
        bottom: _twips(_attribute(spacing, 'after')) + (isHeading ? 8 : 5),
        top: _twips(_attribute(spacing, 'before')) + (isHeading ? 8 : 0),
      ),
      child: pw.RichText(
        textAlign: switch (alignment) {
          'center' => pw.TextAlign.center,
          'right' || 'end' => pw.TextAlign.right,
          'both' || 'distribute' => pw.TextAlign.justify,
          _ => pw.TextAlign.left,
        },
        text: pw.TextSpan(children: spans),
      ),
    );
  }

  pw.Widget? _parseDocxTable(
    XmlElement table,
    ({pw.Font regular, pw.Font devanagari}) fonts,
  ) {
    final rows = table.childElements
        .where((element) => element.name.local == 'tr')
        .map((row) {
          return pw.TableRow(
            children: row.childElements
                .where((element) => element.name.local == 'tc')
                .map((cell) {
                  final paragraphs = cell.childElements
                      .where((element) => element.name.local == 'p')
                      .map((element) => _parseDocxParagraph(element, fonts))
                      .whereType<pw.Widget>()
                      .toList();
                  return pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: paragraphs,
                    ),
                  );
                })
                .toList(),
          );
        })
        .where((row) => row.children.isNotEmpty)
        .toList();
    if (rows.isEmpty) return null;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Table(
        border: pw.TableBorder.all(width: 0.5, color: plain.PdfColors.grey500),
        children: rows,
      ),
    );
  }

  String _runText(XmlElement run) {
    final buffer = StringBuffer();
    for (final node in run.descendants.whereType<XmlElement>()) {
      switch (node.name.local) {
        case 't':
          buffer.write(node.innerText);
        case 'tab':
          buffer.write('    ');
        case 'br':
        case 'cr':
          buffer.writeln();
      }
    }
    return buffer.toString();
  }

  XmlElement? _firstChild(XmlElement? parent, String localName) {
    if (parent == null) return null;
    return parent.childElements
        .where((element) => element.name.local == localName)
        .firstOrNull;
  }

  String? _attribute(XmlElement? element, String localName) {
    if (element == null) return null;
    for (final attribute in element.attributes) {
      if (attribute.name.local == localName) return attribute.value;
    }
    return null;
  }

  pw.PageTheme _docxPageTheme(XmlElement body) {
    final section = body.childElements
        .where((element) => element.name.local == 'sectPr')
        .firstOrNull;
    final pageSize = _firstChild(section, 'pgSz');
    final margins = _firstChild(section, 'pgMar');
    final width = _twips(_attribute(pageSize, 'w'));
    final height = _twips(_attribute(pageSize, 'h'));
    final format = width > 0 && height > 0
        ? plain.PdfPageFormat(width, height)
        : plain.PdfPageFormat.a4;
    return pw.PageTheme(
      pageFormat: format,
      margin: pw.EdgeInsets.fromLTRB(
        _twips(_attribute(margins, 'left'), fallback: 46),
        _twips(_attribute(margins, 'top'), fallback: 48),
        _twips(_attribute(margins, 'right'), fallback: 46),
        _twips(_attribute(margins, 'bottom'), fallback: 48),
      ),
    );
  }

  double _twips(String? value, {double fallback = 0}) {
    final twips = double.tryParse(value ?? '');
    return twips == null ? fallback : twips / 20;
  }

  Future<String> merge(List<String> paths) async {
    if (paths.length < 2) {
      throw const AppException('Select at least two PDF files.');
    }
    final output = PdfDocument();
    for (final path in paths) {
      final source = PdfDocument(inputBytes: await File(path).readAsBytes());
      for (var i = 0; i < source.pages.count; i++) {
        final template = source.pages[i].createTemplate();
        final page = output.pages.add();
        page.graphics.drawPdfTemplate(
          template,
          Offset.zero,
          page.getClientSize(),
        );
      }
      source.dispose();
    }
    final bytes = output.saveSync();
    output.dispose();
    return _files.writePdf(bytes, 'Merged document');
  }

  Future<String> split(
    String path, {
    required int from,
    required int to,
  }) async {
    final source = PdfDocument(inputBytes: await File(path).readAsBytes());
    if (from < 1 || to < from || to > source.pages.count) {
      source.dispose();
      throw AppException('Enter a range between 1 and ${source.pages.count}.');
    }
    final output = PdfDocument();
    for (var i = from - 1; i < to; i++) {
      final template = source.pages[i].createTemplate();
      final page = output.pages.add();
      page.graphics.drawPdfTemplate(
        template,
        Offset.zero,
        page.getClientSize(),
      );
    }
    final bytes = output.saveSync();
    source.dispose();
    output.dispose();
    return _files.writePdf(bytes, 'Pages $from-$to');
  }

  Future<int> pageCount(String path, {String? password}) async {
    final document = PdfDocument(
      inputBytes: await File(path).readAsBytes(),
      password: password,
    );
    final count = document.pages.count;
    document.dispose();
    return count;
  }

  Future<List<Size>> pageSizes(String path, {String? password}) async {
    final document = PdfDocument(
      inputBytes: await File(path).readAsBytes(),
      password: password,
    );
    final sizes = [
      for (var index = 0; index < document.pages.count; index++)
        document.pages[index].getClientSize(),
    ];
    document.dispose();
    return sizes;
  }

  Future<String> compress(String path, PdfCompressionMode mode) async {
    final document = PdfDocument(inputBytes: await File(path).readAsBytes());
    document.compressionLevel = switch (mode) {
      PdfCompressionMode.low => PdfCompressionLevel.bestSpeed,
      PdfCompressionMode.medium => PdfCompressionLevel.aboveNormal,
      PdfCompressionMode.high => PdfCompressionLevel.best,
    };
    final bytes = document.saveSync();
    document.dispose();
    return _files.writePdf(bytes, 'Compressed document');
  }

  Future<String> protect(String path, String password) async {
    if (password.length < 4) {
      throw const AppException('Use a password with at least 4 characters.');
    }
    final document = PdfDocument(inputBytes: await File(path).readAsBytes());
    document.security
      ..algorithm = PdfEncryptionAlgorithm.aesx256Bit
      ..userPassword = password
      ..ownerPassword = password;
    final bytes = document.saveSync();
    document.dispose();
    return _files.writePdf(bytes, 'Protected document');
  }

  Future<String> removePassword(String path, String password) async {
    final document = PdfDocument(
      inputBytes: await File(path).readAsBytes(),
      password: password,
    );
    document.security
      ..userPassword = ''
      ..ownerPassword = '';
    final bytes = document.saveSync();
    document.dispose();
    return _files.writePdf(bytes, 'Unlocked document');
  }

  Future<String> watermark({
    required String path,
    required String text,
    required double opacity,
  }) async {
    final document = PdfDocument(inputBytes: await File(path).readAsBytes());
    for (var i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final size = page.getClientSize();
      final graphics = page.graphics;
      graphics.save();
      graphics.setTransparency(opacity);
      graphics.translateTransform(size.width / 2, size.height / 2);
      graphics.rotateTransform(-35);
      graphics.drawString(
        text,
        PdfStandardFont(PdfFontFamily.helvetica, 46, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(PdfColor(79, 70, 229)),
        bounds: Rect.fromLTWH(-size.width / 2, -30, size.width, 70),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      graphics.restore();
    }
    final bytes = document.saveSync();
    document.dispose();
    return _files.writePdf(bytes, 'Watermarked document');
  }

  Future<String> addText({
    required String path,
    required String text,
    required int pageNumber,
    required double x,
    required double y,
    required double fontSize,
  }) async {
    final document = PdfDocument(inputBytes: await File(path).readAsBytes());
    if (pageNumber < 1 || pageNumber > document.pages.count) {
      document.dispose();
      throw const AppException('The selected page does not exist.');
    }
    document.pages[pageNumber - 1].graphics.drawString(
      text,
      PdfStandardFont(PdfFontFamily.helvetica, fontSize),
      brush: PdfSolidBrush(PdfColor(20, 24, 35)),
      bounds: Rect.fromLTWH(x, y, 400, fontSize * 3),
    );
    final bytes = document.saveSync();
    document.dispose();
    return _files.writePdf(bytes, 'Edited document');
  }

  Future<String> addSignature({
    required String path,
    required Uint8List signature,
    required int pageNumber,
    required double x,
    required double y,
    required double width,
  }) async {
    final document = PdfDocument(inputBytes: await File(path).readAsBytes());
    if (pageNumber < 1 || pageNumber > document.pages.count) {
      document.dispose();
      throw const AppException('The selected page does not exist.');
    }
    document.pages[pageNumber - 1].graphics.drawImage(
      PdfBitmap(signature),
      Rect.fromLTWH(x, y, width, width * 0.42),
    );
    final bytes = document.saveSync();
    document.dispose();
    return _files.writePdf(bytes, 'Signed document');
  }
}
