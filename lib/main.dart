import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/app_database.dart';
import 'providers/app_state.dart';
import 'repositories/repository.dart';
import 'screens/shell.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppState? state;
  Object? error;
  try {
    await NotificationService.init();
    final db = await AppDatabase.open();
    final prefs = await SharedPreferences.getInstance();
    state = AppState(Repository(db), prefs);
    await state.load();
    await state.applyReminders();
  } catch (e) {
    error = e;
  }
  runApp(MasirApp(state: state, error: error));
}

class MasirApp extends StatelessWidget {
  final AppState? state;
  final Object? error;
  const MasirApp({super.key, this.state, this.error});

  @override
  Widget build(BuildContext context) {
    final st = state;
    // در حالت خطای راه‌اندازی، پیش‌فرض (تیره) استفاده می‌شود.
    if (st == null) return _buildApp(ThemeMode.dark);
    // Provider باید بالاتر از MaterialApp باشد تا هم صفحه‌های push‌شده و هم تم به وضعیت دسترسی داشته باشند.
    return ChangeNotifierProvider.value(
      value: st,
      child: Selector<AppState, ThemeMode>(
        selector: (_, s) => s.themeMode,
        builder: (_, mode, __) => _buildApp(mode),
      ),
    );
  }

  Widget _buildApp(ThemeMode mode) {
    return MaterialApp(
      title: 'Get Better',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: mode,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: state == null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('راه‌اندازی پایگاه داده انجام نشد.\nبرنامه را ببند و دوباره باز کن.\n\n$error',
                      textAlign: TextAlign.center, style: const TextStyle(height: 1.8)),
                ),
              ),
            )
          : const Shell(),
    );
  }
}
