import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_model.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();

    final stats = <(String, String)>[
      ('Books read', '${library.totalBooksRead}'),
      ('Total completed reads', '${library.totalSessionsCompleted}'),
      ('Rereads', '${library.totalRereads}'),
      (
        'Average rating',
        library.averageRating != null ? library.averageRating!.toStringAsFixed(2) : '—'
      ),
      ('Currently reading', '${library.reading.length}'),
      ('To read', '${library.toRead.length}'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: stats.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final (label, value) = stats[i];
          return ListTile(
            title: Text(label),
            trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
          );
        },
      ),
    );
  }
}
