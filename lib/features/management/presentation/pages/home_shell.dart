import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../timetable/presentation/pages/timetable_page.dart';
import '../providers/subject_constraint_auto_sync_provider.dart';
import 'management_page.dart';

/// تبويبات الهيكل الرئيسي. تُحفظ في مزوّد حتى لا يُسقط إعادة بناء
/// [HomePage] (بعد حفظ مادة/قيد/صف/معلم) المستخدم إلى الجدول.
class HomeShellTabs {
  const HomeShellTabs._();

  static const int timetable = 0;
  static const int management = 1;
}

/// مصدر الحالة المشترك لتبويب الهيكل. لا يُحفظ في [State] الويدجت لأن
/// إتلاف [HomeShell] كان يعيد الفهرس إلى صفر (الجدول).
final homeShellTabIndexProvider = StateProvider<int>(
  (ref) => HomeShellTabs.timetable,
);

/// الهيكل الرئيسي للتطبيق بعد إكمال الإعداد الأولي: تبويب الجدول وتبويب الإدارة.
///
/// يُشغّل هذا الهيكل مراقب مزامنة قيود المواد التلقائية مرة واحدة عند الظهور،
/// فيُزامن القيود مع بيانات المواد والصفوف والحصص ويستمر في مراقبتها.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const List<Widget> _pages = [
    TimetablePage(),
    ManagementPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(subjectConstraintAutoSyncProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(homeShellTabIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(homeShellTabIndexProvider.notifier).state = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.table_chart),
            label: 'الجدول',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts),
            label: 'الإدارة',
          ),
        ],
      ),
    );
  }
}
