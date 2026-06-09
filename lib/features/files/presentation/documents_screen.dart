import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/models/document_record.dart';
import '../../../core/providers/app_providers.dart';
import '../../viewer/presentation/pdf_viewer_screen.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({this.favoritesOnly = false, super.key});

  final bool favoritesOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(documentsProvider);
    final items = favoritesOnly
        ? all.where((item) => item.isFavorite).toList()
        : all;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Text(
            favoritesOnly ? 'Favorites' : 'Recent files',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? _EmptyState(favoritesOnly: favoritesOnly)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _DocumentTile(item: items[index]),
                ),
        ),
      ],
    );
  }
}

class _DocumentTile extends ConsumerWidget {
  const _DocumentTile({required this.item});

  final DocumentRecord item;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: p.basenameWithoutExtension(item.name),
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename PDF'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'File name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      final newPath = await ref
          .read(fileServiceProvider)
          .rename(item.path, name);
      await ref
          .read(documentsProvider.notifier)
          .replacePath(item.path, newPath);
    } catch (_) {
      if (context.mounted) _message(context, 'Could not rename this file.');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete PDF?'),
            content: Text('This will permanently delete ${item.name}.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await File(item.path).delete();
      await ref.read(documentsProvider.notifier).remove(item.path);
    } catch (_) {
      if (context.mounted) _message(context, 'Could not delete this file.');
    }
  }

  Future<void> _copyOrMove(
    BuildContext context,
    WidgetRef ref, {
    required bool move,
  }) async {
    final service = ref.read(fileServiceProvider);
    final directory = await service.chooseDirectory();
    if (directory == null) return;
    try {
      final path = await service.copyOrMove(item.path, directory, move: move);
      if (move) {
        await ref.read(documentsProvider.notifier).replacePath(item.path, path);
      } else {
        await ref.read(documentsProvider.notifier).add(path);
      }
      if (context.mounted) {
        _message(context, move ? 'File moved.' : 'File copied.');
      }
    } catch (_) {
      if (context.mounted) _message(context, 'Could not complete the action.');
    }
  }

  void _details(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _Detail(label: 'Size', value: _formatBytes(item.size)),
            _Detail(label: 'Location', value: item.path),
            _Detail(
              label: 'Last opened',
              value: item.openedAt.toLocal().toString(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 52,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.picture_as_pdf_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(_formatBytes(item.size)),
        onTap: () async {
          await ref.read(documentsProvider.notifier).add(item.path);
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PdfViewerScreen(path: item.path),
            ),
          );
        },
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'favorite':
                await ref
                    .read(documentsProvider.notifier)
                    .toggleFavorite(item.path);
              case 'share':
                await SharePlus.instance.share(
                  ShareParams(files: [XFile(item.path)]),
                );
              case 'rename':
                await _rename(context, ref);
              case 'copy':
                await _copyOrMove(context, ref, move: false);
              case 'move':
                await _copyOrMove(context, ref, move: true);
              case 'details':
                if (context.mounted) _details(context);
              case 'delete':
                await _delete(context, ref);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'favorite',
              child: Text(item.isFavorite ? 'Remove favorite' : 'Add favorite'),
            ),
            const PopupMenuItem(value: 'share', child: Text('Share')),
            const PopupMenuItem(value: 'rename', child: Text('Rename')),
            const PopupMenuItem(value: 'copy', child: Text('Copy')),
            const PopupMenuItem(value: 'move', child: Text('Move')),
            const PopupMenuItem(value: 'details', child: Text('Details')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.favoritesOnly});

  final bool favoritesOnly;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              favoritesOnly ? Icons.star_outline_rounded : Icons.folder_open,
              size: 70,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              favoritesOnly ? 'No favorites yet' : 'No recent PDFs',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              favoritesOnly
                  ? 'Mark important documents with a star.'
                  : 'Files you open or create will appear here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

void _message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
