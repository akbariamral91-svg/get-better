import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import 'common.dart';

Future<void> showCompletion(BuildContext context, CompletionResult r) async {
  if (r.gained == 0 && r.newAchievements.isEmpty) {
    toast(context, 'این مأموریت قبلاً امتیاز گرفته بود.');
    return;
  }
  if (!r.leveledUp && r.newAchievements.isEmpty) {
    toast(context, '+${faDigits(r.gained)} امتیاز تجربه ثبت شد');
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      content: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.workspace_premium, size: 56, color: context.colors.gold),
          const SizedBox(height: 10),
          if (r.leveledUp)
            Text('سطح ${faDigits(r.newLevel)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.colors.gold)),
          if (r.gained > 0) Text('+${faDigits(r.gained)} XP', style: TextStyle(color: context.colors.green, fontSize: 16)),
          for (final a in r.newAchievements) ...[
            const SizedBox(height: 10),
            Text('دستاورد جدید: ${a.title}', textAlign: TextAlign.center),
          ],
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ادامه'))],
    ),
  );
}
