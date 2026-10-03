import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../timetable/presentation/pages/timetable_page.dart';
import '../providers/subject_constraint_auto_sync_provider.dart';
import 'management_page.dart';

/// تبويبات الهيكل الرئيسي.
class HomeShellTabs {
  static const int timetable = 0;
  static const int management = 1;
}

/// يُحفظ خارج [State] حتى لا يُسقط إعادة بناء [HomePage] المستخدم إلى الجدول.
int homeShellTabIndex = HomeShellTabs.timetable;

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
  final List<Widget> _pages = const [
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
    return Scaffold(
      body: IndexedStack(
        index: homeShellTabIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: homeShellTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            homeShellTabIndex = index;
          });
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
