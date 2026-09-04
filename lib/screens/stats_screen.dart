import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/library_model.dart';
import '../theme/tokens.dart';
import '../widgets/ledger.dart';

/// The totals, read as a ledger: labels on the left, figures on the right,
/// a rule running between them so the eye lands on the right column. Two
/// figures get to be large — the ones a reader actually quotes.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    final n = NumberFormat.decimalPattern();
    final avg = library.averageRating;

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: library.books.isEmpty
          ? const EmptyState(
              headline: 'Nothing to count yet',
              body: 'Totals appear once your library has a book in it. '
                  'Pages, reads and rereads are all recalculated from your '
                  'sessions, so they stay right when you delete something.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.gutter,
                Space.gutter,
                Space.section,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Figure(
                        value: n.format(library.totalBooksRead),
                        label: 'books read',
                      ),
                    ),
                    const SizedBox(width: Space.step),
                    Expanded(
                      child: _Figure(
                        value: n.format(library.totalPagesRead),
                        label: 'pages read',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.block),
                const SectionHeading('reads'),
                _Line(
                  label: 'Completed reads',
                  value: n.format(library.totalSessionsCompleted),
                ),
                _Line(label: 'Rereads', value: n.format(library.totalRereads)),
                _Line(
                  label: 'Average rating',
                  value: avg == null ? 'not rated' : avg.toStringAsFixed(2),
                ),
                const SizedBox(height: Space.block),
                const SectionHeading('shelf'),
                _Line(
                  label: 'Currently reading',
                  value: n.format(library.reading.length),
                ),
                _Line(label: 'To read', value: n.format(library.toRead.length)),
                _Line(label: 'Dropped', value: n.format(library.dropped.length)),
                _Line(
                  label: 'Books in library',
                  value: n.format(library.books.length),
                ),
              ],
            ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Panel(
      padding: const EdgeInsets.all(Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: Faces.display,
                fontSize: 40,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: -1,
                color: c.ink,
                fontFeatures: kTabular,
              ),
            ),
          ),
          const SizedBox(height: Space.snug),
          Meta(label, size: 11),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        alignment: Alignment.center,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: Space.step),
            Expanded(child: Container(height: 1, color: c.rule)),
            const SizedBox(width: Space.step),
            // A fixed figure column, right-aligned: letting the value float
            // after the leader put every number at a different x.
            SizedBox(
              width: 76,
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Faces.utility,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                  fontFeatures: kTabular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
