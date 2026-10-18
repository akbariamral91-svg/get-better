import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  /// نسخهٔ ۲: یادداشت‌ها، برچسب‌ها و اتفاقات روز. نسخهٔ ۳: ستون اختیاری آیکون برای مأموریت‌ها.
  /// ارتقاها فقط افزایشی‌اند و داده‌های قبلی دست‌نخورده می‌مانند.
  static const _version = 3;

  /// [path] برای تست‌ها (مثلاً inMemoryDatabasePath) قابل تعیین است.
  static Future<Database> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), 'masir_ghabuli.db');
    return openDatabase(dbPath, version: _version, onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    }, onCreate: (db, v) async {
      final b = db.batch();
      _createV1(b);
      _createV2(b);
      await b.commit(noResult: true);
    }, onUpgrade: (db, oldVersion, newVersion) async {
      // ارتقای امن: فقط جدول‌های جدید ساخته می‌شوند و هیچ دادهٔ قبلی تغییر نمی‌کند.
      final b = db.batch();
      if (oldVersion < 2) _createV2(b);
      await b.commit(noResult: true);
      if (oldVersion < 3) await _addMissionIcon(db);
    });
  }

  /// ستون icon فقط اگر وجود نداشته باشد افزوده می‌شود (ایمن در برابر اجرای تکراری).
  static Future<void> _addMissionIcon(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(missions)');
    if (cols.any((c) => c['name'] == 'icon')) return;
    await db.execute('ALTER TABLE missions ADD COLUMN icon TEXT');
  }

  static void _createV1(Batch b) {
    b.execute('''CREATE TABLE missions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL, subject TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '',
        minutes INTEGER NOT NULL DEFAULT 30, priority INTEGER NOT NULL DEFAULT 1,
        done INTEGER NOT NULL DEFAULT 0, xp INTEGER NOT NULL DEFAULT 10,
        date TEXT NOT NULL, note TEXT NOT NULL DEFAULT '',
        spent_seconds INTEGER NOT NULL DEFAULT 0, completed_at TEXT, icon TEXT)''');
    b.execute('CREATE INDEX idx_missions_date ON missions(date)');
    // دفتر XP: هر مأموریت فقط یک ردیف دارد؛ UNIQUE جلوی امتیاز تکراری را در سطح پایگاه داده می‌گیرد.
    b.execute('''CREATE TABLE xp_ledger(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mission_id INTEGER NOT NULL UNIQUE, xp INTEGER NOT NULL, at TEXT NOT NULL)''');
    b.execute('CREATE TABLE subjects(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE)');
    b.execute('''CREATE TABLE topics(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
        chapter TEXT NOT NULL DEFAULT '', name TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '', mistakes TEXT NOT NULL DEFAULT '',
        status INTEGER NOT NULL DEFAULT 0, next_review TEXT)''');
    b.execute('''CREATE TABLE quiz_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic_id INTEGER NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
        kind TEXT NOT NULL, total INTEGER NOT NULL, correct INTEGER NOT NULL,
        seconds INTEGER, date TEXT NOT NULL, note TEXT NOT NULL DEFAULT '')''');
    b.execute('CREATE TABLE achievements(id TEXT PRIMARY KEY, unlocked_at TEXT NOT NULL)');
  }

  static void _createV2(Batch b) {
    b.execute('''CREATE TABLE IF NOT EXISTS notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL DEFAULT '', body TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        pinned INTEGER NOT NULL DEFAULT 0)''');
    b.execute('CREATE INDEX IF NOT EXISTS idx_notes_pinned ON notes(pinned, updated_at)');
    b.execute('''CREATE TABLE IF NOT EXISTS tags(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE, color INTEGER NOT NULL)''');
    // جدول رابط: حذف برچسب فقط ردیف‌های رابط را پاک می‌کند، نه خود یادداشت‌ها را.
    b.execute('''CREATE TABLE IF NOT EXISTS note_tags(
        note_id INTEGER NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
        tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
        PRIMARY KEY(note_id, tag_id))''');
    b.execute('CREATE INDEX IF NOT EXISTS idx_note_tags_tag ON note_tags(tag_id)');
    b.execute('''CREATE TABLE IF NOT EXISTS day_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT, body TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL, time TEXT NOT NULL DEFAULT '00:00', icon TEXT)''');
    b.execute('CREATE INDEX IF NOT EXISTS idx_day_events_date ON day_events(date)');
  }
}
