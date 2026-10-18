import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/logic.dart';
import '../theme/app_theme.dart';
import '../utils/app_icons.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';

class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final days = List.generate(7, (i) => s.today.add(Duration(days: i)));
    final sel = isoDay(s.selectedDay);
    final list = s.missionsOn(sel);
    final overdue = s.overdue;
    final isToday = sel == s.todayIso;
    final isTomorrow = sel == isoDay(s.today.add(const Duration(days: 1)));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: context.colors.gold,
        foregroundColor: context.colors.bg,
        onPressed: () => openMissionForm(context, date: s.selectedDay),
        icon: const Icon(Icons.add),
        label: const Text('مأموریت جدید'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        children: [
          const Text('برنامه', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = days[i];
                final on = isoDay(d) == sel;
                final cnt = s.missionsOn(isoDay(d)).length;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => s.selectDay(d),
                  child: Container(
                    width: 64,
                    decoration: BoxDecoration(color: on ? context.colors.gold : context.colors.card, borderRadius: BorderRadius.circular(14)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(i == 0 ? 'امروز' : weekdayName(d), style: TextStyle(fontSize: 11, color: on ? context.colors.bg : context.colors.muted)),
                      const SizedBox(height: 2),
                      Text(faDigits(toJalali(d.year, d.month, d.day)[2]),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: on ? context.colors.bg : context.colors.text)),
                      Text(cnt == 0 ? '—' : '${faDigits(cnt)} کار', style: TextStyle(fontSize: 10, color: on ? context.colors.bg : context.colors.muted)),
                    ]),
                  ),
                );
              },
            ),
          ),
          if (overdue.isNotEmpty && isToday) ...[
            const SizedBox(height: 14),
            AppCard(
              color: context.colors.card2,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${faDigits(overdue.length)} مأموریت از روزهای قبل انجام نشده است.', style: const TextStyle(height: 1.6)),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () async {
                      final ok = await confirm(context, 'انتقال به امروز', 'همهٔ مأموریت‌های انجام‌نشدهٔ قبلی به امروز منتقل شوند؟ می‌توانی بعداً هرکدام را جداگانه جابه‌جا کنی.');
                      if (ok) await s.moveOverdueToToday();
                    },
                    child: const Text('انتقال به امروز'),
                  ),
                ),
              ]),
            ),
          ],
          SectionTitle('${isToday ? 'امروز' : isTomorrow ? 'فردا' : weekdayName(s.selectedDay)} · ${jalaliLabel(s.selectedDay)}'),
          if (list.isEmpty)
            AppCard(
              child: EmptyState(
                icon: Icons.event_available_outlined,
                message: isTomorrow ? 'برنامه فردا را همین حالا بچین تا صبح مجبور به تصمیم‌گیری نباشی.' : 'برای این روز مأموریتی ثبت نشده است.',
                action: FilledButton(onPressed: () => s.addDefaultMissions(sel), child: const Text('افزودن سه مأموریت پیشنهادی')),
              ),
            )
          else
            for (final m in list) _MissionTile(m),
        ],
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  final Mission m;
  const _MissionTile(this.m);

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(6, 10, 4, 10),
        onTap: () => openMissionForm(context, mission: m),
        child: Row(children: [
          IconButton(
            tooltip: m.done ? 'بازگرداندن' : 'تکمیل',
            icon: Icon(m.done ? Icons.check_circle : Icons.radio_button_unchecked, color: m.done ? context.colors.green : context.colors.muted, size: 28),
            onPressed: () async {
              if (m.done) {
                await s.reopenMission(m.id!);
              } else {
                final r = await s.completeMission(m);
                if (context.mounted) await showCompletion(context, r);
              }
            },
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (iconFor(m.icon) != null) ...[
                  Icon(iconFor(m.icon), size: 18, color: m.done ? context.colors.muted : context.colors.gold),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(m.title,
                      style: TextStyle(fontWeight: FontWeight.w600, decoration: m.done ? TextDecoration.lineThrough : null, color: m.done ? context.colors.muted : context.colors.text)),
                ),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (m.subject.isNotEmpty) Pill(m.subject),
                Pill(minutesLabel(m.minutes), icon: Icons.timer_outlined),
                Pill('اولویت ${priorityLabels[m.priority]}', color: m.priority == 2 ? context.colors.red : context.colors.muted),
                Pill('${faDigits(m.xp)} XP', color: context.colors.gold),
              ]),
            ]),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                openMissionForm(context, mission: m);
              } else if (v == 'move') {
                final d = await showDatePicker(
                  context: context,
                  initialDate: parseDay(m.date).isBefore(s.today) ? s.today : parseDay(m.date),
                  firstDate: s.today,
                  lastDate: s.today.add(const Duration(days: 365)),
                );
                if (d != null) await s.moveMission(m.id!, d);
              } else if (v == 'delete') {
                final ok = await confirm(context, 'حذف مأموریت', 'این مأموریت حذف شود؟ امتیازی که قبلاً گرفته‌ای حفظ می‌شود.', ok: 'حذف');
                if (ok) await s.deleteMission(m.id!);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
              if (!m.done) const PopupMenuItem(value: 'move', child: Text('انتقال به روز دیگر')),
              const PopupMenuItem(value: 'delete', child: Text('حذف')),
            ],
          ),
        ]),
      ),
    );
  }
}

Future<void> openMissionForm(BuildContext context, {Mission? mission, DateTime? date}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<AppState>(),
      child: _MissionForm(mission: mission, date: date),
    ),
  );
}

class _MissionForm extends StatefulWidget {
  final Mission? mission;
  final DateTime? date;
  const _MissionForm({this.mission, this.date});
  @override
  State<_MissionForm> createState() => _MissionFormState();
}

class _MissionFormState extends State<_MissionForm> {
  final _key = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.mission?.title ?? '');
  late final _desc = TextEditingController(text: widget.mission?.description ?? '');
  late final _subject = TextEditingController(text: widget.mission?.subject ?? '');
  late final _minutes = TextEditingController(text: faDigits(widget.mission?.minutes ?? 30));
  late final _note = TextEditingController(text: widget.mission?.note ?? '');
  late int _priority = widget.mission?.priority ?? 1;
  late String? _icon = widget.mission?.icon;
  late DateTime _date = widget.mission != null ? parseDay(widget.mission!.date) : (widget.date ?? DateTime.now());
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _desc, _subject, _minutes, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _parseInt(String t) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    var s = t.trim();
    for (var i = 0; i < 10; i++) {
      s = s.replaceAll(fa[i], '$i');
    }
    return int.tryParse(s);
  }

  Future<void> _save() async {
    if (_saving || !_key.currentState!.validate()) return;
    setState(() => _saving = true);
    final s = context.read<AppState>();
    final min = _parseInt(_minutes.text)!;
    final base = widget.mission;
    final m = Mission(
      id: base?.id,
      title: _title.text.trim(),
      subject: _subject.text.trim(),
      description: _desc.text.trim(),
      note: _note.text.trim(),
      date: isoDay(_date),
      minutes: min,
      priority: _priority,
      xp: xpForMission(min, _priority),
      spentSeconds: base?.spentSeconds ?? 0,
      done: base?.done ?? false,
      completedAt: base?.completedAt,
      icon: _icon,
    );
    final err = await s.saveMission(m);
    if (!mounted) return;
    if (err != null) {
      setState(() => _saving = false);
      toast(context, err);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = context.read<AppState>().subjects;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.mission == null ? 'مأموریت جدید' : 'ویرایش مأموریت', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'عنوان'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'عنوان را وارد کن' : null,
            ),
            const SizedBox(height: 10),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _subject.text),
              optionsBuilder: (v) => subjects.map((e) => e.name).where((n) => n.contains(v.text)),
              onSelected: (v) => _subject.text = v,
              fieldViewBuilder: (_, c, f, __) => TextFormField(
                controller: c,
                focusNode: f,
                onChanged: (v) => _subject.text = v,
                decoration: const InputDecoration(labelText: 'درس یا حوزه'),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'توضیح')),
            const SizedBox(height: 10),
            TextFormField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'زمان تخمینی (دقیقه)'),
              validator: (v) {
                final n = _parseInt(v ?? '');
                if (n == null) return 'یک عدد وارد کن';
                if (n < 1 || n > 480) return 'عدد بین ۱ تا ۴۸۰ وارد کن';
                return null;
              },
            ),
            const SizedBox(height: 10),
            IconPickerField(group: IconGroup.tasks, value: _icon, onChanged: (v) => setState(() => _icon = v)),
            const SizedBox(height: 12),
            Text('اولویت', style: TextStyle(color: context.colors.muted)),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: [for (var i = 0; i < 3; i++) ButtonSegment(value: i, label: Text(priorityLabels[i]))],
              selected: {_priority},
              onSelectionChanged: (v) => setState(() => _priority = v.first),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text('تاریخ: ${weekdayName(_date)} ${jalaliLabel(_date)}'),
              onPressed: () async {
                final today = dateOnly(DateTime.now());
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date.isBefore(today) ? today : _date,
                  firstDate: today.subtract(const Duration(days: 30)),
                  lastDate: today.add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 10),
            TextFormField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'یادداشت یا نتیجه (اختیاری)')),
            const SizedBox(height: 8),
            Text('XP این مأموریت: ${faDigits(xpForMission(_parseInt(_minutes.text) ?? 30, _priority))} (بر اساس زمان و اولویت)',
                style: TextStyle(color: context.colors.gold, fontSize: 12)),
            const SizedBox(height: 14),
            FilledButton(onPressed: _saving ? null : _save, child: const Text('ذخیره')),
          ]),
        ),
      ),
    );
  }
}
