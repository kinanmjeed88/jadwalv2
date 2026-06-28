import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/management_provider.dart';
import '../../../../core/models/teacher.dart';

class TeachersPage extends ConsumerStatefulWidget {
  const TeachersPage({super.key});

  @override
  ConsumerState<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends ConsumerState<TeachersPage> {
  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teachersNotifierProvider);

    return Scaffold(
      body: teachersAsync.when(
        data: (teachers) => ListView.builder(
          itemCount: teachers.length,
          itemBuilder: (context, index) {
            final teacher = teachers[index];
            return ListTile(
              title: Text(teacher.name),
              subtitle: Text(
                  '${teacher.specialization} - مفرغ في: ${_getDaysString(teacher.unavailableDays)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      _showAddTeacherDialog(context, ref, teacher: teacher);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      ref
                          .read(teachersNotifierProvider.notifier)
                          .deleteTeacher(teacher.id);
                    },
                  ),
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('حدث خطأ: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTeacherDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getDaysString(List<int> days) {
    if (days.isEmpty) return 'لا يوجد';
    const dayNames = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    return days
        .map((d) => d >= 0 && d < dayNames.length ? dayNames[d] : '')
        .join('، ');
  }

  void _showAddTeacherDialog(BuildContext context, WidgetRef ref, {Teacher? teacher}) {
    final nameCtrl = TextEditingController(text: teacher?.name ?? '');
    final specCtrl = TextEditingController(text: teacher?.specialization ?? '');
    final maxDailyCtrl = TextEditingController(text: teacher?.maxLessonsPerDay.toString() ?? '5');
    final maxWeeklyCtrl = TextEditingController(text: teacher?.maxLessonsPerWeek.toString() ?? '20');
    final selectedDays = <int>[...teacher?.unavailableDays ?? []];
    final allowedPeriods = <int>[...teacher?.allowedPeriods ?? []];

    const dayNames = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

    // Default to 10 periods for the UI constraint checkbox selection
    // In a real app we might fetch this from Settings
    const maxPeriods = 10;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('إضافة معلم'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'الاسم',
                          helperText: 'مثال: أ. أحمد محمد')),
                  TextField(
                      controller: specCtrl,
                      decoration: const InputDecoration(
                          labelText: 'الاختصاص', helperText: 'مثال: رياضيات')),
                  TextField(
                      controller: maxDailyCtrl,
                      decoration: const InputDecoration(
                          labelText: 'الحد الأقصى يومياً',
                          helperText: 'عدد الدروس القصوى باليوم الواحد'),
                      keyboardType: TextInputType.number),
                  TextField(
                      controller: maxWeeklyCtrl,
                      decoration: const InputDecoration(
                          labelText: 'الحد الأقصى أسبوعياً',
                          helperText: 'عدد الدروس القصوى بالأسبوع'),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  const Text('أيام التفرغ:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8.0,
                    children: List.generate(dayNames.length, (index) {
                      return FilterChip(
                        label: Text(dayNames[index]),
                        selected: selectedDays.contains(index),
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              selectedDays.add(index);
                            } else {
                              selectedDays.remove(index);
                            }
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text('الدروس المسموحة (اتركه فارغاً للسماح بالكل):',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Wrap(
                      spacing: 8.0,
                      children: List.generate(maxPeriods, (index) {
                        return FilterChip(
                          label: Text('الدرس ${index + 1}'),
                          selected: allowedPeriods.contains(index),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                allowedPeriods.add(index);
                              } else {
                                allowedPeriods.remove(index);
                              }
                            });
                          },
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء')),
              TextButton(
                onPressed: () {
                  final newTeacher = teacher ?? Teacher();
                  newTeacher
                    ..name = nameCtrl.text
                    ..specialization = specCtrl.text
                    ..maxLessonsPerDay = int.tryParse(maxDailyCtrl.text) ?? 5
                    ..maxLessonsPerWeek = int.tryParse(maxWeeklyCtrl.text) ?? 20
                    ..unavailableDays = List.from(selectedDays)
                    ..allowedPeriods = List.from(allowedPeriods);
                  ref
                      .read(teachersNotifierProvider.notifier)
                      .addTeacher(newTeacher); // acts as put (insert or update)
                  Navigator.pop(context);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        });
      },
    );
  }
}
