import 'package:flutter_test/flutter_test.dart';
import 'package:masir_ghabuli/models/models.dart';
import 'package:masir_ghabuli/services/logic.dart';
import 'package:masir_ghabuli/utils/dates.dart';

QuizLog log(String date, int total, int correct, {int id = 0}) =>
    QuizLog(id: id, topicId: 1, kind: 'practice', total: total, correct: correct, date: date);

void main() {
  test('سطح و XP', () {
    expect(levelForXp(0), 1);
    expect(levelForXp(99), 1);
    expect(levelForXp(100), 2);
    expect(levelForXp(299), 2);
    expect(levelForXp(300), 3);
    expect(levelProgress(50), closeTo(0.5, 1e-9));
    expect(xpForMission(30, 1), 21);
    expect(xpForMission(1000, 2), 100);
  });

  test('استمرار', () {
    expect(longestStreak(['2026-10-01', '2026-10-02', '2026-10-03', '2026-10-05']), 3);
    expect(longestStreak([]), 0);
    final days = {'2026-10-16', '2026-10-15'};
    expect(currentStreak(days, DateTime(2026, 10, 17)), 2);
    expect(currentStreak(days, DateTime(2026, 10, 19)), 0);
  });

  test('معیار تسلط', () {
    expect(masteryCriteriaMet([log('2026-10-01', 10, 9)]), false);
    expect(masteryCriteriaMet([log('2026-10-01', 10, 9, id: 1), log('2026-10-02', 12, 10, id: 2)]), true);
    expect(masteryCriteriaMet([log('2026-10-01', 10, 9, id: 1), log('2026-10-01', 12, 10, id: 2)]), false); // یک روز
    expect(masteryCriteriaMet([log('2026-10-01', 10, 9, id: 1), log('2026-10-02', 5, 5, id: 2)]), false); // کم‌سؤال
    expect(masteryCriteriaMet([log('2026-10-01', 10, 9, id: 1), log('2026-10-02', 10, 5, id: 2)]), false); // دقت پایین
  });

  test('بهبود دقت', () {
    expect(accuracyImproved([log('2026-10-01', 10, 5, id: 1), log('2026-10-05', 10, 7, id: 2)]), true);
    expect(accuracyImproved([log('2026-10-01', 10, 5, id: 1), log('2026-10-05', 10, 5, id: 2)]), false);
  });

  test('تاریخ شمسی', () {
    expect(toJalali(2024, 3, 20), [1403, 1, 1]);
    expect(toJalali(2026, 3, 21), [1405, 1, 1]);
    expect(toJalali(2026, 10, 17), [1405, 7, 25]);
    expect(faDigits(1405), '۱۴۰۵');
    expect(daysBetween(DateTime(2026, 10, 1), DateTime(2026, 10, 17)), 16);
  });
}
