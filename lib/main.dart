import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/library_model.dart';
import 'services/theme_notifier.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const BookCompanionApp());
}

class BookCompanionApp extends StatelessWidget {
  const BookCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryModel()..load()),
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, _) => MaterialApp(
          title: 'Book Companion',
          debugShowCheckedModeBanner: false,
          themeMode: themeNotifier.mode,
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
      ),
    );
  }
}
