import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/book.dart';
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
      _snapPagesToStatus(book, totalPages);
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
      _snapPagesToStatus(book, totalPages);
      await library.addBook(book);
    }
    if (mounted) Navigator.pop(context);
  }

  /// Setting status to "To Read" zeroes out progress; setting it to "Read"
  /// snaps progress to the last page. Only touches a session if one exists
  /// to act on (the open one, or — for a manual "Read" override — the most
  /// recent one).
  void _snapPagesToStatus(Book book, int? totalPages) {
    if (_status == BookStatus.toRead) {
      final open = book.openSession;
      if (open != null) open.currentPage = 0;
    } else if (_status == BookStatus.read && totalPages != null) {
      final target = book.openSession ?? (book.sessions.isEmpty ? null : book.sessions.last);
      if (target != null) target.currentPage = totalPages;
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
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
