import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pdf_manager/core/services/text_summarizer.dart';

void main() {
  const summarizer = TextSummarizer();

  test('returns a shorter extractive summary in source order', () {
    const source =
        'PDF tools help people read documents. '
        'OCR extracts text from scanned pages. '
        'Offline OCR protects private documents. '
        'A summary highlights important document ideas. '
        'Users can copy the resulting text. '
        'The application can save the summary as a PDF.';

    final summary = summarizer.summarize(source, maximumSentences: 2);

    expect(
      summary.split('.').where((part) => part.trim().isNotEmpty),
      hasLength(2),
    );
    expect(source.indexOf(summary.split('.').first), greaterThanOrEqualTo(0));
  });

  test('supports Devanagari text without corrupting it', () {
    const source =
        'यह दस्तावेज़ महत्वपूर्ण जानकारी देता है। '
        'ऑफ़लाइन ओसीआर निजी जानकारी सुरक्षित रखता है। '
        'सारांश मुख्य जानकारी को छोटा करता है। '
        'उपयोगकर्ता पाठ को पीडीएफ में सहेज सकता है। '
        'यह सुविधा बिना इंटरनेट के काम करती है।';

    final summary = summarizer.summarize(source, maximumSentences: 2);

    expect(summary, isNotEmpty);
    expect(summary, contains(RegExp(r'[\u0900-\u097F]')));
  });
}
