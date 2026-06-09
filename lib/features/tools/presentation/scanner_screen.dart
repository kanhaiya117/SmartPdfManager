import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/providers/app_providers.dart';
import 'widgets/tool_scaffold.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final _picker = ImagePicker();
  final List<String> _pages = [];
  var _busy = false;

  Future<void> _capture() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (photo == null || !mounted) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: photo.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 92,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust document edges',
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
      ],
    );
    if (cropped != null) setState(() => _pages.add(cropped.path));
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final path = await ref
          .read(pdfServiceProvider)
          .imagesToPdf(_pages, quality: 88);
      await ref.read(documentsProvider.notifier).add(path);
      if (mounted) await OpenFilex.open(path);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Scan Document',
      subtitle: 'Capture, crop and combine multiple pages into one PDF.',
      icon: Icons.document_scanner_rounded,
      child: Column(
        children: [
          FilledButton.icon(
            onPressed: _capture,
            icon: const Icon(Icons.camera_alt_rounded),
            label: Text(_pages.isEmpty ? 'Capture first page' : 'Add page'),
          ),
          const SizedBox(height: 14),
          if (_pages.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(Icons.crop_free_rounded, size: 58),
                    SizedBox(height: 12),
                    Text(
                      'Place the document on a contrasting surface and keep the camera steady.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 360,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pages.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final item = _pages.removeAt(oldIndex);
                    _pages.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) => Card(
                  key: ValueKey(_pages[index]),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: 235,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(_pages[index]), fit: BoxFit.cover),
                        Positioned(
                          left: 10,
                          top: 10,
                          child: Chip(label: Text('Page ${index + 1}')),
                        ),
                        Positioned(
                          right: 7,
                          top: 7,
                          child: IconButton.filled(
                            onPressed: () =>
                                setState(() => _pages.removeAt(index)),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _pages.isEmpty || _busy ? null : _create,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: Text('Create PDF (${_pages.length} pages)'),
          ),
        ],
      ),
    );
  }
}
