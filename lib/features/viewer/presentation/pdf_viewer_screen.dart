import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/app_background.dart';

class PdfViewerScreen extends ConsumerStatefulWidget {
  const PdfViewerScreen({required this.path, super.key});

  final String path;

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  final _controller = PdfViewerController();
  PdfTextSearchResult? _searchResult;
  var _pageNumber = 1;
  var _pageCount = 0;
  var _annotationMode = PdfAnnotationMode.none;

  @override
  void dispose() {
    _searchResult?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final textController = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search in PDF'),
        content: TextField(
          controller: textController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search text',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (query == null || query.trim().isEmpty) return;
    _searchResult?.dispose();
    final result = _controller.searchText(query.trim());
    if (!mounted) return;
    setState(() => _searchResult = result);
    if (result.totalInstanceCount == 0) {
      _message('No matches found.');
    }
  }

  Future<void> _jumpToPage() async {
    final textController = TextEditingController(text: '$_pageNumber');
    final page = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jump to page'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1–$_pageCount'),
          onSubmitted: (value) {
            Navigator.pop(context, int.tryParse(value));
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(textController.text)),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (page == null || page < 1 || page > _pageCount) return;
    _controller.jumpToPage(page);
  }

  Future<void> _saveAnnotations() async {
    try {
      final bytes = await _controller.saveDocument();
      final path = await ref
          .read(fileServiceProvider)
          .writePdf(bytes, '${p.basenameWithoutExtension(widget.path)} edited');
      await ref.read(documentsProvider.notifier).add(path);
      if (mounted) _message('Saved as ${p.basename(path)}');
    } catch (_) {
      if (mounted) _message('Could not save the edited PDF.');
    }
  }

  void _setAnnotation(PdfAnnotationMode mode) {
    setState(() {
      _annotationMode = _annotationMode == mode ? PdfAnnotationMode.none : mode;
      _controller.annotationMode = _annotationMode;
    });
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final readerDarkMode = ref.watch(settingsProvider).readerDarkMode;
    final search = _searchResult;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            p.basename(widget.path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              onPressed: _search,
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Search text',
            ),
            PopupMenuButton<PdfAnnotationMode>(
              tooltip: 'Annotate',
              initialValue: _annotationMode,
              onSelected: _setAnnotation,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: PdfAnnotationMode.highlight,
                  child: ListTile(
                    leading: Icon(Icons.highlight_rounded),
                    title: Text('Highlight'),
                  ),
                ),
                PopupMenuItem(
                  value: PdfAnnotationMode.underline,
                  child: ListTile(
                    leading: Icon(Icons.format_underlined_rounded),
                    title: Text('Underline'),
                  ),
                ),
                PopupMenuItem(
                  value: PdfAnnotationMode.strikethrough,
                  child: ListTile(
                    leading: Icon(Icons.format_strikethrough_rounded),
                    title: Text('Strike-through'),
                  ),
                ),
                PopupMenuItem(
                  value: PdfAnnotationMode.stickyNote,
                  child: ListTile(
                    leading: Icon(Icons.sticky_note_2_outlined),
                    title: Text('Note'),
                  ),
                ),
              ],
              icon: Icon(
                Icons.edit_note_rounded,
                color: _annotationMode == PdfAnnotationMode.none
                    ? null
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            IconButton(
              onPressed: _saveAnnotations,
              icon: const Icon(Icons.save_alt_rounded),
              tooltip: 'Save a copy',
            ),
          ],
        ),
        body: Column(
          children: [
            if (search != null && search.totalInstanceCount > 0)
              Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: search.previousInstance,
                        icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      ),
                      Text(
                        '${search.currentInstanceIndex} / ${search.totalInstanceCount}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        onPressed: search.nextInstance,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                      IconButton(
                        onPressed: () {
                          search.clear();
                          setState(() => _searchResult = null);
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: ColorFiltered(
                colorFilter: readerDarkMode
                    ? const ColorFilter.matrix([
                        -1,
                        0,
                        0,
                        0,
                        255,
                        0,
                        -1,
                        0,
                        0,
                        255,
                        0,
                        0,
                        -1,
                        0,
                        255,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ])
                    : const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.multiply,
                      ),
                child: SfPdfViewer.file(
                  File(widget.path),
                  controller: _controller,
                  canShowScrollHead: true,
                  canShowScrollStatus: true,
                  enableDoubleTapZooming: true,
                  onDocumentLoaded: (details) {
                    setState(() => _pageCount = details.document.pages.count);
                  },
                  onPageChanged: (details) {
                    setState(() => _pageNumber = details.newPageNumber);
                  },
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: SizedBox(
                  height: 58,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          _controller.zoomLevel = (_controller.zoomLevel - 0.25)
                              .clamp(1, 3);
                        },
                        icon: const Icon(Icons.zoom_out_rounded),
                      ),
                      TextButton.icon(
                        onPressed: _jumpToPage,
                        icon: const Icon(Icons.find_in_page_outlined),
                        label: Text('$_pageNumber / $_pageCount'),
                      ),
                      IconButton(
                        onPressed: () {
                          _controller.zoomLevel = (_controller.zoomLevel + 0.25)
                              .clamp(1, 3);
                        },
                        icon: const Icon(Icons.zoom_in_rounded),
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
  }
}
