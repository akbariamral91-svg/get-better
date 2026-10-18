import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/logic.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';

Color masteryColor(BuildContext context, Mastery m) {
  final c = context.colors;
  return switch (m) {
    Mastery.notStarted => c.muted,
    Mastery.learning => c.gold,
    Mastery.needsReview => c.red,
    Mastery.mastered => c.green,
  };
}

Future<String?> _ask(BuildContext context, String title, String label) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: label)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        TextButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('ذخیره')),
      ],
    ),
  );
}

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final weak = s.weakTopics;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: context.colors.gold,
        foregroundColor: context.colors.bg,
        icon: const Icon(Icons.add),
        label: const Text('درس جدید'),
        onPressed: () async {
          final name = await _ask(context, 'درس جدید', 'نام درس');
          if (name == null || !context.mounted) return;
          final err = await s.addSubject(name);
          if (err != null && context.mounted) toast(context, err);
        },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        children: [
          const Text('مسیر یادگیری', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('درس ← فصل ← مبحث ← تمرین ← آزمون ← مرور', style: TextStyle(color: context.colors.muted, fontSize: 12)),
          if (weak.isNotEmpty) ...[
            const SectionTitle('اولویت مرور'),
            for (final t in weak.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TopicScreen(topicId: t.id!))),
                  child: Row(children: [
                    Icon(Icons.priority_high, color: context.colors.red),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t.name)),
                    Pill(s.subjectOf(t.subjectId)?.name ?? ''),
                  ]),
                ),
              ),
          ],
          const SectionTitle('درس‌ها'),
          if (s.subjects.isEmpty)
            const AppCard(child: EmptyState(icon: Icons.menu_book_outlined, message: 'هنوز درسی اضافه نکرده‌ای. با دکمهٔ «درس جدید» شروع کن.'))
          else
            for (final sub in s.subjects) _SubjectCard(sub),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject sub;
  const _SubjectCard(this.sub);
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final topics = s.topics.where((t) => t.subjectId == sub.id).toList();
    final chapters = <String>{for (final t in topics) t.chapter};
    final acc = accuracyOf(topics.expand((t) => s.logsOf(t.id!)));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              '${faDigits(topics.length)} مبحث · ${acc == null ? 'بدون داده دقت' : 'دقت ${faDigits((acc * 100).round())}٪'}',
              style: TextStyle(color: context.colors.muted, fontSize: 12),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              if (topics.isEmpty)
                Padding(padding: EdgeInsets.all(8), child: Text('مبحثی ثبت نشده است.', style: TextStyle(color: context.colors.muted))),
              for (final ch in chapters) ...[
                if (ch.isNotEmpty)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(ch, style: TextStyle(color: context.colors.gold, fontSize: 13))),
                  ),
                for (final t in topics.where((t) => t.chapter == ch))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.name),
                    trailing: Pill(masteryLabels[t.status]!, color: masteryColor(context, t.status)),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TopicScreen(topicId: t.id!))),
                  ),
              ],
              Row(children: [
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('مبحث جدید'),
                  onPressed: () => _addTopic(context, s),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'حذف درس',
                  icon: Icon(Icons.delete_outline, color: context.colors.muted),
                  onPressed: () async {
                    final ok = await confirm(context, 'حذف درس', 'درس «${sub.name}» با همهٔ مباحث و ثبت‌های آزمونش حذف شود؟', ok: 'حذف');
                    if (ok) await s.deleteSubject(sub.id!);
                  },
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addTopic(BuildContext context, AppState s) async {
    final chapter = TextEditingController(), name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مبحث جدید'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: chapter, decoration: const InputDecoration(labelText: 'فصل (اختیاری)')),
          const SizedBox(height: 10),
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'نام مبحث')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ذخیره')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await s.saveTopic(Topic(subjectId: sub.id!, chapter: chapter.text.trim(), name: name.text.trim()));
    if (err != null && context.mounted) toast(context, err);
  }
}

class TopicScreen extends StatefulWidget {
  final int topicId;
  const TopicScreen({super.key, required this.topicId});
  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  TextEditingController? _notes, _mistakes;

  @override
  void dispose() {
    _notes?.dispose();
    _mistakes?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final idx = s.topics.indexWhere((t) => t.id == widget.topicId);
    if (idx < 0) return const Scaffold(body: Center(child: Text('این مبحث وجود ندارد.')));
    final t = s.topics[idx];
    _notes ??= TextEditingController(text: t.notes);
    _mistakes ??= TextEditingController(text: t.mistakes);
    final logs = s.logsOf(t.id!);
    final acc = accuracyOf(logs);
    final canMaster = masteryCriteriaMet(logs);

    Future<void> save(Topic n) async {
      final err = await s.saveTopic(n);
      if (err != null && context.mounted) toast(context, err);
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.name), actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final nav = Navigator.of(context);
            final ok = await confirm(context, 'حذف مبحث', 'این مبحث و ثبت‌هایش حذف شود؟', ok: 'حذف');
            if (ok) {
              await s.deleteTopic(t.id!);
              nav.pop();
            }
          },
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('دقت کل: ${acc == null ? 'هنوز داده‌ای ثبت نشده' : '${faDigits((acc * 100).round())}٪'}'),
            const SizedBox(height: 4),
            Text('${faDigits(logs.fold<int>(0, (a, l) => a + l.total))} سؤال · ${faDigits(logs.fold<int>(0, (a, l) => a + l.correct))} صحیح · ${faDigits(logs.fold<int>(0, (a, l) => a + l.wrong))} غلط',
                style: TextStyle(color: context.colors.muted, fontSize: 12)),
            const SizedBox(height: 12),
            Text('وضعیت تسلط', style: TextStyle(color: context.colors.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in Mastery.values)
                ChoiceChip(
                  label: Text(masteryLabels[m]!),
                  selected: t.status == m,
                  onSelected: (m == Mastery.mastered && !canMaster)
                      ? null
                      : (_) => save(t.copyWith(status: m)),
                ),
            ]),
            if (!canMaster)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('«تسلط تأییدشده» وقتی فعال می‌شود که دو ثبت آخر، در دو روز متفاوت، هرکدام حداقل ۱۰ سؤال و دقت ۸۰٪ یا بیشتر داشته باشند.',
                    style: TextStyle(color: context.colors.muted, fontSize: 12, height: 1.7)),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Row(children: [
            Icon(Icons.event_repeat, color: context.colors.gold),
            const SizedBox(width: 10),
            Expanded(child: Text(t.nextReview == null ? 'زمان مرور بعدی تعیین نشده' : 'مرور بعدی: ${jalaliLabel(parseDay(t.nextReview!))}')),
            TextButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: s.today.add(const Duration(days: 3)),
                  firstDate: s.today,
                  lastDate: s.today.add(const Duration(days: 365)),
                );
                if (d != null) await save(t.copyWith(nextReview: isoDay(d)));
              },
              child: const Text('تعیین'),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.playlist_add),
          label: const Text('ساخت مأموریت مرور برای امروز'),
          onPressed: () async {
            final sub = s.subjectOf(t.subjectId)?.name ?? '';
            final err = await s.saveMission(s.quick('مرور و تمرین: ${t.name}', sub, 30, 2, s.todayIso));
            if (context.mounted) toast(context, err ?? 'مأموریت به امروز اضافه شد.');
          },
        ),
        const SectionTitle('یادداشت و اشتباهات پرتکرار'),
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'یادداشت'),
          onEditingComplete: () => save(t.copyWith(notes: _notes!.text)),
          onTapOutside: (_) => save(t.copyWith(notes: _notes!.text)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _mistakes,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'اشتباهات پرتکرار'),
          onEditingComplete: () => save(t.copyWith(mistakes: _mistakes!.text)),
          onTapOutside: (_) => save(t.copyWith(mistakes: _mistakes!.text)),
        ),
        SectionTitle('ثبت‌ها', trailing: TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('ثبت جدید'),
          onPressed: () => _addLog(context, s, t),
        )),
        if (logs.isEmpty)
          AppCard(child: Text('هنوز تمرین یا آزمونی برای این مبحث ثبت نشده است.', style: TextStyle(color: context.colors.muted)))
        else
          for (final l in logs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${logKinds[l.kind]} · ${jalaliLabel(parseDay(l.date))}'),
                      const SizedBox(height: 4),
                      Text(
                        '${faDigits(l.correct)} از ${faDigits(l.total)} (${faDigits(((l.accuracy ?? 0) * 100).round())}٪)'
                        '${l.seconds != null ? ' · ${secondsLabel(l.seconds!)}' : ''}',
                        style: TextStyle(color: context.colors.muted, fontSize: 12),
                      ),
                    ]),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: context.colors.muted),
                    onPressed: () async {
                      final ok = await confirm(context, 'حذف ثبت', 'این ثبت حذف شود؟', ok: 'حذف');
                      if (ok) await s.deleteLog(l.id!);
                    },
                  ),
                ]),
              ),
            ),
      ]),
    );
  }

  Future<void> _addLog(BuildContext context, AppState s, Topic t) async {
    final total = TextEditingController(), correct = TextEditingController(), minutes = TextEditingController();
    String kind = 'practice';
    final key = GlobalKey<FormState>();
    int? p(String v) {
      const fa = '۰۱۲۳۴۵۶۷۸۹';
      var x = v.trim();
      for (var i = 0; i < 10; i++) {
        x = x.replaceAll(fa[i], '$i');
      }
      return int.tryParse(x);
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('ثبت تمرین یا آزمون'),
          content: SingleChildScrollView(
            child: Form(
              key: key,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SegmentedButton<String>(
                  segments: [for (final e in logKinds.entries) ButtonSegment(value: e.key, label: Text(e.value))],
                  selected: {kind},
                  onSelectionChanged: (v) => set(() => kind = v.first),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: total,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'تعداد سؤال'),
                  validator: (v) => (p(v ?? '') ?? 0) < 1 ? 'عدد معتبر وارد کن' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: correct,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'پاسخ صحیح'),
                  validator: (v) {
                    final c = p(v ?? '');
                    final t = p(total.text);
                    if (c == null || c < 0) return 'عدد معتبر وارد کن';
                    if (t != null && c > t) return 'بیشتر از تعداد سؤال‌ها نیست';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'زمان کل (دقیقه، اختیاری)'),
                  validator: (v) => (v == null || v.trim().isEmpty || (p(v) ?? 0) > 0) ? null : 'عدد معتبر وارد کن',
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            TextButton(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final mins = p(minutes.text);
    final err = await s.addLog(QuizLog(
      topicId: t.id!, kind: kind, total: p(total.text)!, correct: p(correct.text)!,
      seconds: mins == null ? null : mins * 60, date: s.todayIso,
    ));
    if (err != null && context.mounted) toast(context, err);
  }
}
