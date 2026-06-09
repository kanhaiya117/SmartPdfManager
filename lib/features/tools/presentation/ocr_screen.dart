import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/providers/app_providers.dart';
import 'widgets/tool_scaffold.dart';

class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key});

  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends ConsumerState<OcrScreen> {
  final _picker = ImagePicker();
  final _result = TextEditingController();
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  var _busy = false;

  @override
  void dispose() {
    _result.dispose();
    _recognizer.close();
    super.dispose();
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
      if (recognized.text.trim().isEmpty && mounted) {
        _message('No readable text was detected.');
      }
    } catch (_) {
      if (mounted) _message('Text recognition failed for this image.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePdf() async {
    try {
      final path = await ref
          .read(pdfServiceProvider)
          .textToPdf(
            text: _result.text,
            fontSize: 12,
            bold: false,
            italic: false,
          );
      await ref.read(documentsProvider.notifier).add(path);
      if (mounted) {
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

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Offline OCR',
      subtitle: 'Extract editable text from a photo without uploading it.',
      icon: Icons.document_scanner_outlined,
      child: Column(
        children: [
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
            minLines: 14,
            maxLines: 22,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Recognized text will appear here…',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _result.text.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: _result.text),
                          );
                          if (mounted) _message('Copied to clipboard.');
                        },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy text'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _result.text.trim().isEmpty ? null : _savePdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Save PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
