import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/app_providers.dart';
import 'widgets/tool_scaffold.dart';

class TextToPdfScreen extends ConsumerStatefulWidget {
  const TextToPdfScreen({super.key});

  @override
  ConsumerState<TextToPdfScreen> createState() => _TextToPdfScreenState();
}

class _TextToPdfScreenState extends ConsumerState<TextToPdfScreen> {
  final _text = TextEditingController();
  var _fontSize = 14.0;
  var _bold = false;
  var _italic = false;
  var _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final path = await ref
          .read(pdfServiceProvider)
          .textToPdf(
            text: _text.text,
            fontSize: _fontSize,
            bold: _bold,
            italic: _italic,
          );
      await ref.read(documentsProvider.notifier).add(path);
      if (mounted) {
        await ref
            .read(interstitialAdServiceProvider)
            .showAfterCompletedAction(
              onContinue: () =>
                  mounted ? _showResult(context, path) : Future<void>.value(),
            );
      }
    } catch (error) {
      if (mounted) _message(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Text to PDF',
      subtitle: 'Turn notes and typed content into a clean, shareable PDF.',
      icon: Icons.text_fields_rounded,
      child: Column(
        children: [
          TextField(
            controller: _text,
            minLines: 10,
            maxLines: 18,
            decoration: const InputDecoration(
              hintText: 'Start writing your document…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('Font size'),
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 9,
                          max: 28,
                          divisions: 19,
                          label: _fontSize.round().toString(),
                          onChanged: (value) =>
                              setState(() => _fontSize = value),
                        ),
                      ),
                      Text('${_fontSize.round()} pt'),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      FilterChip(
                        selected: _bold,
                        onSelected: (value) => setState(() => _bold = value),
                        avatar: const Icon(Icons.format_bold_rounded),
                        label: const Text('Bold'),
                      ),
                      FilterChip(
                        selected: _italic,
                        onSelected: (value) => setState(() => _italic = value),
                        avatar: const Icon(Icons.format_italic_rounded),
                        label: const Text('Italic'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Create PDF'),
          ),
        ],
      ),
    );
  }
}

class ImageToPdfScreen extends ConsumerStatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  ConsumerState<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends ConsumerState<ImageToPdfScreen> {
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  var _quality = 80.0;
  var _busy = false;

  Future<void> _pick() async {
    final selected = await _picker.pickMultiImage();
    if (selected.isNotEmpty) setState(() => _images.addAll(selected));
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final path = await ref
          .read(pdfServiceProvider)
          .imagesToPdf(
            _images.map((item) => item.path).toList(),
            quality: _quality.round(),
          );
      await ref.read(documentsProvider.notifier).add(path);
      if (mounted) {
        await ref
            .read(interstitialAdServiceProvider)
            .showAfterCompletedAction(
              onContinue: () =>
                  mounted ? _showResult(context, path) : Future<void>.value(),
            );
      }
    } catch (error) {
      if (mounted) _message(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Image to PDF',
      subtitle: 'Arrange multiple photos and export them as one document.',
      icon: Icons.photo_library_rounded,
      child: Column(
        children: [
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text('Select images'),
          ),
          const SizedBox(height: 12),
          if (_images.isNotEmpty)
            SizedBox(
              height: 190,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final item = _images.removeAt(oldIndex);
                    _images.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) => Card(
                  key: ValueKey(_images[index].path),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: 130,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(_images[index].path),
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton.filled(
                            onPressed: () =>
                                setState(() => _images.removeAt(index)),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: CircleAvatar(
                            radius: 14,
                            child: Text('${index + 1}'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Text('Image quality'),
                  Expanded(
                    child: Slider(
                      value: _quality,
                      min: 35,
                      max: 95,
                      divisions: 12,
                      label: '${_quality.round()}%',
                      onChanged: (value) => setState(() => _quality = value),
                    ),
                  ),
                  Text('${_quality.round()}%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: Text('Create PDF (${_images.length} images)'),
          ),
        ],
      ),
    );
  }
}

class DocxToPdfScreen extends ConsumerStatefulWidget {
  const DocxToPdfScreen({super.key});

  @override
  ConsumerState<DocxToPdfScreen> createState() => _DocxToPdfScreenState();
}

class _DocxToPdfScreenState extends ConsumerState<DocxToPdfScreen> {
  String? _path;
  var _busy = false;

  Future<void> _convert() async {
    if (_path == null) return;
    setState(() => _busy = true);
    try {
      final output = await ref.read(pdfServiceProvider).docxToPdf(_path!);
      await ref.read(documentsProvider.notifier).add(output);
      if (mounted) {
        await ref
            .read(interstitialAdServiceProvider)
            .showAfterCompletedAction(
              onContinue: () =>
                  mounted ? _showResult(context, output) : Future<void>.value(),
            );
      }
    } catch (error) {
      if (mounted) _message(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'DOCX to PDF',
      subtitle: 'Preserve headings, text styles, lists and tables offline.',
      icon: Icons.description_rounded,
      child: Column(
        children: [
          SelectedFileCard(
            path: _path,
            label: 'Select DOCX',
            onChoose: () async {
              final path = await ref.read(fileServiceProvider).pickDocx();
              if (path != null) setState(() => _path = path);
            },
          ),
          const SizedBox(height: 10),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('Formatting support'),
              subtitle: Text(
                'Preserves paragraphs, headings, bold, italic, underline, strike-through, alignment, lists, tables and Hindi text. Floating shapes and advanced Word effects may differ.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _path == null || _busy ? null : _convert,
            icon: const Icon(Icons.sync_alt_rounded),
            label: const Text('Convert to PDF'),
          ),
        ],
      ),
    );
  }
}

Future<void> _showResult(BuildContext context, String path) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 58, color: Colors.green),
          const SizedBox(height: 10),
          Text(
            'PDF ready',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(path, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(files: [XFile(path)]),
                  ),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => OpenFilex.open(path),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

void _message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
