import '../models/models.dart';
import '../utils/dates.dart';

/// مجموع XP لازم برای رسیدن به سطح [level] (سطح ۱ از صفر شروع می‌شود).
int xpThreshold(int level) => 50 * (level - 1) * level;

int levelForXp(int xp) {
  var l = 1;
  while (xp >= xpThreshold(l + 1)) {
    l++;
  }
  return l;
}

double levelProgress(int xp) {
  final l = levelForXp(xp);
  final lo = xpThreshold(l);
  final hi = xpThreshold(l + 1);
  return (xp - lo) / (hi - lo);
}

int xpForMission(int minutes, int priority) => (10 + minutes ~/ 5 + priority * 5).clamp(10, 100).toInt();

int longestStreak(Iterable<String> days) {
  final list = days.toSet().map(parseDay).toList()..sort();
  var best = 0, cur = 0;
  DateTime? prev;
  for (final d in list) {
    cur = (prev != null && daysBetween(prev, d) == 1) ? cur + 1 : 1;
    if (cur > best) best = cur;
    prev = d;
  }
  return best;
}

int currentStreak(Set<String> days, DateTime today) {
  var d = dateOnly(today);
  if (!days.contains(isoDay(d))) d = d.subtract(const Duration(days: 1));
  var n = 0;
  while (days.contains(isoDay(d))) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

List<QuizLog> _sorted(List<QuizLog> logs) {
  final l = [...logs];
  l.sort((a, b) {
    final c = a.date.compareTo(b.date);
    return c != 0 ? c : (a.id ?? 0).compareTo(b.id ?? 0);
  });
  return l;
}

/// معیار «تسلط تأییدشده»: دو ثبت آخر در دو روز متفاوت، هرکدام حداقل ۱۰ سؤال و دقت ≥ ۸۰٪
bool masteryCriteriaMet(List<QuizLog> logs) {
  if (logs.length < 2) return false;
  final s = _sorted(logs);
  final a = s[s.length - 1], b = s[s.length - 2];
  bool ok(QuizLog l) => l.total >= 10 && (l.accuracy ?? 0) >= 0.8;
  return ok(a) && ok(b) && a.date != b.date;
}

/// آیا در این مبحث دقت آخرین ثبت حداقل ۱۰ درصد از بهترین ثبت‌های قبلی بیشتر شده؟
bool accuracyImproved(List<QuizLog> logs) {
  final s = _sorted(logs).where((l) => l.total >= 10).toList();
  if (s.length < 2) return false;
  final last = s.last.accuracy!;
  final earlierMin = s.sublist(0, s.length - 1).map((l) => l.accuracy!).reduce((a, b) => a < b ? a : b);
  return last - earlierMin >= 0.10;
}

double? accuracyOf(Iterable<QuizLog> logs) {
  var t = 0, c = 0;
  for (final l in logs) {
    t += l.total;
    c += l.correct;
  }
  return t == 0 ? null : c / t;
}

bool isWeakTopic(Topic t, List<QuizLog> logs, String today) {
  if (t.status == Mastery.needsReview) return true;
  final acc = accuracyOf(logs);
  final enough = logs.fold<int>(0, (s, l) => s + l.total) >= 10;
  if (enough && acc != null && acc < 0.6) return true;
  if (t.nextReview != null && t.status != Mastery.notStarted && t.nextReview!.compareTo(today) <= 0) return true;
  return false;
}

class Achievement {
  final String id, title, condition;
  const Achievement(this.id, this.title, this.condition);
}

const achievementDefs = [
  Achievement('first_mission', 'اولین مأموریت', 'یک مأموریت را تکمیل کن'),
  Achievement('first_exam', 'اولین آزمون کامل', 'یک آزمون با حداقل ۱۰ سؤال ثبت کن'),
  Achievement('streak7', 'هفت روز استمرار', 'هفت روز پشت‌سرهم فعالیت ثبت کن'),
  Achievement('accuracy_up', 'بهبود دقت', 'دقت یک مبحث را دست‌کم ۱۰ درصد بالا ببر'),
  Achievement('review_done', 'تکمیل مرور', 'یک مرور برای یک مبحث ثبت کن'),
  Achievement('comeback', 'بازگشت به مسیر', 'پس از ۳ روز وقفه یک مأموریت تکمیل کن'),
];
