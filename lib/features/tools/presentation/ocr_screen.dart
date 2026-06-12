import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/services/text_summarizer.dart';
import 'widgets/tool_scaffold.dart';

class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key});

  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends ConsumerState<OcrScreen> {
  final _picker = ImagePicker();
  final _result = TextEditingController();
  final _summary = TextEditingController();
  final _summarizer = const TextSummarizer();
  var _script = TextRecognitionScript.latin;
  late TextRecognizer _recognizer = TextRecognizer(script: _script);
  var _busy = false;
  var _summarizing = false;

  @override
  void dispose() {
    _result.dispose();
    _summary.dispose();
    _recognizer.close();
    super.dispose();
  }

  Future<void> _setScript(TextRecognitionScript script) async {
    if (script == _script) return;
    await _recognizer.close();
    _recognizer = TextRecognizer(script: script);
    setState(() => _script = script);
  }

  Future<void> _recognize(ImageSource source) async {
    final image = await _picker.pickImage(source: source, imageQuality: 95);
    if (image == null) return;
    setState(() => _busy = true);
    try {
      final recognized = await _recognizer.processImage(
        InputImage.fromFilePath(image.path),
      );
      _result.text = recognized.text;
      _summary.clear();
      if (recognized.text.trim().isEmpty) {
        _message(
          'No readable text was detected. Check the selected text language and image clarity.',
        );
      } else {
        setState(() {});
      }
    } catch (error) {
      _message('Text recognition failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _summarize() async {
    if (_result.text.trim().isEmpty) return;
    setState(() => _summarizing = true);
    await Future<void>.delayed(Duration.zero);
    final summary = _summarizer.summarize(_result.text);
    if (!mounted) return;
    _summary.text = summary;
    setState(() => _summarizing = false);
    if (summary.isEmpty) _message('There was not enough text to summarize.');
  }

  Future<void> _savePdf(String text, String label) async {
    try {
      final path = await ref
          .read(pdfServiceProvider)
          .textToPdf(text: text, fontSize: 12, bold: false, italic: false);
      await ref.read(documentsProvider.notifier).add(path);
      if (mounted) {
        _message('$label saved as PDF.');
        await ref
            .read(interstitialAdServiceProvider)
            .showAfterCompletedAction(
              onContinue: () async {
                await OpenFilex.open(path);
              },
            );
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _message('Copied to clipboard.');
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _result.text.trim().isNotEmpty;
    final hasSummary = _summary.text.trim().isNotEmpty;
    return ToolScaffold(
      title: 'Offline OCR',
      subtitle: 'Extract and summarize text locally without uploading it.',
      icon: Icons.document_scanner_outlined,
      child: Column(
        children: [
          DropdownButtonFormField<TextRecognitionScript>(
            initialValue: _script,
            decoration: const InputDecoration(
              labelText: 'Text language / script',
              prefixIcon: Icon(Icons.translate_rounded),
            ),
            items:
                const [
                      TextRecognitionScript.latin,
                      TextRecognitionScript.devanagiri,
                    ]
                    .map(
                      (script) => DropdownMenuItem(
                        value: script,
                        child: Text(_scriptLabel(script)),
                      ),
                    )
                    .toList(),
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) _setScript(value);
                  },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _recognize(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _recognize(ImageSource.gallery),
                  icon: const Icon(Icons.image_rounded),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_busy) const LinearProgressIndicator(),
          TextField(
            controller: _result,
            minLines: 12,
            maxLines: 20,
            onChanged: (_) {
              _summary.clear();
              setState(() {});
            },
            decoration: const InputDecoration(
              labelText: 'Extracted text',
              hintText: 'Recognized text will appear here...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: hasText ? () => _copy(_result.text) : null,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy text'),
              ),
              OutlinedButton.icon(
                onPressed: hasText
                    ? () => _savePdf(_result.text, 'Extracted text')
                    : null,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Text PDF'),
              ),
              FilledButton.icon(
                onPressed: hasText && !_summarizing ? _summarize : null,
                icon: _summarizing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.summarize_rounded),
                label: const Text('Summarize'),
              ),
            ],
          ),
          if (hasSummary) ...[
            const SizedBox(height: 18),
            TextField(
              controller: _summary,
              minLines: 5,
              maxLines: 10,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Summary',
                prefixIcon: Icon(Icons.auto_awesome_rounded),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copy(_summary.text),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy summary'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _savePdf(_summary.text, 'Summary'),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('Summary PDF'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _scriptLabel(TextRecognitionScript script) => switch (script) {
  TextRecognitionScript.latin => 'Latin / English',
  TextRecognitionScript.devanagiri => 'Devanagari / Hindi',
  _ => 'Unsupported',
};
