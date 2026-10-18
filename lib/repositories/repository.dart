import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

class Repository {
  final Database db;
  Repository(this.db);

  // ---------- مأموریت‌ها ----------
  Future<List<Mission>> allMissions() async =>
      (await db.query('missions', orderBy: 'date ASC, priority DESC, id ASC')).map(Mission.fromMap).toList();

  Future<int> insertMission(Mission m) => db.insert('missions', m.toMap()..remove('id'));

  Future<void> updateMission(Mission m) => db.update(
        'missions',
        {
          'title': m.title, 'subject': m.subject, 'description': m.description,
          'minutes': m.minutes, 'priority': m.priority, 'xp': m.xp, 'date': m.date, 'note': m.note,
          'icon': m.icon,
        },
        where: 'id = ?',
        whereArgs: [m.id],
      );

  Future<void> moveMission(int id, String date) =>
      db.update('missions', {'date': date}, where: 'id = ? AND done = 0', whereArgs: [id]);

  /// امتیاز اولیهٔ حذف‌شده‌ها حفظ می‌شود (دفتر XP دست‌نخورده می‌ماند).
  Future<void> deleteMission(int id) => db.delete('missions', where: 'id = ?', whereArgs: [id]);

  /// تکمیل اتمیک: وضعیت و امتیاز در یک تراکنش ثبت می‌شوند. اگر قبلاً امتیاز گرفته باشد، ۰ برمی‌گردد.
  Future<int> completeMission(int id, DateTime now, {int spentSeconds = 0}) {
    return db.transaction((txn) async {
      final rows = await txn.query('missions', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return 0;
      final m = Mission.fromMap(rows.first);
      await txn.update(
        'missions',
        {
          'done': 1,
          'completed_at': m.completedAt ?? now.toIso8601String(),
          'spent_seconds': m.spentSeconds + (m.done ? 0 : spentSeconds),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      final existing = await txn.query('xp_ledger', where: 'mission_id = ?', whereArgs: [id]);
      if (existing.isNotEmpty) return 0;
      await txn.insert('xp_ledger', {'mission_id': id, 'xp': m.xp, 'at': now.toIso8601String()},
          conflictAlgorithm: ConflictAlgorithm.ignore);
      return m.xp;
    });
  }

  /// بازگرداندن وضعیت به «انجام‌نشده»؛ XP ثبت‌شده دست‌نخورده می‌ماند و دوباره داده نمی‌شود.
  Future<void> reopenMission(int id) => db.update('missions', {'done': 0}, where: 'id = ?', whereArgs: [id]);

  Future<int> totalXp() async {
    final r = await db.rawQuery('SELECT COALESCE(SUM(xp),0) AS s FROM xp_ledger');
    return (r.first['s'] as num).toInt();
  }

  Future<List<Map<String, Object?>>> ledger() => db.query('xp_ledger');

  // ---------- درس‌ها و مباحث ----------
  Future<List<Subject>> subjects() async => (await db.query('subjects', orderBy: 'id')).map(Subject.fromMap).toList();

  Future<int> insertSubject(String name) =>
      db.insert('subjects', {'name': name}, conflictAlgorithm: ConflictAlgorithm.abort);

  Future<void> deleteSubject(int id) => db.delete('subjects', where: 'id = ?', whereArgs: [id]);

  Future<List<Topic>> topics() async => (await db.query('topics', orderBy: 'chapter, id')).map(Topic.fromMap).toList();

  Future<int> insertTopic(Topic t) => db.insert('topics', t.toMap()..remove('id'));

  Future<void> updateTopic(Topic t) =>
      db.update('topics', t.toMap()..remove('id'), where: 'id = ?', whereArgs: [t.id]);

  Future<void> deleteTopic(int id) => db.delete('topics', where: 'id = ?', whereArgs: [id]);

  // ---------- ثبت تمرین/آزمون ----------
  Future<List<QuizLog>> logs() async =>
      (await db.query('quiz_logs', orderBy: 'date DESC, id DESC')).map(QuizLog.fromMap).toList();

  Future<int> insertLog(QuizLog l) => db.insert('quiz_logs', l.toMap()..remove('id'));

  Future<void> deleteLog(int id) => db.delete('quiz_logs', where: 'id = ?', whereArgs: [id]);

  // ---------- دستاوردها ----------
  Future<Map<String, String>> achievements() async {
    final r = await db.query('achievements');
    return {for (final e in r) e['id'] as String: e['unlocked_at'] as String};
  }

  Future<void> unlockAchievement(String id, DateTime at) => db.insert(
      'achievements', {'id': id, 'unlocked_at': at.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore);

  // ---------- یادداشت‌ها ----------
  /// سنجاق‌شده‌ها اول؛ سپس جدیدترین ویرایش. برچسب‌ها با یک پرس‌وجوی جدا و بدون N+1 بارگذاری می‌شوند.
  Future<List<Note>> notes() async {
    final rows = await db.query('notes', orderBy: 'pinned DESC, updated_at DESC, id DESC');
    final links = await db.query('note_tags');
    final byNote = <int, List<int>>{};
    for (final l in links) {
      byNote.putIfAbsent(l['note_id'] as int, () => <int>[]).add(l['tag_id'] as int);
    }
    return [for (final r in rows) Note.fromMap(r, tagIds: byNote[r['id'] as int] ?? <int>[])];
  }

  Future<int> insertNote(Note n) => db.transaction((txn) async {
        final id = await txn.insert('notes', n.toMap()..remove('id'));
        await _setNoteTags(txn, id, n.tagIds);
        return id;
      });

  Future<void> updateNote(Note n) => db.transaction((txn) async {
        await txn.update(
          'notes',
          {'title': n.title, 'body': n.body, 'updated_at': n.updatedAt, 'pinned': n.pinned ? 1 : 0},
          where: 'id = ?',
          whereArgs: [n.id],
        );
        await _setNoteTags(txn, n.id!, n.tagIds);
      });

  Future<void> _setNoteTags(DatabaseExecutor txn, int noteId, List<int> tagIds) async {
    await txn.delete('note_tags', where: 'note_id = ?', whereArgs: [noteId]);
    for (final t in tagIds.toSet()) {
      await txn.insert('note_tags', {'note_id': noteId, 'tag_id': t});
    }
  }

  Future<void> setNotePinned(int id, bool pinned) =>
      db.update('notes', {'pinned': pinned ? 1 : 0}, where: 'id = ?', whereArgs: [id]);

  /// حذف یادداشت، ردیف‌های رابط برچسب‌هایش را هم پاک می‌کند (CASCADE)؛ خود برچسب‌ها می‌مانند.
  Future<void> deleteNote(int id) => db.delete('notes', where: 'id = ?', whereArgs: [id]);

  // ---------- برچسب‌ها ----------
  Future<List<NoteTag>> tags() async => (await db.query('tags', orderBy: 'id')).map(NoteTag.fromMap).toList();

  Future<int> insertTag(NoteTag t) => db.insert('tags', t.toMap()..remove('id'), conflictAlgorithm: ConflictAlgorithm.abort);

  Future<void> updateTag(NoteTag t) =>
      db.update('tags', {'name': t.name, 'color': t.color}, where: 'id = ?', whereArgs: [t.id]);

  /// حذف برچسب یادداشت‌های مربوط به آن را حذف نمی‌کند؛ فقط ارتباط‌ها پاک می‌شوند (CASCADE روی note_tags).
  Future<void> deleteTag(int id) => db.delete('tags', where: 'id = ?', whereArgs: [id]);

  // ---------- اتفاقات روز ----------
  Future<List<DayEvent>> dayEvents() async =>
      (await db.query('day_events', orderBy: 'date DESC, time DESC, id DESC')).map(DayEvent.fromMap).toList();

  Future<int> insertDayEvent(DayEvent e) => db.insert('day_events', e.toMap()..remove('id'));

  Future<void> updateDayEvent(DayEvent e) =>
      db.update('day_events', e.toMap()..remove('id'), where: 'id = ?', whereArgs: [e.id]);

  Future<void> deleteDayEvent(int id) => db.delete('day_events', where: 'id = ?', whereArgs: [id]);

  // ---------- پشتیبان‌گیری ----------
  // ترتیب مهم است: والدها پیش از جدول‌های وابسته (برای کلید خارجی)
  static const _tables = [
    'subjects', 'topics', 'missions', 'xp_ledger', 'quiz_logs', 'achievements',
    'notes', 'tags', 'note_tags', 'day_events',
  ];

  Future<Map<String, Object?>> exportAll() async {
    final out = <String, Object?>{'app': 'masir_ghabuli', 'version': 3, 'exported_at': DateTime.now().toIso8601String()};
    for (final t in _tables) {
      out[t] = await db.query(t);
    }
    return out;
  }

  /// بازیابی در یک تراکنش؛ در صورت خطا هیچ داده‌ای تغییر نمی‌کند.
  Future<void> importAll(Map<String, dynamic> data) async {
    if (data['app'] != 'masir_ghabuli') throw const FormatException('فایل پشتیبان معتبر نیست.');
    await db.transaction((txn) async {
      for (final t in _tables.reversed) {
        await txn.delete(t);
      }
      for (final t in _tables) {
        final rows = (data[t] as List?) ?? const [];
        for (final r in rows) {
          await txn.insert(t, Map<String, Object?>.from(r as Map));
        }
      }
    });
  }

  Future<void> wipe() async {
    await db.transaction((txn) async {
      for (final t in _tables.reversed) {
        await txn.delete(t);
      }
    });
  }
}
