import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:masir_ghabuli/database/app_database.dart';
import 'package:masir_ghabuli/models/models.dart';
import 'package:masir_ghabuli/repositories/repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Repository repo;
  setUp(() async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    repo = Repository(db);
  });

  Mission m() => const Mission(title: 'تست', date: '2026-10-17', xp: 25);

  test('XP فقط یک بار ثبت می‌شود', () async {
    final id = await repo.insertMission(m());
    expect(await repo.completeMission(id, DateTime(2026, 10, 17)), 25);
    expect(await repo.completeMission(id, DateTime(2026, 10, 17)), 0);
    await repo.reopenMission(id);
    expect(await repo.completeMission(id, DateTime(2026, 10, 18)), 0);
    expect(await repo.totalXp(), 25);
  });

  test('حذف مأموریت امتیاز را پاک نمی‌کند', () async {
    final id = await repo.insertMission(m());
    await repo.completeMission(id, DateTime(2026, 10, 17));
    await repo.deleteMission(id);
    expect(await repo.totalXp(), 25);
  });

  test('پشتیبان و بازیابی', () async {
    final id = await repo.insertMission(m());
    await repo.completeMission(id, DateTime(2026, 10, 17));
    final sid = await repo.insertSubject('ریاضی');
    final tid = await repo.insertTopic(Topic(subjectId: sid, name: 'کسر'));
    await repo.insertLog(QuizLog(topicId: tid, kind: 'exam', total: 10, correct: 8, date: '2026-10-17'));
    final backup = await repo.exportAll();

    await repo.wipe();
    expect(await repo.totalXp(), 0);
    expect((await repo.allMissions()), isEmpty);

    await repo.importAll(Map<String, dynamic>.from(backup));
    expect(await repo.totalXp(), 25);
    expect((await repo.allMissions()).length, 1);
    expect((await repo.logs()).length, 1);
    expect((await repo.topics()).first.name, 'کسر');
  });

  test('پشتیبان نامعتبر داده‌ها را تغییر نمی‌دهد', () async {
    await repo.insertMission(m());
    expect(() => repo.importAll({'app': 'other'}), throwsFormatException);
    expect((await repo.allMissions()).length, 1);
  });

  // ---------- یادداشت‌ها، برچسب‌ها و اتفاقات روز (پایگاه داده نسخهٔ ۲) ----------
  Note n(String title, {List<int> tags = const [], bool pinned = false, String at = '2026-10-18T10:00:00'}) =>
      Note(title: title, body: 'متن', createdAt: at, updatedAt: at, pinned: pinned, tagIds: tags);

  test('یادداشت با چند برچسب ذخیره و بازیابی می‌شود', () async {
    final t1 = await repo.insertTag(const NoteTag(name: 'ریاضی', color: 0xFFE8B84A));
    final t2 = await repo.insertTag(const NoteTag(name: 'مهم', color: 0xFF4CC38A));
    final id = await repo.insertNote(n('الف', tags: [t1, t2]));
    final list = await repo.notes();
    expect(list.length, 1);
    expect(list.first.id, id);
    expect(list.first.title, 'الف');
    expect(list.first.createdAt, '2026-10-18T10:00:00');
    expect(list.first.tagIds.toSet(), {t1, t2});
  });

  test('حذف برچسب، یادداشت‌های مربوط را حذف نمی‌کند', () async {
    final t = await repo.insertTag(const NoteTag(name: 'x', color: 1));
    await repo.insertNote(n('الف', tags: [t]));
    await repo.deleteTag(t);
    final list = await repo.notes();
    expect(list.length, 1);
    expect(list.first.tagIds, isEmpty);
    expect(await repo.tags(), isEmpty);
  });

  test('حذف یادداشت، برچسب را نگه می‌دارد', () async {
    final t = await repo.insertTag(const NoteTag(name: 'x', color: 1));
    final id = await repo.insertNote(n('الف', tags: [t]));
    await repo.deleteNote(id);
    expect(await repo.notes(), isEmpty);
    expect((await repo.tags()).length, 1);
  });

  test('سنجاق‌شده‌ها اول می‌آیند و ویرایش برچسب‌ها اعمال می‌شود', () async {
    final t1 = await repo.insertTag(const NoteTag(name: 'الف', color: 1));
    final t2 = await repo.insertTag(const NoteTag(name: 'ب', color: 2));
    final oldId = await repo.insertNote(n('قدیمی', at: '2026-10-01T10:00:00', tags: [t1]));
    await repo.insertNote(n('جدید', at: '2026-10-18T10:00:00'));
    await repo.setNotePinned(oldId, true);
    var list = await repo.notes();
    expect(list.first.title, 'قدیمی');
    expect(list.first.pinned, true);

    await repo.updateNote(list.first.copyWith(title: 'ویرایش‌شده', updatedAt: '2026-10-19T09:00:00', tagIds: [t2]));
    list = await repo.notes();
    expect(list.first.title, 'ویرایش‌شده');
    expect(list.first.updatedAt, '2026-10-19T09:00:00');
    expect(list.first.createdAt, '2026-10-01T10:00:00');
    expect(list.first.tagIds, [t2]);
  });

  test('نام برچسب یکتا است', () async {
    await repo.insertTag(const NoteTag(name: 'تکراری', color: 1));
    await expectLater(repo.insertTag(const NoteTag(name: 'تکراری', color: 2)), throwsA(anything));
    expect((await repo.tags()).length, 1);
  });

  test('چند اتفاق در یک روز ثبت می‌شود', () async {
    await repo.insertDayEvent(const DayEvent(title: 'الف', body: 'اول', date: '2026-10-18', time: '08:00', icon: 'cake'));
    await repo.insertDayEvent(const DayEvent(body: 'دوم', date: '2026-10-18', time: '20:30'));
    final list = await repo.dayEvents();
    expect(list.length, 2);
    expect(list.first.time, '20:30');
    expect(list.first.title, isNull);
    expect(list.first.icon, isNull);
    expect(list.last.title, 'الف');
    expect(list.last.icon, 'cake');
    await repo.deleteDayEvent(list.first.id!);
    expect((await repo.dayEvents()).length, 1);
  });

  test('پشتیبان و بازیابی شامل یادداشت‌ها، برچسب‌ها و اتفاقات است', () async {
    final t = await repo.insertTag(const NoteTag(name: 'مهم', color: 5));
    await repo.insertNote(n('الف', tags: [t], pinned: true));
    await repo.insertDayEvent(const DayEvent(body: 'اتفاق', date: '2026-10-18', time: '10:00'));
    final backup = await repo.exportAll();

    await repo.wipe();
    expect(await repo.notes(), isEmpty);
    expect(await repo.tags(), isEmpty);
    expect(await repo.dayEvents(), isEmpty);

    await repo.importAll(Map<String, dynamic>.from(backup));
    final notes = await repo.notes();
    expect(notes.length, 1);
    expect(notes.first.pinned, true);
    expect(notes.first.tagIds, [t]);
    expect((await repo.dayEvents()).length, 1);
  });

  test('پشتیبان نسخهٔ ۱ (بدون جدول‌های جدید) بازیابی می‌شود', () async {
    await repo.insertMission(m());
    final backup = Map<String, dynamic>.from(await repo.exportAll())
      ..remove('notes')
      ..remove('tags')
      ..remove('note_tags')
      ..remove('day_events');
    await repo.importAll(backup);
    expect((await repo.allMissions()).length, 1);
    expect(await repo.notes(), isEmpty);
  });

  test('ارتقا از نسخهٔ ۱ به ۲ دادهٔ قبلی را حفظ می‌کند', () async {
    final dir = Directory.systemTemp.createTempSync('masir_db_test');
    final path = '${dir.path}/v1.db';
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
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
    expect((await r.allMissions()).single.title, 'قدیمی');
    final id = await r.insertNote(n('جدید'));
    expect((await r.notes()).single.id, id);
    await db.close();
    dir.deleteSync(recursive: true);
  });
}
