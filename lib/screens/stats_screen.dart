import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/logic.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final days = List.generate(7, (i) => s.today.subtract(Duration(days: 6 - i)));
    final perDay = [
      for (final d in days)
        s.missions.where((m) => m.done && m.completedAt != null && m.completedAt!.startsWith(isoDay(d))).length.toDouble()
    ];
    final prevStart = s.today.subtract(const Duration(days: 13));
    int doneBetween(DateTime a, DateTime b) => s.missions.where((m) {
          if (!m.done || m.completedAt == null) return false;
          final d = parseDay(m.completedAt!);
          return !d.isBefore(a) && !d.isAfter(b);
        }).length;
    final thisWeek = doneBetween(s.today.subtract(const Duration(days: 6)), s.today);
    final lastWeek = doneBetween(prevStart, s.today.subtract(const Duration(days: 7)));

    List<QuizLog> logsBetween(DateTime a, DateTime b) => s.logs.where((l) {
          final d = parseDay(l.date);
          return !d.isBefore(a) && !d.isAfter(b);
        }).toList();
    final accThis = accuracyOf(logsBetween(s.today.subtract(const Duration(days: 6)), s.today));
    final accLast = accuracyOf(logsBetween(prevStart, s.today.subtract(const Duration(days: 7))));

    final acc = accuracyOf(s.logs);
    final examLogs = s.logs.where((l) => l.kind == 'exam' && l.total >= 10).toList();
    final best = examLogs.isEmpty ? null : examLogs.map((l) => l.accuracy!).reduce((a, b) => a > b ? a : b);
    final paced = examLogs.where((l) => l.seconds != null).toList();
    final fastest = paced.isEmpty ? null : paced.map((l) => l.seconds! / l.total).reduce((a, b) => a < b ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('پیشرفت', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.7,
          children: [
            _Stat('XP کل', faDigits(s.totalXp), context.colors.gold),
            _Stat('سطح', faDigits(s.level), context.colors.gold),
            _Stat('مأموریت انجام‌شده', faDigits(s.completedCount), context.colors.green),
            _Stat('زمان مطالعهٔ ثبت‌شده', s.studiedSeconds == 0 ? '—' : secondsLabel(s.studiedSeconds), context.colors.text),
            _Stat('سؤال حل‌شده', faDigits(s.totalQuestions), context.colors.text),
            _Stat('دقت کل', acc == null ? '—' : '${faDigits((acc * 100).round())}٪', context.colors.green),
          ],
        ),
        const SectionTitle('فعالیت هفتگی'),
        AppCard(
          child: perDay.every((v) => v == 0)
              ? const EmptyState(icon: Icons.show_chart, message: 'برای نمایش روند، چند مأموریت را تکمیل کن.')
              : BarChart(values: perDay, labels: [for (final d in days) weekdayName(d).substring(0, 1)]),
        ),
        const SectionTitle('تغییر نسبت به هفتهٔ قبل'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lastWeek == 0 && thisWeek == 0
                ? 'هنوز داده‌ای برای مقایسه ثبت نشده است.'
                : 'مأموریت‌های انجام‌شده: ${faDigits(thisWeek)} (هفتهٔ قبل: ${faDigits(lastWeek)})'),
            const SizedBox(height: 6),
            Text(accThis == null || accLast == null
                ? 'برای مقایسهٔ دقت، در هر دو هفته چند آزمون یا تمرین ثبت کن.'
                : 'دقت: ${faDigits((accThis * 100).round())}٪ (هفتهٔ قبل: ${faDigits((accLast * 100).round())}٪)',
                style: TextStyle(color: context.colors.muted)),
          ]),
        ),
        const SectionTitle('عملکرد هر درس'),
        if (s.subjects.isEmpty || s.logs.isEmpty)
          const AppCard(child: EmptyState(icon: Icons.insights, message: 'برای نمایش عملکرد درس‌ها، چند آزمون یا تمرین ثبت کن.'))
        else
          for (final sub in s.subjects)
            Builder(builder: (_) {
              final l = s.topics.where((t) => t.subjectId == sub.id).expand((t) => s.logsOf(t.id!));
              final a = accuracyOf(l);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(sub.name)),
                      Text(a == null ? 'بدون داده' : '${faDigits((a * 100).round())}٪', style: TextStyle(color: context.colors.muted)),
                    ]),
                    const SizedBox(height: 8),
                    AnimatedBar(value: a ?? 0, color: context.colors.green, height: 8),
                  ]),
                ),
              );
            }),
        const SectionTitle('مباحث نیازمند مرور'),
        if (s.weakTopics.isEmpty)
          AppCard(child: Text('فعلاً مبحثی در صف مرور نیست.', style: TextStyle(color: context.colors.muted)))
        else
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final t in s.weakTopics) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('• ${t.name}'))])),
        const SectionTitle('رکوردهای شخصی'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _rec(context, 'پاسخ‌های صحیح', faDigits(s.totalCorrect)),
            _rec(context, 'بهترین دقت آزمون (حداقل ۱۰ سؤال)', best == null ? '—' : '${faDigits((best * 100).round())}٪'),
            _rec(context, 'سریع‌ترین سرعت آزمون', fastest == null ? '—' : '${faDigits(fastest.round())} ثانیه برای هر سؤال'),
            _rec(context, 'روزهای فعال', faDigits(s.activeDays.length)),
            _rec(context, 'استمرار فعلی', '${faDigits(currentStreak(s.activeDays, s.today))} روز'),
            _rec(context, 'مباحث با تسلط تأییدشده', faDigits(s.masteredCount)),
            const SizedBox(height: 6),
            Text('سرعت و دقت فقط از ثبت‌های «آزمون» حساب می‌شود. بین آزمون‌هایی با تعداد سؤال و سختی متفاوت، مقایسه دقیق نیست.',
                style: TextStyle(color: context.colors.muted, fontSize: 11, height: 1.7)),
          ]),
        ),
        const SectionTitle('دستاوردها'),
        for (final a in achievementDefs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: Row(children: [
                Icon(s.unlocked.containsKey(a.id) ? Icons.emoji_events : Icons.lock_outline, color: s.unlocked.containsKey(a.id) ? context.colors.gold : context.colors.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.title, style: TextStyle(fontWeight: FontWeight.w600, color: s.unlocked.containsKey(a.id) ? context.colors.text : context.colors.muted)),
                    Text(
                      s.unlocked.containsKey(a.id) ? 'دریافت در ${jalaliLabel(parseDay(s.unlocked[a.id]!))}' : a.condition,
                      style: TextStyle(color: context.colors.muted, fontSize: 12),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _rec(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [Expanded(child: Text(k, style: TextStyle(color: context.colors.muted))), Text(v)]),
      );
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: TextStyle(color: context.colors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800))),
        ]),
      );
}
