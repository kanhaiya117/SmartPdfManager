import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/providers/app_providers.dart';
import 'widgets/tool_scaffold.dart';

class SignatureScreen extends ConsumerStatefulWidget {
  const SignatureScreen({super.key});

  @override
  ConsumerState<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends ConsumerState<SignatureScreen> {
  final _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );
  final _pdfController = PdfViewerController();
  String? _pdfPath;
  final List<String> _savedSignatures = [];
  String? _selectedSignaturePath;
  Uint8List? _selectedSignature;
  List<Size> _pageSizes = const [];
  var _currentPage = 1;
  var _xFraction = 0.18;
  var _yFraction = 0.72;
  var _widthFraction = 0.34;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSignatures();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _pdfController.dispose();
    super.dispose();
  }

  Future<Directory> _signatureDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(base.path, 'signatures'));
    if (!directory.existsSync()) await directory.create(recursive: true);
    return directory;
  }

  Future<void> _loadSignatures() async {
    final directory = await _signatureDirectory();
    final files =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => p.extension(file.path).toLowerCase() == '.png')
            .map((file) => file.path)
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (mounted) setState(() => _savedSignatures.addAll(files));
  }

  Future<void> _choosePdf() async {
    final path = await ref.read(fileServiceProvider).pickPdf();
    if (path == null) return;
    try {
      final sizes = await ref.read(pdfServiceProvider).pageSizes(path);
      if (!mounted) return;
      setState(() {
        _pdfPath = path;
        _pageSizes = sizes;
        _currentPage = 1;
        _xFraction = 0.18;
        _yFraction = 0.72;
        _widthFraction = 0.34;
      });
    } catch (error) {
      if (mounted) _message(error.toString());
    }
  }

  Future<void> _saveDrawing() async {
    final bytes = await _signatureController.toPngBytes();
    if (bytes == null || bytes.isEmpty) {
      _message('Draw a signature first.');
      return;
    }
    final directory = await _signatureDirectory();
    final file = File(
      p.join(
        directory.path,
        'signature_${DateTime.now().millisecondsSinceEpoch}.png',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    setState(() {
      _savedSignatures.insert(0, file.path);
      _selectedSignaturePath = file.path;
      _selectedSignature = bytes;
    });
    _signatureController.clear();
  }

  Future<void> _selectSignature(String path) async {
    final bytes = await File(path).readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedSignaturePath = path;
      _selectedSignature = bytes;
    });
  }

  Future<void> _sign() async {
    if (_pdfPath == null || _selectedSignature == null || _pageSizes.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      final pageSize = _pageSizes[_currentPage - 1];
      final output = await ref
          .read(pdfServiceProvider)
          .addSignature(
            path: _pdfPath!,
            signature: _selectedSignature!,
            pageNumber: _currentPage,
            x: _xFraction * pageSize.width,
            y: _yFraction * pageSize.height,
            width: _widthFraction * pageSize.width,
          );
      await ref.read(documentsProvider.notifier).add(output);
      if (mounted) {
        await ref
            .read(interstitialAdServiceProvider)
            .showAfterCompletedAction(
              onContinue: () async {
                await OpenFilex.open(output);
              },
            );
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _moveSignature(DragUpdateDetails details, Size previewSize) {
    final heightFraction = _widthFraction * 0.42;
    setState(() {
      _xFraction = (_xFraction + details.delta.dx / previewSize.width).clamp(
        0,
        1 - _widthFraction,
      );
      _yFraction = (_yFraction + details.delta.dy / previewSize.height).clamp(
        0,
        1 - heightFraction,
      );
    });
  }

  void _resizeSignature(DragUpdateDetails details, Size previewSize) {
    setState(() {
      _widthFraction = (_widthFraction + details.delta.dx / previewSize.width)
          .clamp(0.14, 0.78);
      _xFraction = _xFraction.clamp(0, 1 - _widthFraction);
      _yFraction = _yFraction.clamp(0, 1 - _widthFraction * 0.42);
    });
  }

  void _goToPage(int page) {
    if (page < 1 || page > _pageSizes.length) return;
    _pdfController.jumpToPage(page);
    setState(() => _currentPage = page);
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Sign PDF',
      subtitle:
          'Select a signature, then drag and resize it directly on a PDF page.',
      icon: Icons.draw_rounded,
      child: Column(
        children: [
          SelectedFileCard(path: _pdfPath, onChoose: _choosePdf),
          const SizedBox(height: 14),
          _SignatureDrawingCard(
            controller: _signatureController,
            onSave: _saveDrawing,
          ),
          if (_savedSignatures.isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Saved signatures',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _savedSignatures.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final path = _savedSignatures[index];
                  final selected = path == _selectedSignaturePath;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _selectSignature(path),
                    child: Container(
                      width: 155,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          width: 3,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                        ),
                      ),
                      child: Image.file(File(path), fit: BoxFit.contain),
                    ),
                  );
                },
              ),
            ),
          ],
          if (_pdfPath != null && _pageSizes.isNotEmpty) ...[
            const SizedBox(height: 18),
            _PlacementPreview(
              path: _pdfPath!,
              controller: _pdfController,
              pageSize: _pageSizes[_currentPage - 1],
              currentPage: _currentPage,
              pageCount: _pageSizes.length,
              signature: _selectedSignature,
              xFraction: _xFraction,
              yFraction: _yFraction,
              widthFraction: _widthFraction,
              onMove: _moveSignature,
              onResize: _resizeSignature,
              onPageChanged: (page) {
                if (mounted) setState(() => _currentPage = page);
              },
              onPrevious: () => _goToPage(_currentPage - 1),
              onNext: () => _goToPage(_currentPage + 1),
            ),
            const SizedBox(height: 10),
            const Card(
              child: ListTile(
                leading: Icon(Icons.open_with_rounded),
                title: Text('Drag to position'),
                subtitle: Text(
                  'Move the signature anywhere on the page. Drag its blue corner handle to resize it.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed:
                _pdfPath == null ||
                    _selectedSignature == null ||
                    _pageSizes.isEmpty ||
                    _busy
                ? null
                : _sign,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_rounded),
            label: Text('Apply to page $_currentPage and save'),
          ),
        ],
      ),
    );
  }
}

class _SignatureDrawingCard extends StatelessWidget {
  const _SignatureDrawingCard({required this.controller, required this.onSave});

  final SignatureController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Signature(
              controller: controller,
              backgroundColor: Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.clear,
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save signature'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacementPreview extends StatelessWidget {
  const _PlacementPreview({
    required this.path,
    required this.controller,
    required this.pageSize,
    required this.currentPage,
    required this.pageCount,
    required this.signature,
    required this.xFraction,
    required this.yFraction,
    required this.widthFraction,
    required this.onMove,
    required this.onResize,
    required this.onPageChanged,
    required this.onPrevious,
    required this.onNext,
  });

  final String path;
  final PdfViewerController controller;
  final Size pageSize;
  final int currentPage;
  final int pageCount;
  final Uint8List? signature;
  final double xFraction;
  final double yFraction;
  final double widthFraction;
  final void Function(DragUpdateDetails details, Size previewSize) onMove;
  final void Function(DragUpdateDetails details, Size previewSize) onResize;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 500,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pageAspect = pageSize.width / pageSize.height;
                final boxAspect = constraints.maxWidth / constraints.maxHeight;
                final previewSize = boxAspect > pageAspect
                    ? Size(
                        constraints.maxHeight * pageAspect,
                        constraints.maxHeight,
                      )
                    : Size(
                        constraints.maxWidth,
                        constraints.maxWidth / pageAspect,
                      );
                final signatureWidth = previewSize.width * widthFraction;
                final signatureHeight = signatureWidth * 0.42;
                return Center(
                  child: SizedBox.fromSize(
                    size: previewSize,
                    child: Stack(
                      children: [
                        SfPdfViewer.file(
                          File(path),
                          controller: controller,
                          pageLayoutMode: PdfPageLayoutMode.single,
                          canShowScrollHead: false,
                          canShowScrollStatus: false,
                          enableDoubleTapZooming: false,
                          maxZoomLevel: 1,
                          onPageChanged: (details) =>
                              onPageChanged(details.newPageNumber),
                        ),
                        if (signature != null)
                          Positioned(
                            left: previewSize.width * xFraction,
                            top: previewSize.height * yFraction,
                            width: signatureWidth,
                            height: signatureHeight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: (details) =>
                                  onMove(details, previewSize),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 2,
                                  ),
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(3),
                                      child: Image.memory(
                                        signature!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanUpdate: (details) =>
                                            onResize(details, previewSize),
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(12),
                                                ),
                                          ),
                                          child: const Icon(
                                            Icons.open_in_full_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: currentPage > 1 ? onPrevious : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  'Page $currentPage of $pageCount',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: currentPage < pageCount ? onNext : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
