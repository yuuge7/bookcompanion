import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/book_detail_screen.dart';
import 'screens/home_screen.dart';
import 'services/library_model.dart';
import 'services/theme_notifier.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const BookCompanionApp());
}

class BookCompanionApp extends StatelessWidget {
  const BookCompanionApp({super.key, this.library, this.settings});
  final LibraryModel? library;
  final ThemeNotifier? settings;
  static final navigator = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) {
          final model = library ?? LibraryModel();
          if (library == null) unawaited(model.load());
          return model;
        },
      ),
      ChangeNotifierProvider(
        create: (_) {
          final model = settings ?? ThemeNotifier();
          if (settings == null) unawaited(model.load());
          return model;
        },
      ),
    ],
    child: Consumer<ThemeNotifier>(
      builder: (context, preferences, _) => DynamicColorBuilder(
        builder: (light, dark) {
          ThemeData theme(bool isDark) {
            final base = isDark ? AppTheme.dark() : AppTheme.light();
            final colors = isDark ? dark : light;
            return preferences.dynamicColor && colors != null
                ? AppTheme.fromScheme(colors)
                : base;
          }

          return MaterialApp(
            navigatorKey: navigator,
            title: 'Book Companion',
            debugShowCheckedModeBanner: false,
            themeMode: preferences.mode,
            theme: theme(false),
            darkTheme: theme(true),
            localizationsDelegates: [_WeekDelegate(preferences.firstDayOfWeek)],
            home: const HomeScreen(),
            builder: (context, child) =>
                _LockGate(child: _SaveBanner(child: child ?? const SizedBox())),
          );
        },
      ),
    ),
  );
}

class _SaveBanner extends StatelessWidget {
  const _SaveBanner({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    return Column(
      children: [
        if (library.saving) const LinearProgressIndicator(),
        if (library.saveError != null)
          SafeArea(
            bottom: false,
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      library.saveError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    Wrap(
                      children: [
                        if (library.canRetry)
                          TextButton(
                            onPressed: library.retrySave,
                            child: const Text('Retry save'),
                          ),
                        TextButton(
                          onPressed: library.discardFailedChange,
                          child: Text(
                            library.canRetry ? 'Discard change' : 'Dismiss',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}

class _LockGate extends StatefulWidget {
  const _LockGate({required this.child});
  final Widget child;
  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> with WidgetsBindingObserver {
  bool _unlocked = false, _authenticating = false;
  String? _widgetBook;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LibraryModel.platform.setMethodCallHandler((call) async {
      if (call.method == 'openBook') {
        _widgetBook = call.arguments as String?;
        if (mounted) _openPending();
      }
    });
    unawaited(
      LibraryModel.platform
          .invokeMethod<String>('initialBook')
          .then((id) {
            _widgetBook = id;
            if (mounted) _openPending();
          })
          .catchError((Object _) {}),
    );
  }

  void _openPending() {
    final prefs = context.read<ThemeNotifier>();
    final id = _widgetBook;
    if (id == null ||
        id.isEmpty ||
        !prefs.loaded ||
        (prefs.appLock && !_unlocked)) {
      return;
    }
    _widgetBook = null;
    BookCompanionApp.navigator.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => BookDetailScreen(bookId: id, updateProgress: true),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LibraryModel.platform.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        !_authenticating &&
        context.read<ThemeNotifier>().appLock) {
      setState(() => _unlocked = false);
      unawaited(context.read<LibraryModel>().refreshWidget(private: true));
    }
  }

  Future<void> _unlock() async {
    setState(() => _authenticating = true);
    final ok = await context.read<ThemeNotifier>().authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _unlocked = ok;
    });
    if (ok) _openPending();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ThemeNotifier>();
    final library = context.watch<LibraryModel>();
    library.autoSnapshots = p.autoSnapshots;
    if (!p.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final locked = p.appLock && !_unlocked;
    final lockScreen = Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 40),
              const SizedBox(height: 16),
              const Text('Your library is locked'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _authenticating ? null : _unlock,
                child: const Text('Unlock library'),
              ),
            ],
          ),
        ),
      ),
    );
    if (_widgetBook != null && !library.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openPending();
      });
    }
    return Stack(
      children: [
        Offstage(offstage: locked, child: widget.child),
        if (locked) lockScreen,
      ],
    );
  }
}

class _WeekLocalizations extends DefaultMaterialLocalizations {
  const _WeekLocalizations(this.firstDay);
  final int firstDay;
  @override
  int get firstDayOfWeekIndex => firstDay;
}

class _WeekDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _WeekDelegate(this.firstDay);
  final int firstDay;
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(_WeekLocalizations(firstDay));
  @override
  bool shouldReload(_WeekDelegate old) => old.firstDay != firstDay;
}
