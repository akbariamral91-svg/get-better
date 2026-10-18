import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';

/// یک مرحلهٔ مسیر انگیزشی. [have] و [need] از داده‌های واقعی برنامه محاسبه می‌شوند.
class RoadmapStage {
  final String title, rule;
  final int have, need;
  const RoadmapStage(this.title, this.rule, this.have, this.need);
  bool get done => have >= need;
  double get progress => need == 0 ? 1.0 : (have / need).clamp(0.0, 1.0).toDouble();
}

/// مرحله‌های مسیر از روی وضعیت واقعی برنامه (بدون هیچ مقدار ساختگی)
List<RoadmapStage> buildRoadmapStages(AppState s) {
  final exams = s.logs.where((l) => l.kind == 'exam' && l.total >= 10).toList();
  return [
    const RoadmapStage('شروع مسیر', 'از همین‌جا شروع می‌شود', 1, 1),
    RoadmapStage('ساخت عادت مطالعه', 'در ۵ روز مختلف فعالیت ثبت کن', s.activeDays.length, 5),
    RoadmapStage('تسلط بر مباحث', '۳ مبحث را به «تسلط تأییدشده» برسان', s.masteredCount, 3),
    RoadmapStage('تثبیت و مرور', '۵ مرور ثبت کن', s.logs.where((l) => l.kind == 'review').length, 5),
    RoadmapStage('آزمون‌های ترکیبی', '۳ آزمون با حداقل ۱۰ سؤال ثبت کن', exams.length, 3),
    RoadmapStage('آزمون‌های زمان‌دار', '۳ آزمون همراه با زمان کل ثبت کن', exams.where((l) => l.seconds != null).length, 3),
    RoadmapStage('ارزیابی نهایی آمادگی', '۱۰ آزمون ثبت کن و مرحله‌های قبل را کامل کن', exams.length, 10),
  ];
}

enum StageStatus { completed, active, locked }

/// اندیس مرحلهٔ فعال = اولین مرحلهٔ ناتمام؛ اگر همه تمام باشند، تعداد مرحله‌ها.
int activeStageIndex(List<RoadmapStage> stages) {
  final i = stages.indexWhere((e) => !e.done);
  return i == -1 ? stages.length : i;
}

StageStatus stageStatus(int index, int active) =>
    index < active ? StageStatus.completed : (index == active ? StageStatus.active : StageStatus.locked);

/// میزان پرشدگی قطعهٔ مسیر بین گره [i] و گره بعدی (برای آخرین قطعه، هدف).
double segmentFill(int i, int active, List<RoadmapStage> stages) {
  if (i + 1 < active) return 1.0;
  if (i + 1 == active) return active >= stages.length ? 1.0 : stages[active].progress;
  return 0.0;
}

/// انتخاب یا تغییر تاریخ آزمون؛ تاریخ را فقط خود کاربر تعیین می‌کند.
Future<void> pickExamDate(BuildContext context) async {
  final s = context.read<AppState>();
  final today = s.today;
  final cur = s.examDate;
  final d = await showDatePicker(
    context: context,
    initialDate: (cur != null && !cur.isBefore(today)) ? cur : today.add(const Duration(days: 30)),
    firstDate: today,
    lastDate: today.add(const Duration(days: 730)),
    helpText: 'تاریخ آزمون',
  );
  if (d == null) return;
  final err = await s.setExamDate(d);
  if (err != null && context.mounted) toast(context, err);
}

class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key});
  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  static const double _spacing = 150, _topGap = 70, _bottomGap = 110;
  ScrollController? _ctrl;

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _showInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('دربارهٔ این مسیر'),
        content: const Text(
          'این مسیر یک چارچوب انگیزشی است تا پیشرفتت را ببینی؛ ساختار رسمی آزمون نمونه دولتی نیست.\n\n'
          'وضعیت مرحله‌ها فقط از فعالیت‌هایی که خودت در برنامه ثبت می‌کنی (روزهای فعال، تسلط بر مباحث، مرورها و آزمون‌ها) محاسبه می‌شود.\n\n'
          'برای ساختار، زمان و منابع آزمون به اطلاعیهٔ رسمی مراجعه کن.',
          style: TextStyle(height: 1.8),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('متوجه شدم'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.colors;
    final stages = buildRoadmapStages(s);
    final n = stages.length;
    final active = activeStageIndex(stages);
    final stackH = _topGap + (n - 1) * _spacing + _bottomGap;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
        child: Row(children: [
          const Expanded(child: Text('نقشهٔ مسیر', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
          IconButton(tooltip: 'دربارهٔ این مسیر', icon: Icon(Icons.info_outline, color: c.muted), onPressed: _showInfo),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Wrap(spacing: 14, runSpacing: 4, children: [
          _legend(c.green, Icons.check, 'تکمیل‌شده'),
          _legend(c.gold, Icons.flag, 'فعال'),
          _legend(c.muted, Icons.lock_outline, 'قفل‌شده'),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          // مسیر از پایین شروع می‌شود؛ پیمایش معکوس است و در ابتدا مرحلهٔ فعال را به مرکز می‌آورد.
          if (_ctrl == null) {
            final double fromBottom = _bottomGap + (active < n ? active : n - 1) * _spacing;
            final double target = active >= n ? 1e6 : (fromBottom - box.maxHeight / 2);
            _ctrl = ScrollController(initialScrollOffset: target < 0 ? 0.0 : target);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final cc = _ctrl;
              if (cc != null && cc.hasClients && cc.offset > cc.position.maxScrollExtent) {
                cc.jumpTo(cc.position.maxScrollExtent);
              }
            });
          }
          final w = box.maxWidth;
          final pts = [
            for (var i = 0; i < n; i++) Offset(w * (i.isEven ? 0.28 : 0.72), _topGap + (n - 1 - i) * _spacing),
          ];
          final goalPt = Offset(w / 2, 0);
          return SingleChildScrollView(
            controller: _ctrl,
            reverse: true,
            child: Column(children: [
              _GoalBanner(s: s, allDone: active >= n),
              SizedBox(
                height: stackH,
                width: w,
                child: Stack(children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PathPainter(
                        points: [...pts, goalPt],
                        fills: [for (var i = 0; i < n; i++) segmentFill(i, active, stages)],
                        trackColor: c.card2,
                        doneColor: c.green,
                        activeColor: c.gold,
                      ),
                    ),
                  ),
                  for (var i = 0; i < n; i++) ...[
                    Positioned(left: pts[i].dx - 28, top: pts[i].dy - 28, child: _Node(stage: stages[i], status: stageStatus(i, active))),
                    _label(i, pts[i], w, stages[i], stageStatus(i, active), c),
                  ],
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 6,
                    child: Text(
                      'این مسیر انگیزشی است و ساختار رسمی آزمون نیست.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.muted, fontSize: 11.5),
                    ),
                  ),
                ]),
              ),
            ]),
          );
        }),
      ),
    ]);
  }

  Widget _legend(Color color, IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: context.colors.muted)),
      ]);

  Widget _label(int i, Offset p, double w, RoadmapStage st, StageStatus status, C c) {
    final right = i.isEven; // گره‌های زوج: متن سمت راست گره؛ فرد: سمت چپ
    final width = (right ? w - p.dx - 46 : p.dx - 46).clamp(110.0, 260.0).toDouble();
    final left = right ? p.dx + 36 : p.dx - 36 - width;
    final locked = status == StageStatus.locked;
    return Positioned(
      left: left,
      top: p.dy - 60,
      width: width,
      height: 120,
      child: Align(
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${faDigits(i + 1)}. ${st.title}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, color: locked ? c.muted : c.text)),
          const SizedBox(height: 2),
          Text(st.rule, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 11.5, height: 1.5)),
          const SizedBox(height: 5),
          if (status == StageStatus.completed)
            Text('تکمیل‌شده', style: TextStyle(color: c.green, fontSize: 11.5, fontWeight: FontWeight.w700))
          else ...[
            if (status == StageStatus.active) AnimatedBar(value: st.progress, height: 6),
            if (status == StageStatus.active) const SizedBox(height: 3),
            Text(
              locked ? 'قفل‌شده • ${faDigits(st.have.clamp(0, st.need))} از ${faDigits(st.need)}' : '${faDigits(st.have.clamp(0, st.need))} از ${faDigits(st.need)}',
              style: TextStyle(color: c.muted, fontSize: 11),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Node extends StatelessWidget {
  final RoadmapStage stage;
  final StageStatus status;
  const _Node({required this.stage, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = switch (status) {
      StageStatus.completed => 'تکمیل‌شده: ${stage.title}',
      StageStatus.active => 'فعال: ${stage.title}',
      StageStatus.locked => 'قفل‌شده: ${stage.title}',
    };
    Widget inner;
    switch (status) {
      case StageStatus.completed:
        inner = CircleAvatar(radius: 22, backgroundColor: c.green, child: Icon(Icons.check, color: c.onAccent, size: 26));
      case StageStatus.active:
        inner = Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(value: stage.progress, strokeWidth: 4, color: c.gold, backgroundColor: c.card2),
          ),
          CircleAvatar(radius: 20, backgroundColor: c.gold, child: Icon(Icons.flag, color: c.onAccent, size: 22)),
        ]);
      case StageStatus.locked:
        inner = CircleAvatar(
          radius: 22,
          backgroundColor: c.card2,
          child: Icon(Icons.lock_outline, color: c.muted, size: 20),
        );
    }
    return Semantics(label: label, child: SizedBox(width: 56, height: 56, child: Center(child: inner)));
  }
}

class _GoalBanner extends StatelessWidget {
  final AppState s;
  final bool allDone;
  const _GoalBanner({required this.s, required this.allDone});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final days = s.daysToExam;
    final exam = s.examDate;
    Widget countdown;
    if (exam == null) {
      countdown = Column(children: [
        Text('تاریخ آزمون هنوز تعیین نشده است.', style: TextStyle(color: c.muted, fontSize: 13)),
        const SizedBox(height: 4),
        TextButton.icon(
          icon: const Icon(Icons.event, size: 18),
          label: const Text('تعیین تاریخ آزمون'),
          onPressed: () => pickExamDate(context),
        ),
      ]);
    } else {
      final String main;
      if (days! > 0) {
        main = '${faDigits(days)} روز تا آزمون';
      } else if (days == 0) {
        main = 'امروز روز آزمون است';
      } else {
        main = 'تاریخ ثبت‌شدهٔ آزمون گذشته است';
      }
      countdown = Column(children: [
        Text(main, style: TextStyle(color: c.gold, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(jalaliFull(exam), style: TextStyle(color: c.muted, fontSize: 12)),
          TextButton(onPressed: () => pickExamDate(context), child: const Text('تغییر تاریخ')),
        ]),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.gold.withOpacity(0.6)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.gold.withOpacity(0.20), c.card],
          ),
        ),
        child: Column(children: [
          Icon(Icons.emoji_events, color: c.gold, size: 36),
          const SizedBox(height: 6),
          Text('هدف', style: TextStyle(color: c.muted, fontSize: 12)),
          const SizedBox(height: 2),
          const Text('قبولی در مدرسه نمونه دولتی بشارتی', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.5)),
          if (allDone) ...[
            const SizedBox(height: 4),
            Text('همهٔ مرحله‌های مسیر را کامل کرده‌ای. ادامه بده!', textAlign: TextAlign.center, style: TextStyle(color: c.green, fontSize: 12.5)),
          ],
          const SizedBox(height: 10),
          countdown,
        ]),
      ),
    );
  }
}

/// مسیر خمیدهٔ پیوسته از پایین (شروع) به بالا (هدف). هر قطعه جداگانه و بر اساس پیشرفت واقعی پر می‌شود.
class _PathPainter extends CustomPainter {
  final List<Offset> points; // نقطه‌های گره‌ها از پایین به بالا + نقطهٔ هدف در انتها
  final List<double> fills; // یک مقدار ۰ تا ۱ برای هر قطعه
  final Color trackColor, doneColor, activeColor;
  const _PathPainter({required this.points, required this.fills, required this.trackColor, required this.doneColor, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final dy = a.dy - b.dy;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, a.dy - dy * 0.5, b.dx, b.dy + dy * 0.5, b.dx, b.dy);
      canvas.drawPath(path, track);
      final f = fills[i].clamp(0.0, 1.0);
      if (f <= 0) continue;
      final metrics = path.computeMetrics().toList();
      if (metrics.isEmpty) continue;
      final m = metrics.first;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = f >= 1 ? doneColor : activeColor;
      canvas.drawPath(m.extractPath(0, m.length * f), paint);
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.points.length != points.length ||
      old.trackColor != trackColor ||
      old.doneColor != doneColor ||
      old.activeColor != activeColor ||
      !_sameList(old.fills, fills) ||
      !_samePts(old.points, points);

  static bool _sameList(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _samePts(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
