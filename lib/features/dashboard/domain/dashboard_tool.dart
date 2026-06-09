import 'package:flutter/material.dart';

enum DashboardTool {
  reader('PDF Reader', 'Open and read documents', Icons.picture_as_pdf_rounded),
  scanner(
    'Scan Document',
    'Camera to polished PDF',
    Icons.document_scanner_rounded,
  ),
  sign('Sign PDF', 'Draw and place signatures', Icons.draw_rounded),
  textToPdf(
    'Text to PDF',
    'Create formatted documents',
    Icons.text_fields_rounded,
  ),
  imageToPdf(
    'Image to PDF',
    'Combine and reorder photos',
    Icons.photo_library_rounded,
  ),
  docxToPdf(
    'DOCX to PDF',
    'Offline document conversion',
    Icons.description_rounded,
  ),
  merge('Merge PDF', 'Combine multiple files', Icons.call_merge_rounded),
  split('Split PDF', 'Extract a page range', Icons.call_split_rounded),
  compress('Compress PDF', 'Reduce document size', Icons.compress_rounded),
  ocr(
    'Offline OCR',
    'Extract text from images',
    Icons.document_scanner_outlined,
  ),
  edit('Edit PDF', 'Add text and annotations', Icons.edit_document),
  security('Protect PDF', 'Add or remove a password', Icons.lock_rounded),
  watermark(
    'Watermark',
    'Add a custom text mark',
    Icons.branding_watermark_rounded,
  );

  const DashboardTool(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final IconData icon;
}
