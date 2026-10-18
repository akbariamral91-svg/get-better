import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masir_ghabuli/database/app_database.dart';
import 'package:masir_ghabuli/models/models.dart';
import 'package:masir_ghabuli/providers/app_state.dart';
import 'package:masir_ghabuli/repositories/repository.dart';
import 'package:masir_ghabuli/screens/notes_screen.dart';
import 'package:masir_ghabuli/screens/roadmap_screen.dart';
import 'package:masir_ghabuli/theme/app_theme.dart';
import 'package:masir_ghabuli/utils/app_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Repository repo;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = Repository(await AppDatabase.open(path: inMemoryDatabasePath));
  });

  Future<AppState> fresh() async => AppState(repo, await SharedPreferences.getInstance());

  Note note(String t, String b, {List<int> tags = const []}) =>
      Note(title: t, body: b, createdAt: '2026-10-18T10:00:00', updatedAt: '2026-10-18T10:00:00', tagIds: tags);

  test('جست‌وجو در عنوان و متن و فیلتر برچسب', () {
    final all = [note('ریاضی', 'کسرها', tags: [1]), note('علوم', 'سلول و بافت', tags: [2]), note('', 'يادداشت عربی‌نویس')];
    expect(filterNotes(all, query: 'کسر').length, 1);
    expect(filterNotes(all, query: 'بافت').single.title, 'علوم');
    expect(filterNotes(all, query: 'یادداشت').length, 1); // «ي» عربی با «ی» فارسی یکی گرفته می‌شود
    expect(filterNotes(all, tagId: 2).single.title, 'علوم');
    expect(filterNotes(all, tagId: 1, query: 'سلول'), isEmpty);
    expect(filterNotes(all).length, 3);
  });

  test('آیکون مأموریت و اتفاق ذخیره می‌شود و کلیدها معتبرند', () async {
    final s = await fresh();
    final id = await repo.insertMission(const Mission(title: 'الف', date: '2026-10-18', xp: 10, icon: 'quiz'));
    await s.load();
    expect(s.missions.single.icon, 'quiz');
    await s.saveMission(s.missions.single.copyWith(title: 'ب', icon: 'brush'));
    expect((await repo.allMissions()).single.icon, 'brush');
    await s.saveMission(s.missions.single.copyWith(clearIcon: true));
    expect((await repo.allMissions()).single.icon, isNull);
    expect(id, isPositive);
    await s.saveDayEvent(body: 'x', icon: 'cake');
    expect((await fresh().then((a) async {
      await a.load();
      return a;
    }))
        .dayEvents
        .single
        .icon, 'cake');
    for (final keys in iconGroupKeys.values) {
      for (final k in keys) {
        expect(appIcons.containsKey(k), true, reason: k);
      }
    }
  });

  test('تاریخ آزمون: بدون پیش‌فرض، ذخیره، شمارش معکوس، حذف و پشتیبان', () async {
    final s = await fresh();
    expect(s.examDate, isNull);
    expect(s.daysToExam, isNull);
    final t0 = s.today;
    final target = DateTime(t0.year, t0.month, t0.day + 12);
    expect(await s.setExamDate(target), isNull);
    expect(s.daysToExam, 12);
    expect((await fresh()).examDate, target);

    final backup = await s.exportBackup();
    await s.setExamDate(null);
    expect(s.examDate, isNull);
    expect(await s.importBackup(backup), isNull);
    expect(s.examDate, target);
  });

  test('مرحله‌های مسیر از داده واقعی ساخته می‌شوند', () async {
    final s = await fresh();
    final st = buildRoadmapStages(s);
    expect(st.length, 7);
    expect(st.first.done, true);
    expect(activeStageIndex(st), 1);
    expect(st[1].have, 0);
    expect(stageStatus(0, 1), StageStatus.completed);
    expect(stageStatus(1, 1), StageStatus.active);
    expect(stageStatus(2, 1), StageStatus.locked);
    expect(segmentFill(0, 1, st), 0.0); // هنوز هیچ پیشرفتی در مرحلهٔ فعال ثبت نشده
    expect(segmentFill(1, 1, st), 0.0);
    expect(segmentFill(0, 2, st), 1.0);
    const done = [RoadmapStage('الف', '', 1, 1), RoadmapStage('ب', '', 3, 3)];
    expect(activeStageIndex(done), 2);
    expect(segmentFill(1, 2, done), 1.0); // قطعهٔ منتهی به هدف وقتی همه کامل‌اند
  });

  test('ارتقای پایگاه داده از نسخهٔ ۲ به ۳ مأموریت‌ها را حفظ می‌کند', () async {
    final dir = Directory.systemTemp.createTempSync('masir_db_v2');
    final path = '${dir.path}/v2.db';
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, v) async {
          await db.execute('''CREATE TABLE missions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL, subject TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '',
            minutes INTEGER NOT NULL DEFAULT 30, priority INTEGER NOT NULL DEFAULT 1,
            done INTEGER NOT NULL DEFAULT 0, xp INTEGER NOT NULL DEFAULT 10,
            date TEXT NOT NULL, note TEXT NOT NULL DEFAULT '',
            spent_seconds INTEGER NOT NULL DEFAULT 0, completed_at TEXT)''');
          await db.execute("INSERT INTO missions(title, date, xp) VALUES('قدیمی', '2026-10-17', 25)");
        },
      ),
    );
    await old.close();
    final db = await AppDatabase.open(path: path);
    final r = Repository(db);
    final m = (await r.allMissions()).single;
    expect(m.title, 'قدیمی');
    expect(m.icon, isNull);
    await r.updateMission(m.copyWith(icon: 'school'));
    expect((await r.allMissions()).single.icon, 'school');
    await db.close();
    dir.deleteSync(recursive: true);
  });

  test('تم روی فونت وزیرمتن تنظیم شده است', () {
    for (final b in Brightness.values) {
      final t = buildTheme(b);
      expect(t.textTheme.bodyMedium?.fontFamily, appFontFamily);
      expect(t.textTheme.titleLarge?.fontFamily, appFontFamily);
    }
    expect(appFontFamily, 'Vazirmatn');
  });

  testWidgets('صفحهٔ پیشرفت هدف و مرحله‌ها را نشان می‌دهد و صفحهٔ یادداشت‌ها بدون خطا ساخته می‌شود', (tester) async {
    late AppState state;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final db = await AppDatabase.open(path: inMemoryDatabasePath);
      state = AppState(Repository(db), await SharedPreferences.getInstance());
      await state.load();
      await state.saveNote(title: 'نمونه', body: 'متن');
    });
    Widget app(Widget child) => ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            locale: const Locale('fa'),
            supportedLocales: const [Locale('fa')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (c, ch) => Directionality(textDirection: TextDirection.rtl, child: ch!),
            home: Scaffold(body: child),
          ),
        );

    await tester.binding.setSurfaceSize(const Size(360, 720));
    await tester.pumpWidget(app(const RoadmapScreen()));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('نقشهٔ مسیر'), findsOneWidget);
    expect(find.text('تاریخ آزمون هنوز تعیین نشده است.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(app(const NotesScreen()));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('نمونه'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
