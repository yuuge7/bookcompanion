import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../services/library_model.dart';
import '../services/reading_stats.dart';
import '../services/theme_notifier.dart';
import '../theme/tokens.dart';
import '../widgets/ledger.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int? _year = DateTime.now().year;
  Future<void> _goal(ThemeNotifier prefs) async {
    final target = TextEditingController(text: '${prefs.goalTarget}');
    final year = TextEditingController(text: '${prefs.goalYear}');
    var unit = prefs.goalUnit;
    final form = GlobalKey<FormState>();
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Yearly reading goal'),
          scrollable: true,
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: year,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Year'),
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ||
                          int.parse(v!) < 1900 ||
                          int.parse(v) > 9999
                      ? 'Enter a year from 1900 to 9999.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: unit,
                  decoration: const InputDecoration(labelText: 'Count'),
                  items: const [
                    DropdownMenuItem(
                      value: 'books',
                      child: Text('Completed reads'),
                    ),
                    DropdownMenuItem(value: 'pages', child: Text('Pages')),
                  ],
                  onChanged: (v) => update(() => unit = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: target,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target'),
                  validator: (v) =>
                      int.tryParse(v ?? '') == null || int.parse(v!) <= 0
                      ? 'Use a positive whole number.'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Save goal'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      await prefs.update({
        'goalYear': int.parse(year.text),
        'goalTarget': int.parse(target.text),
        'goalUnit': unit,
      });
    }
    target.dispose();
    year.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>(),
        prefs = context.watch<ThemeNotifier>();
    final stats = ReadingStats(library.books, year: _year);
    final years = {
      DateTime.now().year,
      prefs.goalYear,
      ...library.books
          .expand((b) => b.sessions)
          .where((s) => s.endDate != null && s.precision.name != 'unknown')
          .map((s) => s.endDate!.year),
      ...library.books
          .expand((b) => b.sessions)
          .expand((s) => s.progress)
          .map((p) => p.date.year),
    }.toList()..sort((a, b) => b.compareTo(a));
    final goal = ReadingStats(library.books, year: prefs.goalYear);
    final done = prefs.goalUnit == 'pages' ? goal.pages : goal.completedReads;
    final start = DateTime(prefs.goalYear), end = DateTime(prefs.goalYear + 1);
    final now = DateTime.now();
    final fraction =
        (calendarDaysBetween(now, start) / calendarDaysBetween(end, start))
            .clamp(0.0, 1.0);
    final expected = (prefs.goalTarget * fraction).ceil();
    final status = done >= prefs.goalTarget
        ? 'Goal reached'
        : now.isBefore(start)
        ? 'Starts January 1'
        : done >= expected
        ? 'On track'
        : '${expected - done} behind pace';
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<int>(
            isExpanded: true,
            key: ValueKey('stats-year-$_year'),
            initialValue: _year,
            decoration: const InputDecoration(labelText: 'Period'),
            items: [
              const DropdownMenuItem<int>(value: null, child: Text('All time')),
              ...years.map(
                (y) => DropdownMenuItem(value: y, child: Text('$y')),
              ),
            ],
            onChanged: (y) => setState(() => _year = y),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _figure(context, '${stats.booksRead}', 'books read'),
              _figure(context, '${stats.pages}', 'pages read'),
              _figure(context, '${stats.completedReads}', 'completed reads'),
              _figure(context, '${stats.rereads}', 'rereads'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Average rating: ${stats.averageRating?.toStringAsFixed(2) ?? 'unrated'} · Listening: ${stats.minutes ~/ 60}h ${stats.minutes % 60}m',
          ),
          if (_year != null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Unknown dates count in All time. Historic reads without logs add pages to their known finish month. Daily activity uses recorded progress only.',
              ),
            ),
          const SizedBox(height: 24),
          SectionHeading(
            '${prefs.goalYear} reading goal',
            trailing: TextButton(
              onPressed: () => _goal(prefs),
              child: const Text('Edit goal'),
            ),
          ),
          Text(
            '$done / ${prefs.goalTarget} ${prefs.goalUnit == 'books' ? 'reads' : 'pages'} · $status',
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: (done / prefs.goalTarget).clamp(0, 1)),
          const SizedBox(height: 24),
          const SectionHeading('reading rhythm'),
          const SizedBox(height: 12),
          Text(
            '${stats.currentStreak} day current streak · ${stats.longestStreak} day best streak',
          ),
          Text(
            '${stats.pagesPerActiveDay.toStringAsFixed(1)} pages / active day · ${stats.activeDays.length} active days',
          ),
          const SizedBox(height: 24),
          const SectionHeading('books by month'),
          _Bars(
            values: {
              for (var i = 0; i < 12; i++) _months[i]: stats.booksByMonth[i],
            },
          ),
          const SizedBox(height: 20),
          const SectionHeading('pages by month'),
          _Bars(
            values: {
              for (var i = 0; i < 12; i++) _months[i]: stats.pagesByMonth[i],
            },
          ),
          const SizedBox(height: 20),
          const SectionHeading('rating distribution'),
          _Bars(
            values: {
              for (var i = 0; i < 5; i++) '${i + 1} stars': stats.ratings[i],
            },
          ),
          const SizedBox(height: 20),
          const SectionHeading('top authors'),
          _Bars(values: _top(stats.authors)),
          const SizedBox(height: 20),
          const SectionHeading('top tags'),
          _Bars(values: _top(stats.tags)),
          const SizedBox(height: 20),
          const SectionHeading('format split'),
          _Bars(values: stats.formats),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    YearReviewScreen(year: _year ?? DateTime.now().year),
              ),
            ),
            child: const Text('Year in Review'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
Map<String, int> _top(Map<String, int> values) {
  final entries = values.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(entries.take(5));
}

Widget _figure(BuildContext context, String value, String label) => SizedBox(
  width: 140,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: Theme.of(context).textTheme.displaySmall),
      Meta(label),
    ],
  ),
);

class _Bars extends StatelessWidget {
  const _Bars({required this.values});
  final Map<String, int> values;
  @override
  Widget build(BuildContext context) {
    final maximum = values.values.fold(1, (a, b) => a > b ? a : b);
    if (values.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No entries for this period yet.'),
      );
    }
    return Column(
      children: values.entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Semantics(
                label: '${e.key}: ${e.value}',
                excludeSemantics: true,
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        e.key,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: e.value / maximum,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 48,
                      child: Text('${e.value}', textAlign: TextAlign.end),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class YearReviewScreen extends StatefulWidget {
  const YearReviewScreen({super.key, required this.year});
  final int year;
  @override
  State<YearReviewScreen> createState() => _YearReviewScreenState();
}

class _YearReviewScreenState extends State<YearReviewScreen> {
  final _boundary = GlobalKey();
  bool _busy = false;
  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final capture =
          await (_boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 3);
      final bytes = await capture.toByteData(format: ui.ImageByteFormat.png);
      capture.dispose();
      if (!mounted) return;
      await context.read<LibraryModel>().storage.saveExport(
        'reading-${widget.year}.png',
        bytes!.buffer.asUint8List(),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not export image. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ReadingStats(
      context.watch<LibraryModel>().books,
      year: widget.year,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Year in Review')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          RepaintBoundary(
            key: _boundary,
            child: ColoredBox(
              color: context.c.ground,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Meta('BOOK COMPANION'),
                    const SizedBox(height: 24),
                    Text(
                      '${widget.year}',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    Text(
                      'A year in books',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 32),
                    _figure(context, '${stats.booksRead}', 'books read'),
                    const SizedBox(height: 20),
                    _figure(context, '${stats.pages}', 'pages read'),
                    const SizedBox(height: 24),
                    Text(
                      '${stats.completedReads} completed reads · ${stats.rereads} rereads',
                    ),
                    Text(
                      '${stats.longestStreak} day longest streak · ${stats.activeDays.length} active days',
                    ),
                    Text(
                      'Average rating ${stats.averageRating?.toStringAsFixed(1) ?? 'unrated'}',
                    ),
                    const SizedBox(height: 24),
                    const SectionHeading('authors of my year'),
                    _Bars(values: _top(stats.authors)),
                    const SizedBox(height: 20),
                    const SectionHeading('my genres'),
                    _Bars(values: _top(stats.tags)),
                    const SizedBox(height: 28),
                    const Text('Read. Remember. Repeat.'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _export,
            child: Text(_busy ? 'Making image…' : 'Export image'),
          ),
        ],
      ),
    );
  }
}
