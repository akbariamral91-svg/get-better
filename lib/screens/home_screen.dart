import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final today = s.todayMissions;
    final done = today.where((m) => m.done).length;
    final frac = today.isEmpty ? 0.0 : done / today.length;
    final next = s.nextMission;
    final top = today.take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (s.comebackMode) _ComebackCard(s),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: context.colors.gold.withOpacity(0.15), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(faDigits(s.level), style: TextStyle(color: context.colors.gold, fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('سطح ${faDigits(s.level)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('${faDigits(s.totalXp)} XP', style: TextStyle(color: context.colors.gold)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            AnimatedBar(value: s.levelFraction),
            const SizedBox(height: 6),
            Text('تا سطح بعد: ${faDigits(_toNext(s))} XP', style: TextStyle(color: context.colors.muted, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          color: context.colors.card2,
          child: next == null
              ? EmptyState(
                  icon: Icons.add_task,
                  message: today.isEmpty ? 'برای امروز مأموریتی نداری.' : 'همهٔ مأموریت‌های امروز انجام شد. آفرین!',
                  action: today.isEmpty
                      ? FilledButton(onPressed: () => s.addDefaultMissions(s.todayIso), child: const Text('افزودن سه مأموریت پیشنهادی'))
                      : null,
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('مأموریت بعدی', style: TextStyle(color: context.colors.muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(next.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    if (next.subject.isNotEmpty) Pill(next.subject, color: context.colors.muted),
                    Pill(minutesLabel(next.minutes), icon: Icons.timer_outlined),
                    Pill('${faDigits(next.xp)} XP', color: context.colors.gold),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('شروع مأموریت'),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FocusScreen(mission: next))),
                    ),
                  ),
                ]),
        ),
        SectionTitle('امروز', trailing: Text('${faDigits((frac * 100).round())}٪ تکمیل', style: TextStyle(color: context.colors.green))),
        AnimatedBar(value: frac, color: context.colors.green),
        const SizedBox(height: 12),
        if (top.isEmpty)
          AppCard(child: Text('هنوز مأموریتی برای امروز نداری. از بخش «برنامه روزانه» اضافه کن.', style: TextStyle(color: context.colors.muted)))
        else
          for (final m in top)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Icon(m.done ? Icons.check_circle : Icons.radio_button_unchecked, color: m.done ? context.colors.green : context.colors.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(m.title,
                        style: TextStyle(decoration: m.done ? TextDecoration.lineThrough : null, color: m.done ? context.colors.muted : context.colors.text)),
                  ),
                  Text('${faDigits(m.xp)} XP', style: TextStyle(color: context.colors.gold, fontSize: 12)),
                ]),
              ),
            ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => s.goHomeSub(1), icon: const Icon(Icons.calendar_month), label: const Text('برنامه روزانه'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: () => s.goTab(1), icon: const Icon(Icons.bar_chart), label: const Text('گزارش پیشرفت'))),
        ]),
        SectionTitle('پایان روز'),
        AppCard(
          onTap: () => _report(context, s),
          child: Row(children: [
            Icon(Icons.nights_stay_outlined, color: context.colors.gold),
            SizedBox(width: 12),
            Expanded(child: Text('گزارش پایان روز و آماده‌سازی برنامه فردا')),
            Icon(Icons.chevron_left, color: context.colors.muted),
          ]),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Row(children: [
            Icon(Icons.flag, color: context.colors.gold),
            SizedBox(width: 12),
            Expanded(child: Text('هدف نهایی: قبولی در مدرسه نمونه دولتی', style: TextStyle(fontWeight: FontWeight.w600))),
          ]),
        ),
      ],
    );
  }

  int _toNext(AppState s) {
    final hi = 50 * s.level * (s.level + 1);
    return hi - s.totalXp;
  }

  void _report(BuildContext context, AppState s) {
    final today = s.todayMissions;
    final done = today.where((m) => m.done).length;
    final mins = today.where((m) => m.done).fold<int>(0, (a, m) => a + m.minutes);
    final tomorrow = s.missionsOn(isoDay(s.today.add(const Duration(days: 1)))).length;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('گزارش امروز', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Text('مأموریت انجام‌شده: ${faDigits(done)} از ${faDigits(today.length)}'),
          const SizedBox(height: 6),
          Text('زمان برنامه‌ریزی‌شدهٔ انجام‌شده: ${minutesLabel(mins)}'),
          const SizedBox(height: 6),
          Text('XP امروز: ${faDigits(s.xpOnDay(s.todayIso))}'),
          const SizedBox(height: 6),
          Text(tomorrow == 0 ? 'برای فردا هنوز برنامه‌ای نداری.' : 'مأموریت‌های فردا: ${faDigits(tomorrow)}'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                s.selectDay(s.today.add(const Duration(days: 1)));
                s.goHomeSub(1);
              },
              child: const Text('برنامه‌ریزی فردا'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ComebackCard extends StatelessWidget {
  final AppState s;
  const _ComebackCard(this.s);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          color: context.colors.card2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('خوش برگشتی', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${faDigits(s.daysSinceActive)} روز از آخرین فعالیتت گذشته. امتیازهایت سر جایشان هستند. '
                'برای شروع دوباره، فقط یک مأموریت کوتاه ۱۰ دقیقه‌ای کافی است.',
                style: TextStyle(color: context.colors.muted, height: 1.7)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await s.addComebackMission();
                if (context.mounted) toast(context, 'مأموریت کوتاه به امروز اضافه شد.');
              },
              child: const Text('افزودن مأموریت بازگشت'),
            ),
          ]),
        ),
      );
}

/// صفحهٔ اجرای مأموریت با زمان‌سنج
class FocusScreen extends StatefulWidget {
  final Mission mission;
  const FocusScreen({super.key, required this.mission});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final _sw = Stopwatch()..start();
  Timer? _t;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String get _clock {
    final s = _sw.elapsed.inSeconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return faDigits('$m:$r');
  }

  Future<void> _finish() async {
    if (_busy) return; // جلوگیری از لمس مکرر
    setState(() => _busy = true);
    final s = context.read<AppState>();
    final nav = Navigator.of(context);
    final res = await s.completeMission(widget.mission, spentSeconds: _sw.elapsed.inSeconds);
    nav.pop();
    if (nav.context.mounted) await showCompletion(nav.context, res);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mission;
    return Scaffold(
      appBar: AppBar(title: const Text('مأموریت در حال انجام')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (m.description.isNotEmpty) Text(m.description, style: TextStyle(color: context.colors.muted, height: 1.8)),
          const Spacer(),
          Center(child: Text(_clock, style: TextStyle(fontSize: 56, fontWeight: FontWeight.w300, color: context.colors.gold))),
          Center(child: Text('زمان پیشنهادی: ${minutesLabel(m.minutes)}', style: TextStyle(color: context.colors.muted))),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _finish,
              icon: const Icon(Icons.check),
              label: const Text('پایان و ثبت مأموریت'),
            ),
          ),
        ]),
      ),
    );
  }
}
