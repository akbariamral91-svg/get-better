import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';
import 'roadmap_screen.dart' show pickExamDate;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SectionTitle('ظاهر'),
        AppCard(
          child: Row(children: [
            Icon(Icons.brightness_6_outlined, color: context.colors.muted),
            const SizedBox(width: 12),
            const Expanded(child: Text('تم برنامه', style: TextStyle(fontWeight: FontWeight.w600))),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: ThemeMode.dark, label: Text('تیره')),
                ButtonSegment(value: ThemeMode.light, label: Text('روشن')),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => s.setThemeMode(v.first),
            ),
          ]),
        ),
        const SectionTitle('آزمون'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.event_outlined, color: context.colors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('تاریخ آزمون', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    s.examDate == null ? 'هنوز تعیین نشده' : jalaliFull(s.examDate!),
                    style: TextStyle(color: context.colors.muted, fontSize: 12),
                  ),
                ]),
              ),
              TextButton(onPressed: () => pickExamDate(context), child: Text(s.examDate == null ? 'تعیین' : 'تغییر')),
              if (s.examDate != null)
                IconButton(
                  tooltip: 'حذف تاریخ آزمون',
                  icon: const Icon(Icons.close),
                  onPressed: () => s.setExamDate(null),
                ),
            ]),
            const SizedBox(height: 6),
            Text('تاریخ را خودت از اطلاعیهٔ رسمی وارد کن؛ برنامه آن را حدس نمی‌زند. شمارش معکوس در صفحهٔ پیشرفت نمایش داده می‌شود.',
                style: TextStyle(color: context.colors.muted, fontSize: 12, height: 1.8)),
          ]),
        ),
        const SectionTitle('یادآوری‌ها'),
        _ReminderTile(keyName: 'morning', title: 'یادآوری شروع روز', subtitle: 'بررسی برنامهٔ امروز'),
        const SizedBox(height: 8),
        _ReminderTile(keyName: 'night', title: 'یادآوری برنامه‌ریزی شبانه', subtitle: 'آماده‌سازی برنامهٔ فردا'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('ارسال اعلان آزمایشی'),
          onPressed: () async {
            final ok = await NotificationService.requestPermission();
            if (!context.mounted) return;
            if (!ok) {
              toast(context, 'مجوز اعلان داده نشده است. از تنظیمات گوشی، اعلان‌های «Get Better» را روشن کن.');
              return;
            }
            await NotificationService.showNow('Get Better', 'اعلان‌ها درست کار می‌کنند.');
          },
        ),
        const SizedBox(height: 6),
        Text(
          'یادآوری‌ها روزانه و بدون اینترنت اجرا می‌شوند، اما در برخی گوشی‌ها (مثل شیائومی، سامسونگ، هواوی) سیستم صرفه‌جویی باتری ممکن است اعلان را تأخیر بدهد یا حذف کند. در این صورت باتری برنامه را روی «بدون محدودیت» بگذار. اعلان‌ها به‌دلیل استفاده از زمان‌بندی غیردقیق ممکن است چند دقیقه دیرتر برسند.',
          style: TextStyle(color: context.colors.muted, fontSize: 12, height: 1.8),
        ),
        const SectionTitle('پشتیبان‌گیری'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('پشتیبان به‌صورت متن در حافظهٔ کلیپ‌بورد کپی می‌شود. آن را در یک یادداشت یا پیام ذخیره‌شده نگه دار و هر زمان خواستی همین‌جا بازیابی کن.',
                style: TextStyle(color: context.colors.muted, fontSize: 12, height: 1.8)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final text = await s.exportBackup();
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) toast(context, 'پشتیبان کپی شد.');
                  },
                  child: const Text('گرفتن پشتیبان'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: () => _restore(context, s), child: const Text('بازیابی'))),
            ]),
          ]),
        ),
        const SectionTitle('داده‌ها'),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: context.colors.red),
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('پاک کردن کامل داده‌ها'),
          onPressed: () async {
            final ok = await confirm(context, 'پاک کردن کامل', 'همهٔ مأموریت‌ها، امتیازها، مباحث و تنظیمات برای همیشه پاک می‌شود. ابتدا پشتیبان بگیر. ادامه می‌دهی؟', ok: 'پاک کن');
            if (!ok) return;
            await s.wipeAll();
            if (context.mounted) toast(context, 'همهٔ داده‌ها پاک شد.');
          },
        ),
      ]),
    );
  }

  Future<void> _restore(BuildContext context, AppState s) async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('بازیابی پشتیبان'),
        content: TextField(controller: c, maxLines: 5, decoration: const InputDecoration(labelText: 'متن پشتیبان را اینجا بچسبان')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('بازیابی')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    final ok = await confirm(context, 'جایگزینی داده‌ها', 'داده‌های فعلی با پشتیبان جایگزین می‌شوند. ادامه می‌دهی؟');
    if (!ok) return;
    final err = await s.importBackup(text.trim());
    if (context.mounted) toast(context, err ?? 'بازیابی انجام شد.');
  }
}

class _ReminderTile extends StatelessWidget {
  final String keyName, title, subtitle;
  const _ReminderTile({required this.keyName, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final r = s.reminder(keyName);
    final time = faDigits('${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}');
    return AppCard(
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(subtitle, style: TextStyle(color: context.colors.muted, fontSize: 12)),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: r.hour, minute: r.minute));
                if (t != null) await s.setReminder(keyName, r.enabled, t.hour, t.minute);
              },
              child: Text('ساعت $time'),
            ),
          ]),
        ),
        Switch(
          value: r.enabled,
          onChanged: (v) async {
            if (v) {
              final ok = await NotificationService.requestPermission();
              if (!ok) {
                if (context.mounted) toast(context, 'بدون مجوز اعلان، یادآوری کار نمی‌کند. مجوز را از تنظیمات گوشی بده.');
                return;
              }
            }
            await s.setReminder(keyName, v, r.hour, r.minute);
          },
        ),
      ]),
    );
  }
}
