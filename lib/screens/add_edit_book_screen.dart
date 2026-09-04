import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/book.dart';
import '../models/reading_session.dart';
import '../services/library_model.dart';
import '../theme/tokens.dart';
import '../widgets/ledger.dart';
import '../widgets/read_dates.dart';

class AddEditBookScreen extends StatefulWidget {
  const AddEditBookScreen({super.key, this.book});

  /// null = creating a new book.
  final Book? book;

  @override
  State<AddEditBookScreen> createState() => _AddEditBookScreenState();
}

class _AddEditBookScreenState extends State<AddEditBookScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _pagesController;
  late BookStatus _status;
  String? _coverPath;
  DateTime? _startDate;
  DateTime? _endDate;
  DatePrecision _precision = DatePrecision.exact;
  int? _rating;
  String? _coverError;

  bool get _isEditing => widget.book != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.book?.title ?? '');
    _authorController = TextEditingController(text: widget.book?.author ?? '');
    _pagesController =
        TextEditingController(text: widget.book?.totalPages?.toString() ?? '');
    _status = widget.book?.status ?? BookStatus.toRead;
    _coverPath = widget.book?.coverImagePath;
    final sessions = widget.book?.sessions ?? const <ReadingSession>[];
    final lastSession = sessions.isEmpty ? null : sessions.last;
    _startDate = lastSession?.startDate ?? DateUtils.dateOnly(DateTime.now());
    _endDate = lastSession?.endDate ?? DateUtils.dateOnly(DateTime.now());
    _precision = lastSession?.precision ?? DatePrecision.exact;
    _rating = lastSession?.rating;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _pagesController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 800);
      if (picked == null) return;
      setState(() {
        _coverPath = picked.path;
        _coverError = null;
      });
    } catch (_) {
      setState(() => _coverError =
          'Could not open your photos. Check the app has permission, then '
          'try again.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final library = context.read<LibraryModel>();
    final navigator = Navigator.of(context);
    final pagesText = _pagesController.text.trim();
    final totalPages = pagesText.isEmpty ? null : int.tryParse(pagesText);

    if (_isEditing) {
      final book = widget.book!;
      book.title = _titleController.text.trim();
      book.author = _authorController.text.trim();
      book.status = _status;
      book.coverImagePath = _coverPath;
      book.totalPages = totalPages;
      _syncSessionsWithStatus(book, totalPages);
      await library.updateBook(book);
    } else {
      final book = Book(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
        status: _status,
        coverImagePath: _coverPath,
        totalPages: totalPages,
      );
      _syncSessionsWithStatus(book, totalPages);
      await library.addBook(book);
    }
    navigator.pop();
  }

  void _syncSessionsWithStatus(Book book, int? totalPages) {
    if (_status == BookStatus.toRead) {
      book.sessions.removeWhere((s) => s.isOpen);
    } else if (_status == BookStatus.reading) {
      if (book.openSession == null) {
        book.sessions.add(ReadingSession(
          id: const Uuid().v4(),
          startDate: _startDate ?? DateUtils.dateOnly(DateTime.now()),
          precision: _precision,
        ));
      } else {
        book.openSession!
          ..startDate = _startDate ?? DateUtils.dateOnly(DateTime.now())
          ..precision = _precision;
      }
    } else if (_status == BookStatus.read) {
      final today = DateUtils.dateOnly(DateTime.now());
      // Whichever session this status lands on, it carries the dates, the
      // precision and the rating the form was showing.
      final target = book.openSession ??
          (book.sessions.isEmpty ? null : book.sessions.last);
      final session = target ??
          (ReadingSession(
            id: const Uuid().v4(),
            startDate: _startDate ?? today,
          )..currentPage = totalPages ?? 0);
      if (target == null) book.sessions.add(session);

      session
        ..startDate = _startDate ?? session.startDate
        ..endDate = _endDate ?? today
        ..precision = _precision
        ..rating = _rating;
      if (totalPages != null) session.currentPage = totalPages;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wantsStart =
        _status == BookStatus.reading || _status == BookStatus.read;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit book' : 'Add book')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.snug,
            Space.gutter,
            Space.section,
          ),
          children: [
            _CoverPicker(
              path: _coverPath,
              error: _coverError,
              onPick: _pickCover,
              onRemove: _coverPath == null
                  ? null
                  : () => setState(() => _coverPath = null),
            ),
            const SizedBox(height: Space.block),
            const SectionHeading('the book'),
            const SizedBox(height: Space.step),
            _Field(
              label: 'Title',
              controller: _titleController,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'A book needs a title to show up in your list.'
                  : null,
            ),
            const SizedBox(height: Space.step),
            _Field(
              label: 'Author',
              controller: _authorController,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: Space.step),
            _Field(
              label: 'Total pages',
              hint: 'Optional — needed to show progress',
              controller: _pagesController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                if (n == null) return 'Enter a whole number of pages.';
                if (n <= 0) return 'A book has at least one page.';
                return null;
              },
            ),
            const SizedBox(height: Space.block),
            const SectionHeading('shelf'),
            const SizedBox(height: Space.step),
            SegmentedChoice<BookStatus>(
              values: BookStatus.values,
              value: _status,
              labelOf: (s) => s.label,
              onChanged: (s) => setState(() => _status = s),
            ),
            const SizedBox(height: Space.snug),
            Text(
              _statusHelp(_status),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.inkMuted),
            ),
            if (wantsStart) ...[
              const SizedBox(height: Space.block),
              const SectionHeading('dates'),
              const SizedBox(height: Space.step),
              // A book finished years ago rarely has exact days attached to
              // it, and a guessed day is worse than saying it is not known.
              SegmentedChoice<DatePrecision>(
                values: DatePrecision.values,
                value: _precision,
                labelOf: (p) => p.label,
                onChanged: _changePrecision,
              ),
              const SizedBox(height: Space.snug),
              Text(
                _precisionHelp(_precision),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.inkMuted),
              ),
              if (_precision != DatePrecision.unknown) ...[
                const SizedBox(height: Space.step),
                _DateRow(
                  label: 'Started',
                  value: _startDate!,
                  precision: _precision,
                  onPick: () => _pickStart(context),
                ),
                if (_status == BookStatus.read) ...[
                  const SizedBox(height: Space.snug),
                  _DateRow(
                    label: 'Finished',
                    value: _endDate!,
                    precision: _precision,
                    onPick: () => _pickEnd(context),
                  ),
                ],
              ],
            ],
            if (_status == BookStatus.read) ...[
              const SizedBox(height: Space.block),
              const SectionHeading('rating'),
              const SizedBox(height: Space.tight),
              Text(
                'Optional, and it belongs to this read alone — a reread can '
                'score differently.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: Space.snug),
              StarRating(
                value: _rating,
                onChanged: (v) => setState(() => _rating = v),
              ),
            ],
            const SizedBox(height: Space.block),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? 'Save changes' : 'Add to library'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Switching precision re-snaps the dates, so an approximate read never
  /// keeps the stray day someone happened to tap.
  void _changePrecision(DatePrecision next) {
    setState(() {
      _precision = next;
      if (next == DatePrecision.approximate) {
        _startDate = snapToMonthStart(_startDate!);
        _endDate = snapToMonthEnd(_endDate!);
      }
    });
  }

  Future<void> _pickStart(BuildContext context) async {
    final approximate = _precision == DatePrecision.approximate;
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate!,
      firstDate: DateTime(1900),
      lastDate: DateUtils.dateOnly(DateTime.now()),
      helpText: approximate ? 'Started — any day that month' : 'Started on',
    );
    if (picked == null) return;
    setState(() {
      _startDate = approximate ? snapToMonthStart(picked) : picked;
      if (_endDate != null && _endDate!.isBefore(_startDate!)) {
        _endDate = approximate ? snapToMonthEnd(picked) : picked;
      }
    });
  }

  Future<void> _pickEnd(BuildContext context) async {
    final approximate = _precision == DatePrecision.approximate;
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate!.isBefore(_startDate!) ? _startDate! : _endDate!,
      firstDate: _startDate!,
      lastDate: DateUtils.dateOnly(DateTime.now()),
      helpText: approximate ? 'Finished — any day that month' : 'Finished on',
    );
    if (picked == null) return;
    setState(() => _endDate = approximate ? snapToMonthEnd(picked) : picked);
  }

  String _precisionHelp(DatePrecision precision) => switch (precision) {
        DatePrecision.exact => 'You know the days.',
        DatePrecision.approximate =>
          'Only the month is kept. Use this for a read you can place in a '
              'month or a span of months but not on a day.',
        DatePrecision.unknown =>
          'No dates are kept. The read still counts towards your totals.',
      };

  String _statusHelp(BookStatus status) => switch (status) {
        BookStatus.toRead =>
          'Waiting on the shelf. Any open read is cleared when you save.',
        BookStatus.reading =>
          'Opens a read from the date below, if one is not open already.',
        BookStatus.read =>
          'Closes the read with the dates below and counts it in your totals.',
        BookStatus.dropped =>
          'Set aside. The read stays open with no end date, so the page you '
              'stopped on is kept.',
      };
}

/// The cover, its own block with an explicit action — not a bare grey
/// rectangle you have to guess is tappable.
class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.path,
    required this.onPick,
    required this.onRemove,
    this.error,
  });

  final String? path;
  final String? error;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hasCover = path != null && File(path!).existsSync();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: hasCover ? 'Replace cover' : 'Choose a cover',
          excludeSemantics: true,
          child: InkWell(
            onTap: onPick,
            borderRadius: Radii.cover,
            child: Container(
              width: 84,
              height: 120,
              decoration: BoxDecoration(
                color: c.plate,
                borderRadius: Radii.cover,
                border: Border.all(color: c.rule),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: hasCover
                  ? Image.file(File(path!), fit: BoxFit.cover)
                  : Icon(Icons.add_photo_alternate_outlined,
                      size: 26, color: c.inkFaint),
            ),
          ),
        ),
        const SizedBox(width: Space.gutter),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Meta('cover'),
              const SizedBox(height: Space.tight),
              Text(
                hasCover
                    ? 'Stored as a link to the picked image.'
                    : 'Optional. Without one, the row shows the first letter '
                        'of the title.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: Space.step),
              Wrap(
                spacing: Space.snug,
                children: [
                  OutlinedButton(
                    onPressed: onPick,
                    child: Text(hasCover ? 'Replace' : 'Choose image'),
                  ),
                  if (onRemove != null)
                    TextButton(onPressed: onRemove, child: const Text('Remove')),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: Space.snug),
                Text(
                  error!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.danger),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Label above the field, not floating inside it: floating labels are the
/// most recognisable Material default on any form.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Meta(label.toLowerCase()),
        const SizedBox(height: Space.tight + 2),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          style: TextStyle(
            fontFamily: Faces.body,
            fontSize: 15,
            color: c.ink,
          ),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.precision,
    required this.onPick,
  });

  final String label;
  final DateTime value;
  final DatePrecision precision;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final formatted = dateAtPrecision(value, precision);

    return Semantics(
      button: true,
      label: '$label $formatted, change date',
      excludeSemantics: true,
      child: InkWell(
        onTap: onPick,
        borderRadius: Radii.field,
        child: Container(
          height: kTapTarget,
          padding: const EdgeInsets.symmetric(horizontal: Space.step),
          decoration: BoxDecoration(
            color: c.well,
            borderRadius: Radii.field,
            border: Border.all(color: c.rule),
          ),
          child: Row(
            children: [
              Meta(label.toLowerCase()),
              const SizedBox(width: Space.step),
              Expanded(child: Container(height: 1, color: c.rule)),
              const SizedBox(width: Space.step),
              Meta(
                formatted,
                color: c.ink,
                size: 13,
                weight: FontWeight.w600,
              ),
              const SizedBox(width: Space.snug),
              Icon(Icons.event_outlined, size: 16, color: c.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
