import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/book.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const BookCard({super.key, required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd();
    final open = book.openSession;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: SizedBox(
          width: 44,
          height: 64,
          child: book.coverImagePath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(File(book.coverImagePath!), fit: BoxFit.cover),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.menu_book),
                ),
        ),
        title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          open != null
              ? (book.totalPages != null
                  ? 'Page ${open.currentPage} of ${book.totalPages}'
                  : 'Started ${dateFmt.format(open.startDate)}')
              : book.author,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: book.isReread
            ? Chip(
                label: Text('x${book.timesRead}'),
                visualDensity: VisualDensity.compact,
              )
            : (book.averageRating != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      Text(book.averageRating!.toStringAsFixed(1)),
                    ],
                  )
                : null),
      ),
    );
  }
}
