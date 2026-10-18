import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masir_ghabuli/database/app_database.dart';
import 'package:masir_ghabuli/models/models.dart';
import 'package:masir_ghabuli/providers/app_state.dart';
import 'package:masir_ghabuli/repositories/repository.dart';
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

  test('تم پیش‌فرض تیره است و انتخاب کاربر پس از راه‌اندازی دوباره حفظ می‌شود', () async {
    final a = await fresh();
    expect(a.themeMode, ThemeMode.dark);
    await a.setThemeMode(ThemeMode.light);
    expect((await fresh()).themeMode, ThemeMode.light);
    await a.toggleTheme();
    expect((await fresh()).themeMode, ThemeMode.dark);
  });

  test('پاک‌سازی کامل داده‌ها تم انتخابی را نگه می‌دارد', () async {
    final a = await fresh();
    await a.setThemeMode(ThemeMode.light);
    await a.wipeAll();
    expect(a.themeMode, ThemeMode.light);
    expect((await fresh()).themeMode, ThemeMode.light);
  });

  test('یادداشت: اعتبارسنجی، ذخیره، ویرایش، سنجاق و حذف', () async {
    final s = await fresh();
    expect(await s.saveNote(title: ' ', body: ''), isNotNull);
    expect(await s.saveNote(title: 'الف', body: 'متن'), isNull);
    expect(s.notes.length, 1);
    final id = s.notes.first.id!;
    expect(await s.saveNote(id: id, title: 'ب', body: 'متن'), isNull);
    expect(s.notes.first.title, 'ب');
    expect(await s.toggleNotePin(id), isNull);
    expect(s.notes.first.pinned, true);
    expect(await s.deleteNote(id), isNull);
    expect(s.notes, isEmpty);
  });

  test('برچسب: نام یکتا و حذف بدون حذف یادداشت', () async {
    final s = await fresh();
    expect(await s.saveTag(name: '', color: 1), isNotNull);
    expect(await s.saveTag(name: 'مهم', color: 0xFFE8B84A), isNull);
    expect(await s.saveTag(name: 'مهم', color: 2), isNotNull);
    final tagId = s.tags.first.id!;
    expect(await s.saveNote(title: 'الف', tagIds: [tagId]), isNull);
    expect(s.notes.first.tagIds, [tagId]);
    expect(await s.deleteTag(tagId), isNull);
    expect(s.tags, isEmpty);
    expect(s.notes.length, 1);
    expect(s.notes.first.tagIds, isEmpty);
  });

  test('اتفاقات روز: چند اتفاق در یک روز و اعتبارسنجی', () async {
    final s = await fresh();
    expect(await s.saveDayEvent(body: ' '), isNotNull);
    expect(await s.saveDayEvent(body: 'الف', time: '25:99'), isNotNull);
    expect(await s.saveDayEvent(body: 'الف', date: '۱۴۰۵', time: '10:00'), isNotNull);
    expect(await s.saveDayEvent(body: 'اول', date: '2026-10-18', time: '08:00', icon: 'cake'), isNull);
    expect(await s.saveDayEvent(title: ' ', body: 'دوم', date: '2026-10-18', time: '21:15'), isNull);
    expect(s.eventsOn('2026-10-18').length, 2);
    final second = s.dayEvents.firstWhere((e) => e.body == 'دوم');
    expect(second.title, isNull);
    expect(second.icon, isNull);
    expect(await s.deleteDayEvent(second.id!), isNull);
    expect(s.eventsOn('2026-10-18').length, 1);
  });

  test('داده‌های جدید پس از بارگذاری دوباره باقی می‌مانند', () async {
    final s = await fresh();
    await s.saveNote(title: 'ماندگار', body: 'متن');
    await s.saveDayEvent(body: 'اتفاق', date: '2026-10-18', time: '10:00');
    final again = await fresh();
    await again.load();
    expect(again.notes.map((Note n) => n.title), ['ماندگار']);
    expect(again.dayEvents.length, 1);
  });
}
