import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/library_model.dart';
import 'services/theme_notifier.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

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
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
