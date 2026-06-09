import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
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
    final xml = XmlDocument.parse(String.fromCharCodes(entry.content));
    final paragraphs = xml
        .findAllElements('w:p')
        .map(
          (paragraph) => paragraph
              .findAllElements('w:t')
              .map((node) => node.innerText)
              .join(),
        )
        .where((value) => value.trim().isNotEmpty)
        .toList();
    return textToPdf(
      text: paragraphs.join('\n\n'),
      fontSize: 12,
      bold: false,
      italic: false,
    );
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
