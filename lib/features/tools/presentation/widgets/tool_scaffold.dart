import 'package:flutter/material.dart';

import '../../../../core/widgets/app_background.dart';

class ToolScaffold extends StatelessWidget {
  const ToolScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.tertiary,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 46, color: Colors.white),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class SelectedFileCard extends StatelessWidget {
  const SelectedFileCard({
    required this.path,
    required this.onChoose,
    this.label = 'Select PDF',
    super.key,
  });

  final String? path;
  final VoidCallback onChoose;
  final String label;

  @override
  Widget build(BuildContext context) {
    final name = path?.split(RegExp(r'[/\\]')).last;
    return Card(
      child: ListTile(
        leading: Icon(
          path == null ? Icons.upload_file_rounded : Icons.check_circle_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(name ?? label),
        subtitle: path == null
            ? const Text('Choose a file from device storage')
            : Text(path!, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onChoose,
      ),
    );
  }
}
