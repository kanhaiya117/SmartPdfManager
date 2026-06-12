import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pdf_manager/core/services/file_service.dart';
import 'package:smart_pdf_manager/core/services/pdf_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DOCX conversion preserves structured multilingual content', () async {
    final directory = await Directory.systemTemp.createTemp('smart_pdf_test');
    addTearDown(() => directory.delete(recursive: true));
    final docx = File('${directory.path}/formatted.docx');
    await docx.writeAsBytes(_formattedDocx());

    final service = PdfService(_TestFileService(directory));
    final outputPath = await service.docxToPdf(docx.path);

    final output = File(outputPath);
    expect(output.existsSync(), isTrue);
    expect(output.lengthSync(), greaterThan(1000));
    final artifacts = await Directory(
      'build/test-artifacts',
    ).create(recursive: true);
    await output.copy('${artifacts.path}/formatted-docx.pdf');

    final document = PdfDocument(inputBytes: await output.readAsBytes());
    final extracted = PdfTextExtractor(
      document,
    ).extractText().replaceAll(RegExp(r'\s+'), ' ').trim();
    document.dispose();

    expect(extracted, contains('Quarterly Report'));
    expect(extracted, contains('Important result'));
    expect(extracted, contains('हिंदी सामग्री'));
    expect(extracted, contains('Revenue'));
    expect(extracted, contains('Growth'));
  });

  test('text PDF embeds Devanagari text', () async {
    final directory = await Directory.systemTemp.createTemp('smart_pdf_text');
    addTearDown(() => directory.delete(recursive: true));
    final service = PdfService(_TestFileService(directory));

    final outputPath = await service.textToPdf(
      text: 'ऑफ़लाइन ओसीआर सारांश',
      fontSize: 12,
      bold: false,
      italic: false,
    );

    final document = PdfDocument(
      inputBytes: await File(outputPath).readAsBytes(),
    );
    final extracted = PdfTextExtractor(document).extractText();
    document.dispose();
    expect(extracted, contains('ऑफ़लाइन'));
  });

  test('signature is applied at requested page coordinates', () async {
    final directory = await Directory.systemTemp.createTemp('smart_pdf_sign');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/source.pdf');
    final sourceDocument = PdfDocument();
    sourceDocument.pages.add();
    final sourceBytes = sourceDocument.saveSync();
    sourceDocument.dispose();
    await source.writeAsBytes(sourceBytes);

    final service = PdfService(_TestFileService(directory));
    final sizes = await service.pageSizes(source.path);
    expect(sizes, hasLength(1));
    expect(sizes.single.width, greaterThan(0));

    final outputPath = await service.addSignature(
      path: source.path,
      signature: Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
          'AAAADUlEQVQIHWP4z8DwHwAFgAI/ScLx5QAAAABJRU5ErkJggg==',
        ),
      ),
      pageNumber: 1,
      x: 120,
      y: 240,
      width: 160,
    );

    final output = File(outputPath);
    expect(output.existsSync(), isTrue);
    expect(output.lengthSync(), greaterThan(sourceBytes.length));
    final signed = PdfDocument(inputBytes: await output.readAsBytes());
    expect(signed.pages.count, 1);
    signed.dispose();
  });
}

class _TestFileService extends FileService {
  _TestFileService(this.directory);

  final Directory directory;
  var _counter = 0;

  @override
  Future<String> writePdf(List<int> bytes, String stem) async {
    final file = File('${directory.path}/${_counter++}.pdf');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}

List<int> _formattedDocx() {
  const documentXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/><w:jc w:val="center"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="36"/></w:rPr><w:t>Quarterly Report</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:rPr><w:b/><w:u w:val="single"/></w:rPr><w:t>Important result</w:t></w:r>
      <w:r><w:t xml:space="preserve"> with formatting.</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>हिंदी सामग्री सही दिखनी चाहिए।</w:t></w:r>
    </w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Revenue</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Growth</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>100</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>25%</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
    <w:sectPr/>
  </w:body>
</w:document>
''';
  final bytes = utf8.encode(documentXml);
  final archive = Archive()
    ..addFile(ArchiveFile('word/document.xml', bytes.length, bytes));
  return ZipEncoder().encode(archive);
}
