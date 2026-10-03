import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/classroom.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/teacher.dart';
import '../../../timetable/presentation/providers/timetable_provider.dart';
import '../providers/management_provider.dart';

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

  void _showAddTeacherDialog(BuildContext context, WidgetRef ref,
      {Teacher? teacher}) {
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
  final Set<int> _selectedSubjectIds = <int>{};
  final Set<int> _selectedClassroomIds = <int>{};
  bool _isSaving = false;

  bool get _isEditing => widget.teacher != null;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.teacher?.name ?? '');
    specCtrl =
        TextEditingController(text: widget.teacher?.specialization ?? '');
    maxDailyCtrl = TextEditingController(
        text: widget.teacher?.maxLessonsPerDay.toString() ?? '5');
    maxWeeklyCtrl = TextEditingController(
        text: widget.teacher?.maxLessonsPerWeek.toString() ?? '20');
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
    final subjectsAsync = ref.watch(subjectsNotifierProvider);
    final classroomsAsync = ref.watch(classroomsNotifierProvider);

    return AlertDialog(
      title: Text(_isEditing ? 'تعديل معلم' : 'إضافة معلم'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: nameCtrl,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'مطلوب' : null,
                decoration: const InputDecoration(
                    labelText: 'الاسم', helperText: 'مثال: أ. أحمد محمد'),
              ),
              TextFormField(
                controller: specCtrl,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'مطلوب' : null,
                decoration: const InputDecoration(
                    labelText: 'الاختصاص', helperText: 'مثال: رياضيات'),
              ),
              TextFormField(
                  controller: maxDailyCtrl,
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'مطلوب' : null,
                  decoration: const InputDecoration(
                      labelText: 'الحد الأقصى يومياً',
                      helperText: 'عدد الدروس القصوى باليوم الواحد'),
                  keyboardType: TextInputType.number),
              TextFormField(
                  controller: maxWeeklyCtrl,
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'مطلوب' : null,
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
              if (!_isEditing) ...[
                const SizedBox(height: 20),
                const Text('الإسناد الأولي',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'اختياري: اختر مادة أو أكثر وصفًا أو أكثر. يُنشأ إسناد لكل تركيب (مادة × صف) بنموذج الحصص الحالي.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                const Text('المواد'),
                subjectsAsync.when(
                  data: (subjects) {
                    if (subjects.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('لا توجد مواد بعد. يمكن الإسناد لاحقًا من تبويب المهام.'),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      children: subjects.map((subject) {
                        return FilterChip(
                          label: Text(subject.name),
                          selected: _selectedSubjectIds.contains(subject.id),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSubjectIds.add(subject.id);
                              } else {
                                _selectedSubjectIds.remove(subject.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, st) => Text('تعذر تحميل المواد: $e'),
                ),
                const SizedBox(height: 12),
                const Text('الصفوف'),
                classroomsAsync.when(
                  data: (classrooms) {
                    if (classrooms.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('لا توجد صفوف بعد. يمكن الإسناد لاحقًا من تبويب المهام.'),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      children: classrooms.map((classroom) {
                        return FilterChip(
                          label: Text(classroom.name),
                          selected: _selectedClassroomIds.contains(classroom.id),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedClassroomIds.add(classroom.id);
                              } else {
                                _selectedClassroomIds.remove(classroom.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, st) => Text('تعذر تحميل الصفوف: $e'),
                ),
                if (_selectedSubjectIds.isNotEmpty &&
                    _selectedClassroomIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'سيتم إنشاء ${_selectedSubjectIds.length * _selectedClassroomIds.length} إسنادًا (كل مادة لكل صف مختار).',
                      style: const TextStyle(fontSize: 12, color: Colors.teal),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () => _save(
                    subjectsAsync.maybeWhen(
                      data: (subjects) => subjects,
                      orElse: () => const <Subject>[],
                    ),
                    classroomsAsync.maybeWhen(
                      data: (classrooms) => classrooms,
                      orElse: () => const <Classroom>[],
                    ),
                  ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }

  Future<void> _save(
    List<Subject> allSubjects,
    List<Classroom> allClassrooms,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    final newTeacher = widget.teacher ?? Teacher();
    newTeacher
      ..name = nameCtrl.text
      ..specialization = specCtrl.text
      ..maxLessonsPerDay = int.tryParse(maxDailyCtrl.text) ?? 5
      ..maxLessonsPerWeek = int.tryParse(maxWeeklyCtrl.text) ?? 20
      ..unavailableDays = List.from(selectedDays)
      ..allowedPeriods = List.from(allowedPeriods);

    try {
      if (_isEditing) {
        await ref.read(teachersNotifierProvider.notifier).addTeacher(newTeacher);
      } else {
        final selectedSubjects = allSubjects
            .where((subject) => _selectedSubjectIds.contains(subject.id))
            .toList();
        final selectedClassrooms = allClassrooms
            .where((classroom) => _selectedClassroomIds.contains(classroom.id))
            .toList();

        final error = await ref
            .read(teachersNotifierProvider.notifier)
            .addTeacherWithInitialAssignments(
              teacher: newTeacher,
              subjects: selectedSubjects,
              classrooms: selectedClassrooms,
            );
        if (error != null) {
          if (mounted) {
            setState(() => _isSaving = false);
          }
          messenger.showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
          return;
        }

        ref.invalidate(timetableNotifierProvider);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ المعلم: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
