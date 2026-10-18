import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// زیرساخت آیکون‌های داخلی: فقط آیکون‌های برداری Material (نه ایموجی یا استیکر).
/// در پایگاه داده فقط «کلید» متنی آیکون ذخیره می‌شود و با [iconFor] به IconData تبدیل می‌شود؛
/// بنابراین مجموعه را می‌توان بدون تغییر داده‌های ذخیره‌شده گسترش داد.
const Map<String, IconData> appIcons = {
  // درس و کار
  'menu_book': Icons.menu_book,
  'quiz': Icons.quiz,
  'edit': Icons.edit,
  'calculate': Icons.calculate,
  'science': Icons.science,
  'translate': Icons.translate,
  'history_edu': Icons.history_edu,
  'school': Icons.school,
  'public': Icons.public,
  'brush': Icons.brush,
  'music_note': Icons.music_note,
  'psychology': Icons.psychology,
  'fitness_center': Icons.fitness_center,
  'timer': Icons.timer,
  'replay': Icons.replay,
  'checklist': Icons.checklist,
  // یادداشت
  'lightbulb': Icons.lightbulb,
  'bookmark': Icons.bookmark,
  'star': Icons.star,
  'flag': Icons.flag,
  'push_pin': Icons.push_pin,
  'label': Icons.label,
  'favorite': Icons.favorite,
  'edit_note': Icons.edit_note,
  'event_note': Icons.event_note,
  'auto_awesome': Icons.auto_awesome,
  // اتفاقات روز
  'celebration': Icons.celebration,
  'emoji_events': Icons.emoji_events,
  'mood': Icons.mood,
  'sentiment_satisfied': Icons.sentiment_satisfied,
  'wb_sunny': Icons.wb_sunny,
  'restaurant': Icons.restaurant,
  'local_cafe': Icons.local_cafe,
  'cake': Icons.cake,
  'sports_soccer': Icons.sports_soccer,
  'directions_walk': Icons.directions_walk,
  'groups': Icons.groups,
  'call': Icons.call,
  'flight': Icons.flight,
  'movie': Icons.movie,
  'pets': Icons.pets,
  'shopping_bag': Icons.shopping_bag,
  'bedtime': Icons.bedtime,
  'thumb_up': Icons.thumb_up,
};

/// گروه‌های کاربرد آیکون
enum IconGroup { tasks, notes, events }

const Map<IconGroup, List<String>> iconGroupKeys = {
  IconGroup.tasks: [
    'menu_book', 'quiz', 'edit', 'calculate', 'science', 'translate', 'history_edu', 'school',
    'public', 'brush', 'music_note', 'psychology', 'fitness_center', 'timer', 'replay', 'checklist',
  ],
  IconGroup.notes: [
    'lightbulb', 'bookmark', 'star', 'flag', 'push_pin', 'label', 'favorite', 'edit_note',
    'event_note', 'auto_awesome', 'psychology', 'school',
  ],
  IconGroup.events: [
    'celebration', 'emoji_events', 'mood', 'sentiment_satisfied', 'wb_sunny', 'restaurant', 'local_cafe',
    'cake', 'sports_soccer', 'directions_walk', 'groups', 'call', 'flight', 'movie', 'pets',
    'shopping_bag', 'bedtime', 'thumb_up', 'favorite', 'star',
  ],
};

/// تبدیل کلید ذخیره‌شده به آیکون؛ برای کلید خالی یا ناشناخته null برمی‌گرداند.
IconData? iconFor(String? key) => key == null ? null : appIcons[key];

/// انتخاب‌گر آیکون. کلید انتخاب‌شده را برمی‌گرداند؛ رشتهٔ خالی یعنی «بدون آیکون» و null یعنی انصراف.
Future<String?> showIconPicker(BuildContext context, {required IconGroup group, String? selected}) {
  final keys = iconGroupKeys[group] ?? const <String>[];
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final c = ctx.colors;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('انتخاب آیکون', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('بدون آیکون')),
            ]),
            const SizedBox(height: 8),
            Flexible(
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 5,
                semanticChildCount: keys.length,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (final k in keys)
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(ctx, k),
                      child: Container(
                        decoration: BoxDecoration(
                          color: k == selected ? c.gold.withOpacity(0.18) : c.card2,
                          borderRadius: BorderRadius.circular(14),
                          border: k == selected ? Border.all(color: c.gold) : null,
                        ),
                        child: Icon(appIcons[k], color: k == selected ? c.gold : c.text),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        ),
      );
    },
  );
}

/// فیلد انتخاب آیکون برای فرم‌ها: آیکون فعلی را نشان می‌دهد و با لمس، انتخاب‌گر را باز می‌کند.
/// [onChanged] با کلید جدید (یا null برای «بدون آیکون») صدا زده می‌شود.
class IconPickerField extends StatelessWidget {
  final IconGroup group;
  final String? value;
  final ValueChanged<String?> onChanged;
  const IconPickerField({super.key, required this.group, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final icon = iconFor(value);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        alignment: AlignmentDirectional.centerStart,
        foregroundColor: c.text,
        side: BorderSide(color: c.card2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () async {
        final r = await showIconPicker(context, group: group, selected: value);
        if (r == null) return; // انصراف
        onChanged(r.isEmpty ? null : r);
      },
      child: Row(children: [
        Icon(icon ?? Icons.add_reaction_outlined, color: icon == null ? c.muted : c.gold, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(icon == null ? 'انتخاب آیکون (اختیاری)' : 'آیکون انتخاب‌شده')),
        Icon(Icons.chevron_left, color: c.muted),
      ]),
    );
  }
}
