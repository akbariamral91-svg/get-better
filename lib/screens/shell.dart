import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'home_tab.dart';
import 'learning_screen.dart';
import 'notes_screen.dart';
import 'progress_tab.dart';

/// قالب اصلی برنامه با چهار صفحه: خانه، پیشرفت، یادداشت‌ها، مرور. صفحهٔ پیش‌فرض «خانه» است.
class Shell extends StatelessWidget {
  const Shell({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    const pages = [HomeTab(), ProgressTab(), NotesScreen(), LearningScreen()];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: s.tabIndex, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: s.tabIndex,
        onDestinationSelected: s.goTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'پیشرفت'),
          NavigationDestination(icon: Icon(Icons.sticky_note_2_outlined), selectedIcon: Icon(Icons.sticky_note_2), label: 'یادداشت‌ها'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'مرور'),
        ],
      ),
    );
  }
}
