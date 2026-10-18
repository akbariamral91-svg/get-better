import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masir_ghabuli/database/app_database.dart';
import 'package:masir_ghabuli/providers/app_state.dart';
import 'package:masir_ghabuli/repositories/repository.dart';
import 'package:masir_ghabuli/screens/shell.dart';
import 'package:masir_ghabuli/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('چهار صفحهٔ اصلی در ناوبری قابل دسترسی‌اند و خانه پیش‌فرض است', (tester) async {
    late AppState state;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final db = await AppDatabase.open(path: inMemoryDatabasePath);
      state = AppState(Repository(db), await SharedPreferences.getInstance());
      await state.load();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: state.themeMode,
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const Shell(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(state.tabIndex, 0);
    Finder navLabel(String t) => find.descendant(of: find.byType(NavigationBar), matching: find.text(t));
    const labels = ['خانه', 'پیشرفت', 'یادداشت‌ها', 'مرور'];
    for (final l in labels) {
      expect(navLabel(l), findsOneWidget);
    }
    for (var i = 0; i < labels.length; i++) {
      await tester.tap(navLabel(labels[i]));
      await tester.pump(const Duration(milliseconds: 700));
      expect(state.tabIndex, i);
    }

    // دکمهٔ کوچک تغییر تم (در تب خانه)
    await tester.tap(navLabel('خانه'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(state.themeMode, ThemeMode.dark);
    await tester.tap(find.byTooltip('حالت روشن'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(state.themeMode, ThemeMode.light);
  });
}
