import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/book.dart';
import '../models/reading_session.dart';
import '../services/library_model.dart';

class AddEditBookScreen extends StatefulWidget {
  final Book? book; // null = creating a new book
  const AddEditBookScreen({super.key, this.book});

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
    final lastSession = widget.book?.sessions.isEmpty ?? true ? null : widget.book?.sessions.last;
    _startDate = lastSession?.startDate ?? DateUtils.dateOnly(DateTime.now());
    _endDate = lastSession?.endDate ?? DateUtils.dateOnly(DateTime.now());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _pagesController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked != null) {
      setState(() => _coverPath = picked.path);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final library = context.read<LibraryModel>();
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
    if (mounted) Navigator.pop(context);
  }

  void _syncSessionsWithStatus(Book book, int? totalPages) {
    if (_status == BookStatus.toRead) {
      book.sessions.removeWhere((s) => s.isOpen);
    } else if (_status == BookStatus.reading) {
      if (book.openSession == null) {
        book.sessions.add(ReadingSession(
          id: const Uuid().v4(),
          startDate: _startDate ?? DateUtils.dateOnly(DateTime.now()),
        ));
      } else {
        book.openSession!.startDate = _startDate ?? DateUtils.dateOnly(DateTime.now());
      }
    } else if (_status == BookStatus.read) {
      final open = book.openSession;
      if (open != null) {
        open.startDate = _startDate ?? open.startDate;
        open.endDate = _endDate ?? DateUtils.dateOnly(DateTime.now());
        if (totalPages != null) open.currentPage = totalPages;
      } else if (book.sessions.isEmpty) {
        book.sessions.add(ReadingSession(
          id: const Uuid().v4(),
          startDate: _startDate ?? DateUtils.dateOnly(DateTime.now()),
        )..endDate = _endDate ?? DateUtils.dateOnly(DateTime.now())
         ..currentPage = totalPages ?? 0);
      } else {
        final last = book.sessions.last;
        last.startDate = _startDate ?? last.startDate;
        last.endDate = _endDate ?? DateUtils.dateOnly(DateTime.now());
        if (totalPages != null) last.currentPage = totalPages;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit book' : 'Add book')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickCover,
                child: Container(
                  width: 100,
                  height: 144,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _coverPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(_coverPath!), fit: BoxFit.cover),
                        )
                      : const Icon(Icons.add_photo_alternate, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _authorController,
              decoration: const InputDecoration(labelText: 'Author'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pagesController,
              decoration: const InputDecoration(
                labelText: 'Total pages (optional)',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                return int.tryParse(v.trim()) == null ? 'Enter a whole number' : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<BookStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: BookStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            if (_status == BookStatus.reading || _status == BookStatus.read)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Date'),
                subtitle: Text(DateFormat.yMMMd().format(_startDate!)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate!,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
            if (_status == BookStatus.read)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Date'),
                subtitle: Text(DateFormat.yMMMd().format(_endDate!)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate!,
                    firstDate: _startDate!,
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _endDate = picked);
                },
              ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
