import 'dart:convert';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../repositories/repository.dart';
import '../services/logic.dart';
import '../services/notification_service.dart';
import '../utils/dates.dart';

class CompletionResult {
  final int gained, oldLevel, newLevel;
  final List<Achievement> newAchievements;
  const CompletionResult(this.gained, this.oldLevel, this.newLevel, this.newAchievements);
  bool get leveledUp => newLevel > oldLevel;
}

class ReminderSetting {
  final bool enabled;
  final int hour, minute;
  const ReminderSetting(this.enabled, this.hour, this.minute);
}

class AppState extends ChangeNotifier {
  final Repository repo;
  final SharedPreferences prefs;

  static const _themeKey = 'theme_mode';
  static const _examKey = 'exam_date';

  /// تم انتخابی کاربر؛ پیش‌فرض تیره است و در SharedPreferences ذخیره می‌شود.
  ThemeMode themeMode;

  AppState(this.repo, this.prefs) : themeMode = prefs.getString(_themeKey) == 'light' ? ThemeMode.light : ThemeMode.dark;

  List<Mission> missions = [];
  List<Subject> subjects = [];
  List<Topic> topics = [];
  List<QuizLog> logs = [];
  List<Note> notes = [];
  List<NoteTag> tags = [];
  List<DayEvent> dayEvents = [];
  Map<String, String> unlocked = {};
  int totalXp = 0;
  List<Map<String, Object?>> _ledger = [];

  /// روز انتخاب‌شده در صفحه برنامه
  DateTime selectedDay = dateOnly(DateTime.now());

  /// تب فعال نوار پایین: ۰ خانه، ۱ پیشرفت، ۲ یادداشت‌ها، ۳ مرور
  int tabIndex = 0;

  /// بخش فعال تب خانه: ۰ امروز، ۱ برنامه روزانه
  int homeSub = 0;

  // برای تست‌پذیری ساعت قابل جایگزینی است
  DateTime Function() clock = DateTime.now;
  DateTime get today => dateOnly(clock());
  String get todayIso => isoDay(today);

  Future<void> load() async {
    missions = await repo.allMissions();
    subjects = await repo.subjects();
    topics = await repo.topics();
    logs = await repo.logs();
    notes = await repo.notes();
    tags = await repo.tags();
    dayEvents = await repo.dayEvents();
    unlocked = await repo.achievements();
    totalXp = await repo.totalXp();
    _ledger = await repo.ledger();
    notifyListeners();
  }

  // ---------- مشتق‌شده‌ها ----------
  int get level => levelForXp(totalXp);
  double get levelFraction => levelProgress(totalXp);

  List<Mission> missionsOn(String iso) => missions.where((m) => m.date == iso).toList();
  List<Mission> get todayMissions => missionsOn(todayIso);
  Mission? get nextMission {
    final l = todayMissions.where((m) => !m.done).toList();
    if (l.isEmpty) return null;
    l.sort((a, b) => b.priority.compareTo(a.priority));
    return l.first;
  }

  List<Mission> get overdue => missions.where((m) => !m.done && m.date.compareTo(todayIso) < 0).toList();

  Set<String> get activeDays => {
        for (final m in missions)
          if (m.done && m.completedAt != null) m.completedAt!.substring(0, 10),
        for (final l in logs) l.date,
      };

  String? get lastActiveDay {
    if (activeDays.isEmpty) return null;
    final l = activeDays.toList()..sort();
    return l.last;
  }

  int get daysSinceActive {
    final last = lastActiveDay;
    return last == null ? 0 : daysBetween(parseDay(last), today);
  }

  /// حالت بازگشت: حداقل ۳ روز وقفه پس از سابقهٔ فعالیت
  bool get comebackMode => lastActiveDay != null && daysSinceActive >= 3;

  List<QuizLog> logsOf(int topicId) => logs.where((l) => l.topicId == topicId).toList();
  Subject? subjectOf(int id) {
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  int xpOnDay(String iso) =>
      _ledger.where((r) => (r['at'] as String).startsWith(iso)).fold<int>(0, (s, r) => s + (r['xp'] as int));

  int get completedCount => missions.where((m) => m.done).length;
  int get studiedSeconds => missions.fold<int>(0, (s, m) => s + m.spentSeconds);
  int get totalQuestions => logs.fold<int>(0, (s, l) => s + l.total);
  int get totalCorrect => logs.fold<int>(0, (s, l) => s + l.correct);
  int get masteredCount => topics.where((t) => t.status == Mastery.mastered).length;
  List<Topic> get weakTopics => topics.where((t) => isWeakTopic(t, logsOf(t.id!), todayIso)).toList();

  // ---------- مأموریت‌ها ----------
  String? _validateMission(Mission m) {
    if (m.title.trim().isEmpty) return 'عنوان مأموریت را وارد کن.';
    if (m.minutes < 1 || m.minutes > 480) return 'زمان باید بین ۱ تا ۴۸۰ دقیقه باشد.';
    return null;
  }

  Future<String?> saveMission(Mission m) async {
    final err = _validateMission(m);
    if (err != null) return err;
    try {
      if (m.id == null) {
        await repo.insertMission(m);
      } else {
        await repo.updateMission(m);
      }
      await load();
      return null;
    } catch (e) {
      return 'ذخیره انجام نشد. دوباره تلاش کن.';
    }
  }

  Mission quick(String title, String subject, int minutes, int priority, String iso, {String description = ''}) => Mission(
      title: title, subject: subject, description: description, date: iso, minutes: minutes, priority: priority,
      xp: xpForMission(minutes, priority));

  Future<void> addDefaultMissions(String iso) async {
    final w = weakTopics;
    final focus = w.isNotEmpty ? w.first : null;
    final sub = focus == null ? '' : (subjectOf(focus.subjectId)?.name ?? '');
    final topic = focus?.name ?? 'یک مبحث مشخص';
    await repo.insertMission(quick('مطالعهٔ $topic', sub, 40, 2, iso, description: 'یک مبحث را با تمرکز بخوان و نکته‌برداری کن.'));
    await repo.insertMission(quick('حل تست‌های $topic', sub, 30, 2, iso, description: 'تست‌های همان مبحث را حل و پاسخ‌ها را بررسی کن.'));
    await repo.insertMission(quick('مرور اشتباهات قبلی', sub, 20, 1, iso, description: 'اشتباهات تکراری را دوباره ببین و علتشان را بنویس.'));
    await load();
  }

  Future<void> addComebackMission() async {
    await repo.insertMission(quick('بازگشت آرام: ۱۰ دقیقه مرور سبک', '', 10, 1, todayIso,
        description: 'فقط یک مبحث آسان را مرور کن. همین شروع کافی است.'));
    await load();
  }

  Future<void> deleteMission(int id) async {
    await repo.deleteMission(id);
    await load();
  }

  Future<void> moveMission(int id, DateTime to) async {
    await repo.moveMission(id, isoDay(to));
    await load();
  }

  Future<void> moveOverdueToToday() async {
    for (final m in overdue) {
      await repo.moveMission(m.id!, todayIso);
    }
    await load();
  }

  Future<void> reopenMission(int id) async {
    await repo.reopenMission(id);
    await load();
  }

  Future<CompletionResult> completeMission(Mission m, {int spentSeconds = 0}) async {
    final oldLevel = level;
    final lastBefore = lastActiveDay;
    final gap = lastBefore == null ? 0 : daysBetween(parseDay(lastBefore), today);
    final gained = await repo.completeMission(m.id!, clock(), spentSeconds: spentSeconds);
    await load();
    final fresh = await _evaluateAchievements(comeback: gap >= 3);
    return CompletionResult(gained, oldLevel, level, fresh);
  }

  // ---------- مباحث ----------
  Future<String?> addSubject(String name) async {
    final n = name.trim();
    if (n.isEmpty) return 'نام درس را وارد کن.';
    if (subjects.any((s) => s.name == n)) return 'این درس قبلاً اضافه شده است.';
    await repo.insertSubject(n);
    await load();
    return null;
  }

  Future<void> deleteSubject(int id) async {
    await repo.deleteSubject(id);
    await load();
  }

  Future<String?> saveTopic(Topic t) async {
    if (t.name.trim().isEmpty) return 'نام مبحث را وارد کن.';
    if (t.status == Mastery.mastered && t.id != null && !masteryCriteriaMet(logsOf(t.id!))) {
      return 'برای تسلط تأییدشده، دو ثبت آخر باید در دو روز متفاوت، هرکدام حداقل ۱۰ سؤال و دقت ۸۰٪ یا بیشتر داشته باشند.';
    }
    if (t.id == null) {
      await repo.insertTopic(t);
    } else {
      await repo.updateTopic(t);
    }
    await load();
    return null;
  }

  Future<void> deleteTopic(int id) async {
    await repo.deleteTopic(id);
    await load();
  }

  Future<String?> addLog(QuizLog l) async {
    if (l.total < 1) return 'تعداد سؤال باید حداقل ۱ باشد.';
    if (l.correct < 0 || l.correct > l.total) return 'تعداد پاسخ صحیح باید بین ۰ و تعداد سؤال‌ها باشد.';
    if (l.seconds != null && l.seconds! < 1) return 'زمان نامعتبر است.';
    await repo.insertLog(l);
    await load();
    await _evaluateAchievements();
    return null;
  }

  Future<void> deleteLog(int id) async {
    await repo.deleteLog(id);
    await load();
  }

  // ---------- دستاوردها ----------
  Future<List<Achievement>> _evaluateAchievements({bool comeback = false}) async {
    final ok = <String>{};
    if (completedCount >= 1) ok.add('first_mission');
    if (logs.any((l) => l.kind == 'exam' && l.total >= 10)) ok.add('first_exam');
    if (longestStreak(activeDays) >= 7) ok.add('streak7');
    for (final t in topics) {
      if (accuracyImproved(logsOf(t.id!))) ok.add('accuracy_up');
    }
    if (logs.any((l) => l.kind == 'review')) ok.add('review_done');
    if (comeback) ok.add('comeback');
    final fresh = <Achievement>[];
    for (final a in achievementDefs) {
      if (ok.contains(a.id) && !unlocked.containsKey(a.id)) {
        await repo.unlockAchievement(a.id, clock());
        fresh.add(a);
      }
    }
    if (fresh.isNotEmpty) {
      unlocked = await repo.achievements();
      notifyListeners();
    }
    return fresh;
  }

  // ---------- یادآوری‌ها ----------
  ReminderSetting reminder(String key) => ReminderSetting(
      prefs.getBool('${key}_on') ?? false,
      prefs.getInt('${key}_h') ?? (key == 'morning' ? 7 : 21),
      prefs.getInt('${key}_m') ?? 0);

  Future<void> setReminder(String key, bool on, int hour, int minute) async {
    await prefs.setBool('${key}_on', on);
    await prefs.setInt('${key}_h', hour);
    await prefs.setInt('${key}_m', minute);
    await applyReminders();
    notifyListeners();
  }

  Future<void> applyReminders() async {
    final mo = reminder('morning'), ni = reminder('night');
    if (mo.enabled) {
      await NotificationService.scheduleDaily(NotificationService.morningId, mo.hour, mo.minute, 'Get Better',
          'برنامه امروزت آماده است. مأموریت اول را شروع کن.');
    } else {
      await NotificationService.cancel(NotificationService.morningId);
    }
    if (ni.enabled) {
      await NotificationService.scheduleDaily(NotificationService.nightId, ni.hour, ni.minute, 'Get Better',
          'چند دقیقه برای برنامه‌ریزی فردا وقت بگذار.');
    } else {
      await NotificationService.cancel(NotificationService.nightId);
    }
  }

  // ---------- پشتیبان ----------
  Future<String> exportBackup() async {
    final data = await repo.exportAll();
    final exam = examDate;
    if (exam != null) data['exam_date'] = isoDay(exam);
    return const JsonEncoder.withIndent(null).convert(data);
  }

  Future<String?> importBackup(String text) async {
    try {
      final data = jsonDecode(text);
      if (data is! Map<String, dynamic>) return 'متن پشتیبان معتبر نیست.';
      await repo.importAll(data);
      final exam = data['exam_date'];
      if (exam is String && _dateRe.hasMatch(exam)) await prefs.setString(_examKey, exam);
      await load();
      return null;
    } on FormatException catch (e) {
      return e.message.isEmpty ? 'متن پشتیبان معتبر نیست.' : e.message;
    } catch (_) {
      return 'بازیابی انجام نشد؛ داده‌های فعلی تغییر نکردند.';
    }
  }

  Future<void> wipeAll() async {
    await repo.wipe();
    final keepTheme = themeMode;
    await prefs.clear();
    await prefs.setString(_themeKey, keepTheme.name);
    await NotificationService.cancel(NotificationService.morningId);
    await NotificationService.cancel(NotificationService.nightId);
    await load();
  }

  void goTab(int i) {
    tabIndex = i;
    notifyListeners();
  }

  /// رفتن به تب خانه و انتخاب بخش «امروز» (۰) یا «برنامه روزانه» (۱)
  void goHomeSub(int i) {
    tabIndex = 0;
    homeSub = i;
    notifyListeners();
  }

  // ---------- تم ----------
  Future<void> setThemeMode(ThemeMode m) async {
    final mode = m == ThemeMode.light ? ThemeMode.light : ThemeMode.dark;
    if (mode == themeMode) return;
    themeMode = mode;
    notifyListeners();
    try {
      await prefs.setString(_themeKey, mode.name);
    } catch (_) {
      // ذخیره نشدن تم نباید برنامه را مختل کند؛ تم برای همین نشست اعمال شده است.
    }
  }

  Future<void> toggleTheme() => setThemeMode(themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  // ---------- تاریخ آزمون ----------
  /// تاریخ آزمون را خود کاربر وارد می‌کند؛ تاریخ پیش‌فرض یا حدسی وجود ندارد.
  DateTime? get examDate {
    final v = prefs.getString(_examKey);
    if (v == null || !_dateRe.hasMatch(v)) return null;
    return parseDay(v);
  }

  /// تعداد روزهای مانده تا آزمون (۰ یعنی امروز، منفی یعنی گذشته)؛ بدون تاریخ null.
  int? get daysToExam {
    final d = examDate;
    return d == null ? null : daysBetween(today, d);
  }

  Future<String?> setExamDate(DateTime? d) async {
    try {
      if (d == null) {
        await prefs.remove(_examKey);
      } else {
        await prefs.setString(_examKey, isoDay(dateOnly(d)));
      }
      notifyListeners();
      return null;
    } catch (_) {
      return 'ذخیرهٔ تاریخ آزمون انجام نشد. دوباره تلاش کن.';
    }
  }

  // ---------- یادداشت‌ها ----------
  Note? noteById(int id) {
    for (final n in notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  NoteTag? tagById(int id) {
    for (final t in tags) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<Note> notesWithTag(int tagId) => notes.where((n) => n.tagIds.contains(tagId)).toList();

  /// ذخیرهٔ یادداشت جدید (بدون [id]) یا ویرایش یادداشت موجود. در صورت خطا متن پیام را برمی‌گرداند.
  Future<String?> saveNote({int? id, String title = '', String body = '', bool pinned = false, List<int> tagIds = const []}) async {
    final t = title.trim(), b = body.trim();
    if (t.isEmpty && b.isEmpty) return 'عنوان یا متن یادداشت را وارد کن.';
    final now = clock().toIso8601String();
    try {
      if (id == null) {
        await repo.insertNote(Note(title: t, body: b, createdAt: now, updatedAt: now, pinned: pinned, tagIds: tagIds));
      } else {
        final old = noteById(id);
        if (old == null) return 'این یادداشت دیگر وجود ندارد.';
        await repo.updateNote(Note(id: id, title: t, body: b, createdAt: old.createdAt, updatedAt: now, pinned: pinned, tagIds: tagIds));
      }
      await load();
      return null;
    } catch (_) {
      return 'ذخیرهٔ یادداشت انجام نشد. دوباره تلاش کن.';
    }
  }

  Future<String?> toggleNotePin(int id) async {
    final n = noteById(id);
    if (n == null) return 'این یادداشت دیگر وجود ندارد.';
    try {
      await repo.setNotePinned(id, !n.pinned);
      await load();
      return null;
    } catch (_) {
      return 'تغییر سنجاق انجام نشد. دوباره تلاش کن.';
    }
  }

  Future<String?> deleteNote(int id) async {
    try {
      await repo.deleteNote(id);
      await load();
      return null;
    } catch (_) {
      return 'حذف یادداشت انجام نشد. دوباره تلاش کن.';
    }
  }

  // ---------- برچسب‌ها ----------
  Future<String?> saveTag({int? id, required String name, required int color}) async {
    final n = name.trim();
    if (n.isEmpty) return 'نام برچسب را وارد کن.';
    if (tags.any((t) => t.id != id && t.name == n)) return 'این برچسب قبلاً ساخته شده است.';
    try {
      if (id == null) {
        await repo.insertTag(NoteTag(name: n, color: color));
      } else {
        await repo.updateTag(NoteTag(id: id, name: n, color: color));
      }
      await load();
      return null;
    } catch (_) {
      return 'ذخیرهٔ برچسب انجام نشد. دوباره تلاش کن.';
    }
  }

  /// حذف برچسب یادداشت‌های مربوط به آن را حذف نمی‌کند.
  Future<String?> deleteTag(int id) async {
    try {
      await repo.deleteTag(id);
      await load();
      return null;
    } catch (_) {
      return 'حذف برچسب انجام نشد. دوباره تلاش کن.';
    }
  }

  // ---------- اتفاقات روز ----------
  List<DayEvent> eventsOn(String iso) => dayEvents.where((e) => e.date == iso).toList();

  static final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _timeRe = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  /// ثبت اتفاق جدید (بدون [id]) یا ویرایش. اگر [date] و [time] داده نشوند، زمان فعلی استفاده می‌شود.
  Future<String?> saveDayEvent({int? id, String? title, required String body, String? date, String? time, String? icon}) async {
    final b = body.trim();
    if (b.isEmpty) return 'متن اتفاق را وارد کن.';
    final now = clock();
    final d = date ?? isoDay(dateOnly(now));
    final t = time ?? '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    if (!_dateRe.hasMatch(d)) return 'تاریخ نامعتبر است.';
    if (!_timeRe.hasMatch(t)) return 'ساعت نامعتبر است.';
    final tt = title?.trim();
    final ev = DayEvent(
      id: id,
      title: (tt == null || tt.isEmpty) ? null : tt,
      body: b,
      date: d,
      time: t,
      icon: (icon == null || icon.isEmpty) ? null : icon,
    );
    try {
      if (id == null) {
        await repo.insertDayEvent(ev);
      } else {
        await repo.updateDayEvent(ev);
      }
      await load();
      return null;
    } catch (_) {
      return 'ذخیرهٔ اتفاق انجام نشد. دوباره تلاش کن.';
    }
  }

  Future<String?> deleteDayEvent(int id) async {
    try {
      await repo.deleteDayEvent(id);
      await load();
      return null;
    } catch (_) {
      return 'حذف اتفاق انجام نشد. دوباره تلاش کن.';
    }
  }

  void selectDay(DateTime d) {
    selectedDay = dateOnly(d);
    notifyListeners();
  }
}
