import 'package:flutter/material.dart';

import '../../models/journal_entry.dart';
import '../../services/journal_store.dart';
import '../../theme/palette.dart';
import '../../widgets/pixel_icons.dart';
import '../../widgets/pixel_widgets.dart';
import '../../widgets/routes.dart';
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
        child: Stack(
          children: [
            Column(
              children: [
                PixelHeader(
                  title: 'JOURNAL',
                  actions: [
                    PixelIconButton(
                      glyph: Px.calendar,
                      onTap: () => Navigator.of(context).push(
                        slideUpRoute(const JournalCalendarScreen()),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: entries.isEmpty
                      ? const EmptyState(
                          message: 'The Wired is listening.',
                          glyph: Px.book,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 104),
                          itemCount: entries.length,
                          itemBuilder: (context, i) => _Stagger(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _EntryCard(entry: entries[i]),
                            ),
                          ),
                        ),
                ),
              ],
            ),
            Positioned(
              right: 20,
              bottom: 24,
              child: PixelFab(onTap: () => showJournalEntrySheet(context)),
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
        final t = Curves.easeOutCubic
            .transform(((v * total - delay) / 320).clamp(0.0, 1.0));
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
    return PixelCard(
      onTap: () => Navigator.of(context).push(
        slideUpRoute(JournalEntryView(entry: entry)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PixelIcon(
                journalTypeGlyph(entry.type),
                color: p.accentMid,
                size: 13,
              ),
              const SizedBox(width: 9),
              Text(journalStamp(entry.at), style: p.label),
              const Spacer(),
              Text(
                entry.type.label,
                style: p.label.copyWith(color: p.textGhost),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
      SizedBox(
        height: 160,
        width: double.infinity,
        child: MediaImage(entry.mediaPath),
      ),
      ..._captionLine(p),
    ],
    JournalType.video => [
      Container(
        height: 160,
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          children: [
            Center(child: PixelIcon(Px.play, color: p.accent, size: 26)),
            if (entry.durationMs != null)
              Positioned(
                right: 8,
                bottom: 6,
                child: Text(
                  journalDuration(entry.durationMs),
                  style: TextStyle(
                    fontFamily: kFontTerminal,
                    fontSize: 17,
                    color: p.textDim,
                  ),
                ),
              ),
          ],
        ),
      ),
      ..._captionLine(p),
    ],
    JournalType.audio => [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: p.accentDim),
            ),
            child: PixelIcon(Px.mic, color: p.accent, size: 16),
          ),
          const SizedBox(width: 12),
          Text(
            journalDuration(entry.durationMs),
            style: TextStyle(
              fontFamily: kFontTerminal,
              fontSize: 26,
              color: p.text,
              height: 1,
            ),
          ),
          const SizedBox(width: 12),
          if (entry.body.isNotEmpty)
            Expanded(
              child: Text(
                entry.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: p.bodyDim.copyWith(fontSize: 18),
              ),
            ),
        ],
      ),
    ],
  };

  List<Widget> _captionLine(NaviPalette p) => entry.body.isEmpty
      ? const []
      : [
          const SizedBox(height: 8),
          Text(
            entry.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: p.bodyDim.copyWith(fontSize: 18),
          ),
        ];
}
