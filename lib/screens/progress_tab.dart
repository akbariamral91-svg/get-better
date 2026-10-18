import 'package:flutter/material.dart';
import 'roadmap_screen.dart';
import 'stats_screen.dart';

/// تب «پیشرفت»: آمار و دستاوردها + نقشهٔ مسیر (که قبلاً تب جداگانه بود).
class ProgressTab extends StatefulWidget {
  const ProgressTab({super.key});
  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  int _view = 0;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('آمار و دستاوردها'), icon: Icon(Icons.insights_outlined)),
              ButtonSegment(value: 1, label: Text('نقشهٔ مسیر'), icon: Icon(Icons.flag_outlined)),
            ],
            selected: {_view},
            onSelectionChanged: (v) => setState(() => _view = v.first),
          ),
        ),
      ),
      Expanded(
        child: IndexedStack(index: _view, children: const [StatsScreen(), RoadmapScreen()]),
      ),
    ]);
  }
}
