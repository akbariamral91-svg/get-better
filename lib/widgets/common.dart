import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: color ?? context.colors.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Row(children: [
          Expanded(child: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.text))),
          if (trailing != null) trailing!,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.message, this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: context.colors.muted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.colors.muted, height: 1.7)),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      );
}

class AnimatedBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;
  const AnimatedBar({super.key, required this.value, this.color, this.height = 10});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => LinearProgressIndicator(
            value: v, minHeight: height, color: color ?? context.colors.gold, backgroundColor: context.colors.card2),
        ),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  const Pill(this.text, {super.key, this.color, this.icon});
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 4)],
        Text(text, style: TextStyle(fontSize: 12, color: c)),
      ]),
    );
  }
}

String minutesLabel(int m) => m >= 60 ? '${faDigits(m ~/ 60)} ساعت${m % 60 == 0 ? '' : ' و ${faDigits(m % 60)} دقیقه'}' : '${faDigits(m)} دقیقه';

String secondsLabel(int s) => minutesLabel((s / 60).round());

void toast(BuildContext c, String msg) {
  ScaffoldMessenger.of(c).hideCurrentSnackBar();
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));
}

Future<bool> confirm(BuildContext c, String title, String body, {String ok = 'تأیید'}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(body, style: const TextStyle(height: 1.7)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

/// نمودار میله‌ای ساده با داده واقعی
class BarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color? color;
  const BarChart({super.key, required this.values, required this.labels, this.color});
  @override
  Widget build(BuildContext context) {
    final barColor = color ?? context.colors.gold;
    final maxV = values.fold<double>(0, (a, b) => b > a ? b : a);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(faDigits(values[i].round()), style: TextStyle(fontSize: 11, color: context.colors.muted)),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: maxV == 0 ? 0 : values[i] / maxV),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Container(
                    height: 4 + 90 * v,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: values[i] == 0 ? context.colors.card2 : barColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(labels[i], style: TextStyle(fontSize: 10, color: context.colors.muted)),
              ]),
            ),
        ],
      ),
    );
  }
}
