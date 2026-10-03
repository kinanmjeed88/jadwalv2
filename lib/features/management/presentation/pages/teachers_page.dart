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
                    tooltip: 'تعديل',
                    onPressed: () {
                      _showAddTeacherDialog(context, ref, teacher: teacher);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'حذف',
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
        tooltip: 'إضافة',
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
    showDialog(
      context: context,
      builder: (context) {
        return _TeacherDialog(teacher: teacher);
      },
    );
  }
}

class _TeacherDialog extends ConsumerStatefulWidget {
  final Teacher? teacher;
  const _TeacherDialog({this.teacher});

  @override
  ConsumerState<_TeacherDialog> createState() => _TeacherDialogState();
}

class _TeacherDialogState extends ConsumerState<_TeacherDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameCtrl;
  late TextEditingController specCtrl;
  late TextEditingController maxDailyCtrl;
  late TextEditingController maxWeeklyCtrl;
  late List<int> selectedDays;
  late List<int> allowedPeriods;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.teacher?.name ?? '');
    specCtrl = TextEditingController(text: widget.teacher?.specialization ?? '');
    maxDailyCtrl = TextEditingController(text: widget.teacher?.maxLessonsPerDay.toString() ?? '5');
    maxWeeklyCtrl = TextEditingController(text: widget.teacher?.maxLessonsPerWeek.toString() ?? '20');
    selectedDays = <int>[...widget.teacher?.unavailableDays ?? []];
    allowedPeriods = <int>[...widget.teacher?.allowedPeriods ?? []];
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    specCtrl.dispose();
    maxDailyCtrl.dispose();
    maxWeeklyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dayNames = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    const maxPeriods = 10;

    return AlertDialog(
      title: const Text('إضافة معلم'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                validator: (val) => val == null || val.trim().isEmpty ? 'مطلوب' : null,
                decoration: const InputDecoration(
                    labelText: 'الاسم',
                    helperText: 'مثال: أ. أحمد محمد')),
              TextFormField(
                controller: specCtrl,
                validator: (val) => val == null || val.trim().isEmpty ? 'مطلوب' : null,
                decoration: const InputDecoration(
                    labelText: 'الاختصاص', helperText: 'مثال: رياضيات')),
              TextFormField(
                controller: maxDailyCtrl,
                validator: (val) => val == null || val.trim().isEmpty ? 'مطلوب' : null,
                decoration: const InputDecoration(
                    labelText: 'الحد الأقصى يومياً',
                    helperText: 'عدد الدروس القصوى باليوم الواحد'),
                keyboardType: TextInputType.number),
              TextFormField(
                controller: maxWeeklyCtrl,
                validator: (val) => val == null || val.trim().isEmpty ? 'مطلوب' : null,
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
        ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final newTeacher = widget.teacher ?? Teacher();
            newTeacher
              ..name = nameCtrl.text
              ..specialization = specCtrl.text
              ..maxLessonsPerDay = int.tryParse(maxDailyCtrl.text) ?? 5
              ..maxLessonsPerWeek = int.tryParse(maxWeeklyCtrl.text) ?? 20
              ..unavailableDays = List.from(selectedDays)
              ..allowedPeriods = List.from(allowedPeriods);
            ref
                .read(teachersNotifierProvider.notifier)
                .addTeacher(newTeacher);
            Navigator.pop(context);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
