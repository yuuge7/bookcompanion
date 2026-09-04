import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/library_model.dart';
import '../theme/tokens.dart';
import 'ledger.dart';

/// The app's daily action, reachable in one tap from the list.
///
/// The page is typed, never stepped — bumping a page count one tap at a
/// time is wrong for a book you read thirty pages of in a sitting, and the
/// product decided that deliberately.
Future<void> showSetPageDialog(BuildContext context, Book book) async {
  final open = book.openSession;
  if (open == null) return;

  final library = context.read<LibraryModel>();
  final page = await showDialog<int>(
    context: context,
    builder: (_) => _SetPageDialog(book: book, current: open.currentPage),
  );
  if (page != null) {
    await library.updatePage(book, page);
  }
}

class _SetPageDialog extends StatefulWidget {
  const _SetPageDialog({required this.book, required this.current});

  final Book book;
  final int current;

  @override
  State<_SetPageDialog> createState() => _SetPageDialogState();
}

class _SetPageDialogState extends State<_SetPageDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.current}');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _total => widget.book.totalPages;

  void _submit() {
    final raw = _controller.text.trim();
    final value = int.tryParse(raw);
    if (raw.isEmpty || value == null) {
      setState(() => _error = 'Type a page number, digits only.');
      return;
    }
    if (value < 0) {
      setState(() => _error = 'Pages start at 0.');
      return;
    }
    if (_total != null && value > _total!) {
      setState(() => _error = 'This book has $_total pages.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(
        Space.block,
        Space.block,
        Space.block,
        0,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        Space.block,
        Space.step,
        Space.block,
        0,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Meta('now on p. ${widget.current}', size: 11),
          const SizedBox(height: Space.tight),
          const Text('Current page'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: TextStyle(
              fontFamily: Faces.utility,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: c.ink,
              fontFeatures: kTabular,
            ),
            decoration: InputDecoration(
              suffixText: _total != null ? 'of $_total' : null,
              suffixStyle: TextStyle(
                fontFamily: Faces.utility,
                fontSize: 13,
                color: c.inkMuted,
                fontFeatures: kTabular,
              ),
              errorText: _error,
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.step,
        Space.gutter,
        Space.gutter,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save page')),
      ],
    );
  }
}
