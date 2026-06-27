import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/classroom.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/teacher.dart';
import '../../../../core/models/lesson.dart';
import '../providers/management_provider.dart';
import '../../../timetable/presentation/providers/timetable_provider.dart';

class AssignmentsPage extends ConsumerStatefulWidget {
  const AssignmentsPage({super.key});

  @override
  ConsumerState<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends ConsumerState<AssignmentsPage> {
  Classroom? _selectedClassroom;
  Subject? _selectedSubject;
  Teacher? _selectedTeacher;

  void _assignLesson() {
    if (_selectedClassroom != null && _selectedSubject != null && _selectedTeacher != null) {
      ref.read(timetableNotifierProvider.notifier).assignLessonsToPool(
        _selectedClassroom!,
        _selectedSubject!,
        _selectedTeacher!,
      );
      final subjectName = _selectedSubject!.name;
      final classroomName = _selectedClassroom!.name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إسناد مادة $subjectName لـ $classroomName بنجاح')),
      );
      setState(() {
        _selectedSubject = null;
        _selectedTeacher = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final classroomsAsync = ref.watch(classroomsNotifierProvider);
    final subjectsAsync = ref.watch(subjectsNotifierProvider);
    final teachersAsync = ref.watch(teachersNotifierProvider);
    final lessonsAsync = ref.watch(timetableNotifierProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إسناد الدروس للمدرسين', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    classroomsAsync.when(
                      data: (classrooms) => DropdownButtonFormField<Classroom>(
                        decoration: const InputDecoration(labelText: 'اختر الصف', border: OutlineInputBorder()),
                        value: _selectedClassroom,
                        items: classrooms.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                        onChanged: (val) => setState(() => _selectedClassroom = val),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, st) => Text('خطأ: $e'),
                    ),
                    const SizedBox(height: 16),
                    subjectsAsync.when(
                      data: (subjects) => DropdownButtonFormField<Subject>(
                        decoration: const InputDecoration(labelText: 'اختر المادة', border: OutlineInputBorder()),
                        value: _selectedSubject,
                        items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                        onChanged: (val) => setState(() => _selectedSubject = val),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, st) => Text('خطأ: $e'),
                    ),
                    const SizedBox(height: 16),
                    teachersAsync.when(
                      data: (teachers) => DropdownButtonFormField<Teacher>(
                        decoration: const InputDecoration(labelText: 'اختر المدرس', border: OutlineInputBorder()),
                        value: _selectedTeacher,
                        items: teachers.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                        onChanged: (val) => setState(() => _selectedTeacher = val),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, st) => Text('خطأ: $e'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_selectedClassroom != null && _selectedSubject != null && _selectedTeacher != null) ? _assignLesson : null,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                        child: const Text('إسناد المادة وإضافتها للجدول (دروس بانتظار التوزيع)', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('الإسنادات الحالية (دروس بانتظار التوزيع)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 8),
            lessonsAsync.when(
              data: (lessons) {
                // We only show unassigned (unscheduled) lessons here, grouped by classroom/subject
                final unassigned = lessons.where((l) => l.isUnassigned).toList();
                if (unassigned.isEmpty) {
                  return const Center(child: Text('لا يوجد دروس غير مجدولة. قم بإنشاء إسناد أو توليد الجدول.'));
                }

                // Simple grouped view by classroom
                final grouped = <String, List<Lesson>>{};
                for (var l in unassigned) {
                  final key = l.classroom.value?.name ?? 'بدون صف';
                  grouped.putIfAbsent(key, () => []).add(l);
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, index) {
                    final classroomName = grouped.keys.elementAt(index);
                    final classLessons = grouped[classroomName]!;

                    // Count unique subjects
                    final subjectsMap = <String, int>{};
                    final teachersMap = <String, String>{};
                    for (var l in classLessons) {
                      final sName = l.subject.value?.name ?? 'بدون مادة';
                      subjectsMap[sName] = (subjectsMap[sName] ?? 0) + 1;
                      teachersMap[sName] = l.teacher.value?.name ?? 'بدون مدرس';
                    }

                    return ExpansionTile(
                      title: Text(classroomName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('إجمالي الدروس المطلوبة: ${classLessons.length}'),
                      children: subjectsMap.keys.map((sName) {
                        return ListTile(
                          title: Text(sName),
                          subtitle: Text('المدرس: ${teachersMap[sName] ?? 'غير محدد'}'),
                          trailing: Text('${subjectsMap[sName]} دروس', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('حدث خطأ: $e')),
            ),
          ],
        ),
      ),
    );
  }
}
