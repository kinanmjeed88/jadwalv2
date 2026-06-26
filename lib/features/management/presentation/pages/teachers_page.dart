import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/management_provider.dart';
import '../../../../core/models/teacher.dart';

class TeachersPage extends ConsumerWidget {
  const TeachersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachersAsync = ref.watch(teachersNotifierProvider);

    return Scaffold(
      body: teachersAsync.when(
        data: (teachers) => ListView.builder(
          itemCount: teachers.length,
          itemBuilder: (context, index) {
            final teacher = teachers[index];
            return ListTile(
              title: Text(teacher.name),
              subtitle: Text(teacher.specialization),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  ref
                      .read(teachersNotifierProvider.notifier)
                      .deleteTeacher(teacher.id);
                },
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: \$e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTeacherDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTeacherDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final maxDailyCtrl = TextEditingController(text: '5');
    final maxWeeklyCtrl = TextEditingController(text: '20');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة معلم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'الاسم')),
            TextField(
                controller: specCtrl,
                decoration: const InputDecoration(labelText: 'الاختصاص')),
            TextField(
                controller: maxDailyCtrl,
                decoration:
                    const InputDecoration(labelText: 'الحد الأقصى يومياً'),
                keyboardType: TextInputType.number),
            TextField(
                controller: maxWeeklyCtrl,
                decoration:
                    const InputDecoration(labelText: 'الحد الأقصى أسبوعياً'),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              final teacher = Teacher()
                ..name = nameCtrl.text
                ..specialization = specCtrl.text
                ..maxLessonsPerDay = int.tryParse(maxDailyCtrl.text) ?? 5
                ..maxLessonsPerWeek = int.tryParse(maxWeeklyCtrl.text) ?? 20;
              ref.read(teachersNotifierProvider.notifier).addTeacher(teacher);
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
