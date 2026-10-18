import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'missions_screen.dart';
import 'settings_screen.dart';

/// تب «خانه»: سربرگ برنامه + دو بخش «امروز» (صفحهٔ خانهٔ قبلی) و «برنامه روزانه» (صفحهٔ مأموریت‌های قبلی).
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final dark = s.themeMode == ThemeMode.dark;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Get Better', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.colors.text)),
              const SizedBox(height: 2),
              Text('هر قدم، نزدیک‌تر به هدف', style: TextStyle(color: context.colors.muted, fontSize: 12)),
            ]),
          ),
          // دکمهٔ کوچک تغییر تم؛ انتخاب کاربر ذخیره می‌شود
          IconButton(
            tooltip: dark ? 'حالت روشن' : 'حالت تیره',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: context.colors.muted),
            onPressed: s.toggleTheme,
          ),
          IconButton(
            tooltip: 'تنظیمات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('امروز'), icon: Icon(Icons.today_outlined)),
              ButtonSegment(value: 1, label: Text('برنامه روزانه'), icon: Icon(Icons.calendar_month_outlined)),
            ],
            selected: {s.homeSub},
            onSelectionChanged: (v) => s.goHomeSub(v.first),
          ),
        ),
      ),
      Expanded(
        child: IndexedStack(index: s.homeSub, children: const [HomeScreen(), MissionsScreen()]),
      ),
    ]);
  }
}
