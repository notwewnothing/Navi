import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_blocker.dart';
import '../services/app_icons.dart';
import '../theme/palette.dart';
import 'nd_icons.dart';
import 'nd_widgets.dart';

Future<List<String>?> showAppPickerSheet(
  BuildContext context, {
  List<String> initial = const [],
}) {
  return showNdSheet<List<String>>(
    context: context,
    builder: (context) => _AppPickerSheet(initial: initial),
  );
}

class _AppPickerSheet extends StatefulWidget {
  const _AppPickerSheet({required this.initial});

  final List<String> initial;

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  late final Future<List<InstalledApp>> _apps = AppBlocker.installedApps();
  late final Set<String> _selected = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NdSheetHeader(
            title: 'Choose apps',
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: NdSpace.sm),
                child: Text(
                  '${_selected.length} selected',
                  style: p.label.copyWith(color: p.accent),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NdSpace.page,
              0,
              NdSpace.page,
              NdSpace.xs,
            ),
            child: NdTextField(
              hint: 'Search apps',
              capitalization: TextCapitalization.none,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<InstalledApp>>(
              future: _apps,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                    child: Text('Loading installed apps...', style: p.label),
                  );
                }
                final all = snapshot.data ?? const <InstalledApp>[];
                final apps = _query.isEmpty
                    ? all
                    : [
                        for (final app in all)
                          if (app.label.toLowerCase().contains(_query) ||
                              app.packageName.toLowerCase().contains(_query))
                            app,
                      ];
                if (apps.isEmpty) {
                  return const EmptyState(
                    message: 'No apps match that search.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NdSpace.page,
                    vertical: NdSpace.sm,
                  ),
                  itemCount: apps.length,
                  itemBuilder: (context, i) {
                    final app = apps[i];
                    final selected = _selected.contains(app.packageName);
                    return _AppRow(
                      app: app,
                      selected: selected,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          // Set.add returns false on duplicates, so this doubles as the toggle
                          if (!_selected.add(app.packageName)) {
                            _selected.remove(app.packageName);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NdSpace.md,
              NdSpace.sm,
              NdSpace.page,
              NdSpace.lg,
            ),
            child: Row(
              children: [
                DialogAction(
                  label: 'Clear all',
                  onTap: () => setState(_selected.clear),
                ),
                const Spacer(),
                DialogAction(
                  label: 'Cancel',
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: NdSpace.xs),
                NdButton(
                  label: 'Save',
                  height: 46,
                  filled: true,
                  onTap: () => Navigator.of(context).pop(_selected.toList()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.app,
    required this.selected,
    required this.onTap,
  });

  final InstalledApp app;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NdSpace.sm),
        child: Row(
          children: [
            AppIconImage(packageName: app.packageName, size: 34),
            const SizedBox(width: NdSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: p.row.copyWith(color: selected ? p.text : p.textDim),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: p.label.copyWith(fontSize: 11, color: p.textGhost),
                  ),
                ],
              ),
            ),
            const SizedBox(width: NdSpace.md),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? p.accent : Colors.transparent,
                border: Border.all(color: selected ? p.accent : p.borderHi),
              ),
              child: selected
                  ? Center(child: NdIcon(Nd.check, color: p.onAccent, size: 15))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class AppIconImage extends StatelessWidget {
  const AppIconImage({super.key, required this.packageName, this.size = 26});

  final String packageName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FutureBuilder<Uint8List?>(
      future: AppIcons.getIcon(packageName),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: p.panelHi,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            alignment: Alignment.center,
            child: Text(
              packageName.isNotEmpty
                  ? packageName.split('.').last.substring(0, 1).toUpperCase()
                  : '?',
              style: p.dot(size * 0.45, color: p.textDim),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.28),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) =>
                Container(width: size, height: size, color: p.panelHi),
          ),
        );
      },
    );
  }
}
