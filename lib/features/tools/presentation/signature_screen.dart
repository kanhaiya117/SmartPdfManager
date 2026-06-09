import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';

import '../../../core/providers/app_providers.dart';
import 'widgets/tool_scaffold.dart';

class SignatureScreen extends ConsumerStatefulWidget {
  const SignatureScreen({super.key});

  @override
  ConsumerState<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends ConsumerState<SignatureScreen> {
  final _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );
  final _page = TextEditingController(text: '1');
  String? _pdfPath;
  final List<String> _savedSignatures = [];
  Uint8List? _selectedSignature;
  var _x = 55.0;
  var _y = 650.0;
  var _width = 150.0;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSignatures();
  }

  @override
  void dispose() {
    _controller.dispose();
    _page.dispose();
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

  Future<void> _saveDrawing() async {
    final bytes = await _controller.toPngBytes();
    if (bytes == null || bytes.isEmpty) return;
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
      _selectedSignature = bytes;
    });
    _controller.clear();
  }

  Future<void> _sign() async {
    if (_pdfPath == null || _selectedSignature == null) return;
    setState(() => _busy = true);
    try {
      final output = await ref
          .read(pdfServiceProvider)
          .addSignature(
            path: _pdfPath!,
            signature: _selectedSignature!,
            pageNumber: int.tryParse(_page.text) ?? 0,
            x: _x,
            y: _y,
            width: _width,
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
      title: 'Sign PDF',
      subtitle: 'Draw, save and place reusable signatures on a PDF.',
      icon: Icons.draw_rounded,
      child: Column(
        children: [
          SelectedFileCard(
            path: _pdfPath,
            onChoose: () async {
              final path = await ref.read(fileServiceProvider).pickPdf();
              if (path != null) setState(() => _pdfPath = path);
            },
          ),
          const SizedBox(height: 14),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SizedBox(
                  height: 190,
                  child: Signature(
                    controller: _controller,
                    backgroundColor: Colors.white,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _controller.clear,
                          icon: const Icon(Icons.clear_rounded),
                          label: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saveDrawing,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Save signature'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_savedSignatures.isNotEmpty) ...[
            const SizedBox(height: 12),
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
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final bytes = await File(path).readAsBytes();
                      setState(() => _selectedSignature = bytes);
                    },
                    child: Container(
                      width: 155,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          width: 2,
                          color: _selectedSignature == null
                              ? Colors.transparent
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Image.file(File(path), fit: BoxFit.contain),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _page,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Page number'),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _PositionSlider(
                    label: 'Horizontal',
                    value: _x,
                    max: 500,
                    onChanged: (value) => setState(() => _x = value),
                  ),
                  _PositionSlider(
                    label: 'Vertical',
                    value: _y,
                    max: 750,
                    onChanged: (value) => setState(() => _y = value),
                  ),
                  _PositionSlider(
                    label: 'Width',
                    value: _width,
                    min: 60,
                    max: 360,
                    onChanged: (value) => setState(() => _width = value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _pdfPath == null || _selectedSignature == null || _busy
                ? null
                : _sign,
            icon: const Icon(Icons.verified_rounded),
            label: const Text('Apply signature and save'),
          ),
        ],
      ),
    );
  }
}

class _PositionSlider extends StatelessWidget {
  const _PositionSlider({
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
        SizedBox(width: 78, child: Text(label)),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(width: 40, child: Text('${value.round()}')),
      ],
    );
  }
}
