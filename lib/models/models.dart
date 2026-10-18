enum Mastery { notStarted, learning, needsReview, mastered }

const masteryLabels = {
  Mastery.notStarted: 'شروع‌نشده',
  Mastery.learning: 'در حال یادگیری',
  Mastery.needsReview: 'نیازمند مرور',
  Mastery.mastered: 'تسلط تأییدشده',
};

const priorityLabels = ['کم', 'متوسط', 'زیاد'];
const logKinds = {'practice': 'تمرین', 'exam': 'آزمون', 'review': 'مرور'};

class Mission {
  final int? id;
  final String title, subject, description, note, date;
  final int minutes, priority, xp, spentSeconds;
  final bool done;
  final String? completedAt;
  /// کلید آیکون اختیاری (نگاه کنید به app_icons.dart)
  final String? icon;

  const Mission({
    this.id,
    required this.title,
    this.subject = '',
    this.description = '',
    this.note = '',
    required this.date,
    this.minutes = 30,
    this.priority = 1,
    required this.xp,
    this.spentSeconds = 0,
    this.done = false,
    this.completedAt,
    this.icon,
  });

  Mission copyWith({
    String? title, String? subject, String? description, String? note, String? date,
    int? minutes, int? priority, int? xp, String? icon, bool clearIcon = false,
  }) =>
      Mission(
        id: id,
        title: title ?? this.title,
        subject: subject ?? this.subject,
        description: description ?? this.description,
        note: note ?? this.note,
        date: date ?? this.date,
        minutes: minutes ?? this.minutes,
        priority: priority ?? this.priority,
        xp: xp ?? this.xp,
        spentSeconds: spentSeconds,
        done: done,
        completedAt: completedAt,
        icon: clearIcon ? null : (icon ?? this.icon),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'subject': subject,
        'description': description,
        'minutes': minutes,
        'priority': priority,
        'done': done ? 1 : 0,
        'xp': xp,
        'date': date,
        'note': note,
        'spent_seconds': spentSeconds,
        'completed_at': completedAt,
        'icon': icon,
      };

  factory Mission.fromMap(Map<String, Object?> m) => Mission(
        id: m['id'] as int?,
        title: m['title'] as String,
        subject: (m['subject'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        minutes: (m['minutes'] as int?) ?? 30,
        priority: (m['priority'] as int?) ?? 1,
        done: (m['done'] as int?) == 1,
        xp: (m['xp'] as int?) ?? 10,
        date: m['date'] as String,
        note: (m['note'] as String?) ?? '',
        spentSeconds: (m['spent_seconds'] as int?) ?? 0,
        completedAt: m['completed_at'] as String?,
        icon: m['icon'] as String?,
      );
}

class Subject {
  final int? id;
  final String name;
  const Subject({this.id, required this.name});
  factory Subject.fromMap(Map<String, Object?> m) => Subject(id: m['id'] as int?, name: m['name'] as String);
}

class Topic {
  final int? id;
  final int subjectId;
  final String chapter, name, notes, mistakes;
  final Mastery status;
  final String? nextReview;

  const Topic({
    this.id,
    required this.subjectId,
    this.chapter = '',
    required this.name,
    this.notes = '',
    this.mistakes = '',
    this.status = Mastery.notStarted,
    this.nextReview,
  });

  Topic copyWith({String? chapter, String? name, String? notes, String? mistakes, Mastery? status, String? nextReview, bool clearReview = false}) =>
      Topic(
        id: id,
        subjectId: subjectId,
        chapter: chapter ?? this.chapter,
        name: name ?? this.name,
        notes: notes ?? this.notes,
        mistakes: mistakes ?? this.mistakes,
        status: status ?? this.status,
        nextReview: clearReview ? null : (nextReview ?? this.nextReview),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'subject_id': subjectId,
        'chapter': chapter,
        'name': name,
        'notes': notes,
        'mistakes': mistakes,
        'status': status.index,
        'next_review': nextReview,
      };

  factory Topic.fromMap(Map<String, Object?> m) => Topic(
        id: m['id'] as int?,
        subjectId: m['subject_id'] as int,
        chapter: (m['chapter'] as String?) ?? '',
        name: m['name'] as String,
        notes: (m['notes'] as String?) ?? '',
        mistakes: (m['mistakes'] as String?) ?? '',
        status: Mastery.values[((m['status'] as int?) ?? 0).clamp(0, 3).toInt()],
        nextReview: m['next_review'] as String?,
      );
}

class QuizLog {
  final int? id;
  final int topicId;
  final String kind, date, note;
  final int total, correct;
  final int? seconds;

  const QuizLog({
    this.id,
    required this.topicId,
    required this.kind,
    required this.total,
    required this.correct,
    this.seconds,
    required this.date,
    this.note = '',
  });

  int get wrong => total - correct;
  double? get accuracy => total == 0 ? null : correct / total;

  Map<String, Object?> toMap() => {
        'id': id,
        'topic_id': topicId,
        'kind': kind,
        'total': total,
        'correct': correct,
        'seconds': seconds,
        'date': date,
        'note': note,
      };

  factory QuizLog.fromMap(Map<String, Object?> m) => QuizLog(
        id: m['id'] as int?,
        topicId: m['topic_id'] as int,
        kind: m['kind'] as String,
        total: m['total'] as int,
        correct: m['correct'] as int,
        seconds: m['seconds'] as int?,
        date: m['date'] as String,
        note: (m['note'] as String?) ?? '',
      );
}

/// یادداشت متنی. تاریخ‌ها به‌صورت متن ISO 8601 ذخیره می‌شوند (مثل بقیهٔ مدل‌ها).
class Note {
  final int? id;
  final String title, body, createdAt, updatedAt;
  final bool pinned;
  final List<int> tagIds;

  const Note({
    this.id,
    this.title = '',
    this.body = '',
    required this.createdAt,
    required this.updatedAt,
    this.pinned = false,
    this.tagIds = const [],
  });

  /// عنوان نمایشی: اگر عنوان خالی باشد، خط اول متن
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final first = body.trim().split('\n').first;
    return first.length > 60 ? '${first.substring(0, 60)}…' : first;
  }

  Note copyWith({String? title, String? body, String? updatedAt, bool? pinned, List<int>? tagIds}) => Note(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        pinned: pinned ?? this.pinned,
        tagIds: tagIds ?? this.tagIds,
      );

  /// برچسب‌ها در جدول رابط (note_tags) ذخیره می‌شوند، نه در این نقشه.
  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'pinned': pinned ? 1 : 0,
      };

  factory Note.fromMap(Map<String, Object?> m, {List<int> tagIds = const []}) => Note(
        id: m['id'] as int?,
        title: (m['title'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        createdAt: m['created_at'] as String,
        updatedAt: m['updated_at'] as String,
        pinned: (m['pinned'] as int?) == 1,
        tagIds: tagIds,
      );
}

/// برچسب قابل‌ساخت توسط کاربر. [color] مقدار ARGB رنگ (Color.value) است.
class NoteTag {
  final int? id;
  final String name;
  final int color;
  const NoteTag({this.id, required this.name, required this.color});

  NoteTag copyWith({String? name, int? color}) => NoteTag(id: id, name: name ?? this.name, color: color ?? this.color);

  Map<String, Object?> toMap() => {'id': id, 'name': name, 'color': color};

  factory NoteTag.fromMap(Map<String, Object?> m) =>
      NoteTag(id: m['id'] as int?, name: m['name'] as String, color: (m['color'] as int?) ?? 0xFF8E9AC0);
}

/// یک اتفاق یا چیز جالب روز. در هر روز می‌توان چند اتفاق ثبت کرد.
/// [date] به‌شکل yyyy-MM-dd و [time] به‌شکل HH:mm است؛ [title] و [icon] اختیاری‌اند.
class DayEvent {
  final int? id;
  final String? title;
  final String body, date, time;
  final String? icon;

  const DayEvent({this.id, this.title, required this.body, required this.date, required this.time, this.icon});

  DayEvent copyWith({String? title, String? body, String? date, String? time, String? icon, bool clearTitle = false, bool clearIcon = false}) =>
      DayEvent(
        id: id,
        title: clearTitle ? null : (title ?? this.title),
        body: body ?? this.body,
        date: date ?? this.date,
        time: time ?? this.time,
        icon: clearIcon ? null : (icon ?? this.icon),
      );

  Map<String, Object?> toMap() => {'id': id, 'title': title, 'body': body, 'date': date, 'time': time, 'icon': icon};

  factory DayEvent.fromMap(Map<String, Object?> m) => DayEvent(
        id: m['id'] as int?,
        title: m['title'] as String?,
        body: (m['body'] as String?) ?? '',
        date: m['date'] as String,
        time: (m['time'] as String?) ?? '00:00',
        icon: m['icon'] as String?,
      );
}
