import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'teachers_page.dart';

class ManagementPage extends ConsumerWidget {
  const ManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة البيانات'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'المعلمين'),
              Tab(text: 'المواد'),
              Tab(text: 'الصفوف'),
              Tab(text: 'الإعدادات'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TeachersPage(),
            Center(child: Text('واجهة إدارة المواد (تحت الإنشاء)')),
            Center(child: Text('واجهة إدارة الصفوف (تحت الإنشاء)')),
            Center(child: Text('واجهة الإعدادات (تحت الإنشاء)')),
          ],
        ),
      ),
    );
  }
}
