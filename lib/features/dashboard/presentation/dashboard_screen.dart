import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/banner_ad_card.dart';
import '../../files/presentation/documents_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../tools/presentation/tool_router.dart';
import '../../viewer/presentation/pdf_viewer_screen.dart';
import '../domain/dashboard_tool.dart';
import 'widgets/tool_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(interstitialAdServiceProvider).preload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _HomeTab(),
      const DocumentsScreen(),
      const DocumentsScreen(favoritesOnly: true),
      const SettingsScreen(),
    ];
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: IndexedStack(index: _selectedIndex, children: pages),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (value) {
            setState(() => _selectedIndex = value);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder_rounded),
              label: 'Files',
            ),
            NavigationDestination(
              icon: Icon(Icons.star_outline_rounded),
              selectedIcon: Icon(Icons.star_rounded),
              label: 'Favorites',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  static const _colors = [
    AppColors.primary,
    Color(0xFF0891B2),
    Color(0xFFF97360),
    Color(0xFF7C3AED),
    Color(0xFF0284C7),
    Color(0xFF16A34A),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFF475569),
    Color(0xFF0D9488),
    Color(0xFF6366F1),
    Color(0xFFB45309),
    Color(0xFF2563EB),
  ];

  Future<void> _openReader(BuildContext context, WidgetRef ref) async {
    final path = await ref.read(fileServiceProvider).pickPdf();
    if (path == null || !context.mounted) return;
    await ref.read(documentsProvider.notifier).add(path);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PdfViewerScreen(path: path)),
    );
  }

  Future<void> _openTool(
    BuildContext context,
    WidgetRef ref,
    DashboardTool tool,
  ) async {
    if (tool == DashboardTool.reader) {
      return _openReader(context, ref);
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ToolRouter(tool: tool)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(documentsProvider).take(5).toList();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    image: const DecorationImage(
                      image: AssetImage('assets/branding/app_icon.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart PDF Manager',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Your private offline document workspace',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => _openReader(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Open PDF',
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          sliver: SliverToBoxAdapter(
            child: _HeroCard(onOpen: () => _openReader(context, ref)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          sliver: SliverToBoxAdapter(
            child: Text(
              'PDF tools',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;
              final columns = width >= 850 ? 4 : (width >= 560 ? 3 : 2);
              return SliverGrid.builder(
                itemCount: DashboardTool.values.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: columns == 2 ? 1.1 : 1.2,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemBuilder: (context, index) => ToolCard(
                  tool: DashboardTool.values[index],
                  color: _colors[index],
                  onTap: () =>
                      _openTool(context, ref, DashboardTool.values[index]),
                ),
              );
            },
          ),
        ),
        if (recents.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Recent files',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: recents.length,
            itemBuilder: (context, index) {
              final item = recents[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 22),
                leading: const CircleAvatar(
                  child: Icon(Icons.picture_as_pdf_rounded),
                ),
                title: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(_formatBytes(item.size)),
                trailing: IconButton(
                  icon: Icon(
                    item.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                  ),
                  onPressed: () => ref
                      .read(documentsProvider.notifier)
                      .toggleFavorite(item.path),
                ),
                onTap: () async {
                  await ref.read(documentsProvider.notifier).add(item.path);
                  if (!context.mounted) return;
                  unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PdfViewerScreen(path: item.path),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
        const SliverPadding(
          padding: EdgeInsets.symmetric(vertical: 18),
          sliver: SliverToBoxAdapter(child: BannerAdCard()),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4338CA), Color(0xFF2563EB), Color(0xFF0891B2)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Work smarter with every PDF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Read, create, sign and organize documents privately.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF3730A3),
                  ),
                  onPressed: onOpen,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Open PDF'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Icon(
            Icons.auto_stories_rounded,
            size: 86,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
