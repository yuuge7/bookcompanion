import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/reading_session.dart';

class ReadEdition {
  const ReadEdition(this.format, this.totalLength);
  final BookFormat format;
  final int? totalLength;
}

String formatReadLength(BookFormat format, int? value) => value == null
    ? ''
    : format == BookFormat.audiobook
    ? '${value ~/ 60}:${(value % 60).toString().padLeft(2, '0')}'
    : '$value';

int? parseReadLength(BookFormat format, String text) {
  if (format != BookFormat.audiobook) return int.tryParse(text);
  final match = RegExp(r'^(\d+):([0-5]\d)$').firstMatch(text);
  return match == null
      ? null
      : int.parse(match[1]!) * 60 + int.parse(match[2]!);
}

class ReadFormatFields extends StatefulWidget {
  const ReadFormatFields({
    super.key,
    required this.initial,
    required this.onChanged,
    this.pageLength,
    this.audioLength,
    this.hasProgress = false,
  });
  final ReadEdition initial;
  final ValueChanged<ReadEdition> onChanged;
  final int? pageLength, audioLength;
  final bool hasProgress;
  @override
  State<ReadFormatFields> createState() => _ReadFormatFieldsState();
}

class _ReadFormatFieldsState extends State<ReadFormatFields> {
  late BookFormat _format = widget.initial.format;
  late final _length = TextEditingController(
    text: formatReadLength(_format, widget.initial.totalLength),
  );
  final _lengths = <bool, String>{};
  void _notify() => widget.onChanged(
    ReadEdition(_format, parseReadLength(_format, _length.text.trim())),
  );
  @override
  void dispose() {
    _length.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = _format == BookFormat.audiobook;
    final unitsChanged =
        audio != (widget.initial.format == BookFormat.audiobook);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<BookFormat>(
          key: const ValueKey('read-format'),
          initialValue: _format,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Format for this read'),
          items: BookFormat.values
              .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
              .toList(),
          onChanged: (f) => setState(() {
            _lengths[audio] = _length.text;
            _format = f!;
            final nextAudio = _format == BookFormat.audiobook;
            _length.text =
                _lengths[nextAudio] ??
                formatReadLength(
                  _format,
                  nextAudio ? widget.audioLength : widget.pageLength,
                );
            _notify();
          }),
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey('read-length'),
          controller: _length,
          keyboardType: audio ? TextInputType.datetime : TextInputType.number,
          decoration: InputDecoration(
            labelText: audio
                ? 'Audio duration (h:mm)'
                : 'Total pages for this read',
            helperText: 'Optional',
          ),
          onChanged: (_) => _notify(),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            final length = parseReadLength(_format, v.trim());
            if (length == null || length <= 0) {
              return audio
                  ? 'Use hours:minutes, for example 12:30.'
                  : 'Enter a positive whole number.';
            }
            return null;
          },
        ),
        if (unitsChanged && widget.hasProgress) ...[
          const SizedBox(height: 12),
          const Text(
            'Switching between pages and audio resets the progress log for this read. Earlier reads keep their progress.',
          ),
        ],
      ],
    );
  }
}

Future<ReadEdition?> showReadFormatDialog(
  BuildContext context,
  Book book, {
  ReadingSession? session,
}) {
  final initial = session == null
      ? ReadEdition(
          book.format,
          book.format == BookFormat.audiobook
              ? book.totalMinutes
              : book.totalPages,
        )
      : ReadEdition(session.format!, session.totalLength);
  var edition = initial;
  final form = GlobalKey<FormState>();
  return showDialog<ReadEdition>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      title: Text(
        session == null ? 'Choose this read’s format' : 'Edit read format',
      ),
      content: Form(
        key: form,
        child: ReadFormatFields(
          initial: initial,
          pageLength: book.totalPages,
          audioLength: book.totalMinutes,
          hasProgress:
              session != null &&
              (session.currentPage > 0 || session.progress.isNotEmpty),
          onChanged: (v) => edition = v,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) Navigator.pop(ctx, edition);
          },
          child: Text(session == null ? 'Continue' : 'Save format'),
        ),
      ],
    ),
  );
}
