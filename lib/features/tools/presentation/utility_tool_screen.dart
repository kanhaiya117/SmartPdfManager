import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/services/pdf_service.dart';
import '../../dashboard/domain/dashboard_tool.dart';
import 'widgets/tool_scaffold.dart';

class UtilityToolScreen extends ConsumerStatefulWidget {
  const UtilityToolScreen({required this.tool, super.key});

  final DashboardTool tool;

  @override
  ConsumerState<UtilityToolScreen> createState() => _UtilityToolScreenState();
}

class _UtilityToolScreenState extends ConsumerState<UtilityToolScreen> {
  String? _path;
  final List<String> _paths = [];
  final _text = TextEditingController();
  final _password = TextEditingController();
  final _from = TextEditingController(text: '1');
  final _to = TextEditingController(text: '1');
  final _page = TextEditingController(text: '1');
  var _busy = false;
  var _compression = PdfCompressionMode.medium;
  var _removePassword = false;
  var _opacity = 0.2;
  var _x = 50.0;
  var _y = 80.0;
  var _fontSize = 18.0;
  int? _pageCount;

  @override
  void dispose() {
    _text.dispose();
    _password.dispose();
    _from.dispose();
    _to.dispose();
    _page.dispose();
    super.dispose();
  }

  Future<void> _pickSingle() async {
    final path = await ref.read(fileServiceProvider).pickPdf();
    if (path == null) return;
    setState(() {
      _path = path;
      _pageCount = null;
    });
    if (widget.tool == DashboardTool.split ||
        widget.tool == DashboardTool.edit) {
      try {
        final count = await ref.read(pdfServiceProvider).pageCount(path);
        if (mounted) {
          setState(() {
            _pageCount = count;
            _to.text = '$count';
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _pickMultiple() async {
    final paths = await ref.read(fileServiceProvider).pickPdfs();
    if (paths.isNotEmpty) setState(() => _paths.addAll(paths));
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      final service = ref.read(pdfServiceProvider);
      final output = switch (widget.tool) {
        DashboardTool.merge => await service.merge(_paths),
        DashboardTool.split => await service.split(
          _path!,
          from: int.tryParse(_from.text) ?? 0,
          to: int.tryParse(_to.text) ?? 0,
        ),
        DashboardTool.compress => await service.compress(_path!, _compression),
        DashboardTool.security =>
          _removePassword
              ? await service.removePassword(_path!, _password.text)
              : await service.protect(_path!, _password.text),
        DashboardTool.watermark => await service.watermark(
          path: _path!,
          text: _text.text,
          opacity: _opacity,
        ),
        DashboardTool.edit => await service.addText(
          path: _path!,
          text: _text.text,
          pageNumber: int.tryParse(_page.text) ?? 0,
          x: _x,
          y: _y,
          fontSize: _fontSize,
        ),
        _ => throw UnsupportedError('Unsupported utility'),
      };
      await ref.read(documentsProvider.notifier).add(output);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF saved successfully.')),
        );
        await OpenFilex.open(output);
      }
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

  bool get _canRun {
    if (_busy) return false;
    if (widget.tool == DashboardTool.merge) return _paths.length >= 2;
    if (_path == null) return false;
    if (widget.tool == DashboardTool.security) {
      return _password.text.isNotEmpty;
    }
    if (widget.tool == DashboardTool.watermark ||
        widget.tool == DashboardTool.edit) {
      return _text.text.trim().isNotEmpty;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: widget.tool.title,
      subtitle: _description(widget.tool),
      icon: widget.tool.icon,
      child: Column(
        children: [
          if (widget.tool == DashboardTool.merge)
            _MergePicker(
              paths: _paths,
              onPick: _pickMultiple,
              onChanged: () => setState(() {}),
            )
          else
            SelectedFileCard(path: _path, onChoose: _pickSingle),
          const SizedBox(height: 14),
          ..._options(context),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _canRun ? _run : null,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(widget.tool.icon),
            label: Text(_buttonLabel(widget.tool)),
          ),
        ],
      ),
    );
  }

  List<Widget> _options(BuildContext context) {
    switch (widget.tool) {
      case DashboardTool.split:
        return [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _from,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'From page'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _to,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'To page',
                        helperText: _pageCount == null
                            ? null
                            : 'Total: $_pageCount',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      case DashboardTool.compress:
        return [
          Card(
            child: RadioGroup<PdfCompressionMode>(
              groupValue: _compression,
              onChanged: (value) {
                if (value != null) setState(() => _compression = value);
              },
              child: const Column(
                children: [
                  RadioListTile(
                    value: PdfCompressionMode.low,
                    title: Text('Low'),
                    subtitle: Text('Fastest, modest size reduction'),
                  ),
                  RadioListTile(
                    value: PdfCompressionMode.medium,
                    title: Text('Medium'),
                    subtitle: Text('Balanced speed and size'),
                  ),
                  RadioListTile(
                    value: PdfCompressionMode.high,
                    title: Text('High'),
                    subtitle: Text('Smallest output, slower processing'),
                  ),
                ],
              ),
            ),
          ),
        ];
      case DashboardTool.security:
        return [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.lock_rounded),
                label: Text('Add password'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.lock_open_rounded),
                label: Text('Remove'),
              ),
            ],
            selected: {_removePassword},
            onSelectionChanged: (value) {
              setState(() => _removePassword = value.first);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _removePassword ? 'Current password' : 'New password',
              prefixIcon: const Icon(Icons.password_rounded),
            ),
          ),
        ];
      case DashboardTool.watermark:
        return [
          TextField(
            controller: _text,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Watermark text',
              prefixIcon: Icon(Icons.text_fields_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Text('Opacity'),
                  Expanded(
                    child: Slider(
                      value: _opacity,
                      min: 0.08,
                      max: 0.6,
                      onChanged: (value) => setState(() => _opacity = value),
                    ),
                  ),
                  Text('${(_opacity * 100).round()}%'),
                ],
              ),
            ),
          ),
        ];
      case DashboardTool.edit:
        return [
          TextField(
            controller: _text,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Text to add',
              prefixIcon: Icon(Icons.edit_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _page,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Page number',
              helperText: _pageCount == null ? null : 'Total: $_pageCount',
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _SliderRow(
                    label: 'Horizontal',
                    value: _x,
                    max: 500,
                    onChanged: (value) => setState(() => _x = value),
                  ),
                  _SliderRow(
                    label: 'Vertical',
                    value: _y,
                    max: 750,
                    onChanged: (value) => setState(() => _y = value),
                  ),
                  _SliderRow(
                    label: 'Font size',
                    value: _fontSize,
                    min: 8,
                    max: 48,
                    onChanged: (value) => setState(() => _fontSize = value),
                  ),
                ],
              ),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.tips_and_updates_outlined),
              title: Text('Markup tools'),
              subtitle: Text(
                'Open the PDF Reader to highlight, underline, strike through or add notes, then use Save copy.',
              ),
            ),
          ),
        ];
      default:
        return const [];
    }
  }
}

class _MergePicker extends StatelessWidget {
  const _MergePicker({
    required this.paths,
    required this.onPick,
    required this.onChanged,
  });

  final List<String> paths;
  final VoidCallback onPick;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.playlist_add_rounded),
          label: const Text('Select PDF files'),
        ),
        if (paths.isNotEmpty)
          SizedBox(
            height: 300,
            child: ReorderableListView.builder(
              itemCount: paths.length,
              onReorderItem: (oldIndex, newIndex) {
                final item = paths.removeAt(oldIndex);
                paths.insert(newIndex, item);
                onChanged();
              },
              itemBuilder: (context, index) => Card(
                key: ValueKey(paths[index]),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(
                    paths[index].split(RegExp(r'[/\\]')).last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    onPressed: () {
                      paths.removeAt(index);
                      onChanged();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    this.min = 0,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 82, child: Text(label)),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(width: 36, child: Text('${value.round()}')),
      ],
    );
  }
}

String _description(DashboardTool tool) => switch (tool) {
  DashboardTool.merge => 'Combine PDFs in your preferred order.',
  DashboardTool.split => 'Extract a selected range into a new PDF.',
  DashboardTool.compress => 'Optimize PDF streams for a smaller file.',
  DashboardTool.security =>
    'Protect a PDF with AES-256 or remove a known password.',
  DashboardTool.watermark => 'Apply a centered text watermark to every page.',
  DashboardTool.edit =>
    'Place text precisely on a PDF and save a separate copy.',
  _ => tool.subtitle,
};

String _buttonLabel(DashboardTool tool) => switch (tool) {
  DashboardTool.merge => 'Merge PDFs',
  DashboardTool.split => 'Extract pages',
  DashboardTool.compress => 'Compress PDF',
  DashboardTool.security => 'Save protected copy',
  DashboardTool.watermark => 'Add watermark',
  DashboardTool.edit => 'Add text and save',
  _ => 'Continue',
};
