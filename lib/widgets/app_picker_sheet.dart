import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_blocker.dart';
import '../services/app_icons.dart';
import '../theme/palette.dart';
import 'pixel_icons.dart';
import 'pixel_widgets.dart';

Future<List<String>?> showAppPickerSheet(
  BuildContext context, {
  List<String> initial = const [],
}) {
  return showPixelSheet<List<String>>(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Text('SELECT APPS', style: p.h2.copyWith(color: p.text)),
                const Spacer(),
                Text(
                  '${_selected.length} SELECTED',
                  style: p.label.copyWith(color: p.accent),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: PixelTextField(
              hint: 'Search...',
              fontSize: 20,
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
                    child: Text('SCANNING...', style: p.label),
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
                  return const EmptyState(message: 'No apps found.');
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                DialogAction(
                  label: 'CLEAR',
                  onTap: () => setState(_selected.clear),
                ),
                const Spacer(),
                DialogAction(
                  label: 'CANCEL',
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                PixelButton(
                  label: 'SAVE',
                  height: 40,
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
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            AppIconImage(packageName: app.packageName, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kFontTerminal,
                      fontSize: 21,
                      height: 1.05,
                      color: selected ? p.text : p.textDim,
                    ),
                  ),
                  Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kFontTerminal,
                      fontSize: 13,
                      color: p.textGhost,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PixelIcon(
              selected ? Px.check : Px.circle,
              color: selected ? p.accent : p.textGhost,
              size: 15,
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
            color: p.panelHi,
            alignment: Alignment.center,
            child: Text(
              packageName.isNotEmpty
                  ? packageName
                        .split('.')
                        .last
                        .substring(0, 1)
                        .toUpperCase()
                  : '?',
              style: TextStyle(
                fontFamily: kFontPixel,
                fontSize: size * 0.4,
                color: p.textDim,
              ),
            ),
          );
        }
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, _, _) =>
              Container(width: size, height: size, color: p.panelHi),
        );
      },
    );
  }
}
