import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/library_model.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const BookCompanionApp());
}

class BookCompanionApp extends StatelessWidget {
  const BookCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LibraryModel()..load(),
      child: MaterialApp(
        title: 'Book Companion',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
