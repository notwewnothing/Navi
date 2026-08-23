import 'package:flutter/material.dart';

import '../../models/journal_entry.dart';
import '../../services/journal_store.dart';
import '../../theme/palette.dart';
import '../../widgets/nd_icons.dart';
import '../../widgets/nd_widgets.dart';
import '../../widgets/routes.dart';
import '../shell.dart';
import 'journal_calendar_screen.dart';
import 'journal_entry_editor.dart';
import 'journal_entry_view.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final journal = JournalScope.of(context);
    final entries = journal.entries;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NdHeader(
              title: 'Journal',
              subtitle: entries.isEmpty
                  ? null
                  : entries.length == 1
                  ? '1 entry'
                  : '${entries.length} entries',
              actions: [
                NdIconButton(
                  glyph: Nd.calendar,
                  tooltip: 'Calendar view',
                  onTap: () => Navigator.of(
                    context,
                  ).push(slideUpRoute(const JournalCalendarScreen())),
                ),
              ],
            ),
            Expanded(
              child: entries.isEmpty
                  ? EmptyState(
                      message:
                          'Nothing written yet.\nText, photo, video or voice — all work.',
                      glyph: Nd.book,
                      actionLabel: 'New entry',
                      onAction: () => showJournalEntrySheet(context),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        NdSpace.page,
                        NdSpace.xs,
                        NdSpace.page,
                        kNavContentInset,
                      ),
                      itemCount: entries.length,
                      itemBuilder: (context, i) => _Stagger(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: NdSpace.md),
                          child: _EntryCard(entry: entries[i]),
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

class _Stagger extends StatelessWidget {
  const _Stagger({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = 80.0 * (index > 8 ? 8 : index);
    final total = delay + 320;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total.round()),
      builder: (context, v, child) {
        final t = Curves.easeOutCubic.transform(
          ((v * total - delay) / 320).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return NdCard(
      onTap: () => Navigator.of(
        context,
      ).push(slideUpRoute(JournalEntryView(entry: entry))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NdIcon(journalTypeGlyph(entry.type), color: p.accent, size: 16),
              const SizedBox(width: NdSpace.sm),
              Text(journalStamp(entry.at), style: p.label),
              const Spacer(),
              Text(
                entry.type.label,
                style: p.micro.copyWith(color: p.textGhost),
              ),
            ],
          ),
          const SizedBox(height: NdSpace.md),
          ..._preview(p),
        ],
      ),
    );
  }

  List<Widget> _preview(NaviPalette p) => switch (entry.type) {
    JournalType.text => [
      Text(
        entry.body,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: p.body,
      ),
    ],
    JournalType.photo => [
      ClipRRect(
        borderRadius: BorderRadius.circular(NdRadius.inner),
        child: SizedBox(
          height: 170,
          width: double.infinity,
          child: MediaImage(entry.mediaPath),
        ),
      ),
      ..._captionLine(p),
    ],
    JournalType.video => [
      ClipRRect(
        borderRadius: BorderRadius.circular(NdRadius.inner),
        child: Container(
          height: 170,
          width: double.infinity,
          color: p.panelHi,
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: p.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: NdIcon(Nd.play, color: p.onAccent, size: 24),
                  ),
                ),
              ),
              if (entry.durationMs != null)
                Positioned(
                  right: NdSpace.md,
                  bottom: NdSpace.sm,
                  child: Text(
                    journalDuration(entry.durationMs),
                    style: p.micro.copyWith(color: p.text),
                  ),
                ),
            ],
          ),
        ),
      ),
      ..._captionLine(p),
    ],
    JournalType.audio => [
      Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.panelHi,
              border: Border.all(color: p.border),
            ),
            child: Center(child: NdIcon(Nd.mic, color: p.accent, size: 18)),
          ),
          const SizedBox(width: NdSpace.md),
          Text(
            journalDuration(entry.durationMs),
            style: p.dot(22, color: p.text),
          ),
          const SizedBox(width: NdSpace.md),
          if (entry.body.isNotEmpty)
            Expanded(
              child: Text(
                entry.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: p.bodyDim,
              ),
            ),
        ],
      ),
    ],
  };

  List<Widget> _captionLine(NaviPalette p) => entry.body.isEmpty
      ? const []
      : [
          const SizedBox(height: NdSpace.md),
          Text(
            entry.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: p.bodyDim,
          ),
        ];
}
