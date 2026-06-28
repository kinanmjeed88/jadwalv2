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
    if (_selectedClassroom != null &&
        _selectedSubject != null &&
        _selectedTeacher != null) {
      ref.read(timetableNotifierProvider.notifier).assignLessonsToPool(
            _selectedClassroom!,
            _selectedSubject!,
            _selectedTeacher!,
          );
      final subjectName = _selectedSubject!.name;
      final classroomName = _selectedClassroom!.name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تم إسناد مادة ' +
                subjectName +
                ' لـ ' +
                classroomName +
                ' بنجاح')),
      );
      setState(() {
        _selectedSubject = null;
        _selectedTeacher = null;
      });
    }
  }

  void _showEditAssignmentDialog(BuildContext context, Lesson lesson) {
    Teacher? newTeacher = lesson.teacher.value;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          final teachersAsync = ref.watch(teachersNotifierProvider);
          return AlertDialog(
            title: const Text('تعديل المدرس للمادة'),
            content: teachersAsync.when(
              data: (teachers) => DropdownButtonFormField<Teacher>(
                decoration: const InputDecoration(
                    labelText: 'اختر المدرس',
                    border: OutlineInputBorder()),
                value: teachers.where((t) => t.id == newTeacher?.id).firstOrNull,
                items: teachers
                    .map((t) => DropdownMenuItem(
                        value: t, child: Text(t.name)))
                    .toList(),
                onChanged: (val) =>
                    setState(() => newTeacher = val),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, st) => Text('خطأ: ' + e.toString()),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء')),
              TextButton(
                onPressed: () {
                  if (lesson.classroom.value != null && lesson.subject.value != null && newTeacher != null) {
                    ref.read(timetableNotifierProvider.notifier).updateAssignment(
                        lesson.classroom.value!.id,
                        lesson.subject.value!.id,
                        newTeacher!);
                  }
                  Navigator.pop(context);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        });
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final classroomsAsync = ref.watch(classroomsNotifierProvider);
    final subjectsAsync = ref.watch(subjectsNotifierProvider);
    final teachersAsync = ref.watch(teachersNotifierProvider);
    final lessonsAsync = ref.watch(timetableNotifierProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إسناد الدروس للمدرسين',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal)),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          classroomsAsync.when(
                            data: (classrooms) =>
                                DropdownButtonFormField<Classroom>(
                              decoration: const InputDecoration(
                                  labelText: 'اختر الصف',
                                  border: OutlineInputBorder()),
                              value: _selectedClassroom,
                              items: classrooms
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c.name)))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedClassroom = val),
                            ),
                            loading: () => const CircularProgressIndicator(),
                            error: (e, st) => Text('خطأ: ' + e.toString()),
                          ),
                          const SizedBox(height: 16),
                          subjectsAsync.when(
                            data: (subjects) =>
                                DropdownButtonFormField<Subject>(
                              decoration: const InputDecoration(
                                  labelText: 'اختر المادة',
                                  border: OutlineInputBorder()),
                              value: _selectedSubject,
                              items: subjects
                                  .map((s) => DropdownMenuItem(
                                      value: s, child: Text(s.name)))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedSubject = val),
                            ),
                            loading: () => const CircularProgressIndicator(),
                            error: (e, st) => Text('خطأ: ' + e.toString()),
                          ),
                          const SizedBox(height: 16),
                          teachersAsync.when(
                            data: (teachers) =>
                                DropdownButtonFormField<Teacher>(
                              decoration: const InputDecoration(
                                  labelText: 'اختر المدرس',
                                  border: OutlineInputBorder()),
                              value: _selectedTeacher,
                              items: teachers
                                  .map((t) => DropdownMenuItem(
                                      value: t, child: Text(t.name)))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedTeacher = val),
                            ),
                            loading: () => const CircularProgressIndicator(),
                            error: (e, st) => Text('خطأ: ' + e.toString()),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (_selectedClassroom != null &&
                                      _selectedSubject != null &&
                                      _selectedTeacher != null)
                                  ? _assignLesson
                                  : null,
                              style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(16)),
                              child: const Text(
                                  'إسناد المادة وإضافتها للجدول (دروس بانتظار التوزيع)',
                                  style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('الإسنادات الحالية (دروس بانتظار التوزيع)',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          lessonsAsync.when(
            data: (lessons) {
              final unassigned = lessons.where((l) => l.isUnassigned).toList();
              if (unassigned.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(
                      child: Text(
                          'لا يوجد دروس غير مجدولة. قم بإنشاء إسناد أو توليد الجدول.')),
                );
              }

              final grouped = <String, List<Lesson>>{};
              for (var l in unassigned) {
                final key = l.classroom.value?.name ?? 'بدون صف';
                grouped.putIfAbsent(key, () => []).add(l);
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final classroomName = grouped.keys.elementAt(index);
                      final classLessons = grouped[classroomName]!;

                      final subjectsMap = <String, int>{};
                      final teachersMap = <String, String>{};
                      for (var l in classLessons) {
                        final sName = l.subject.value?.name ?? 'بدون مادة';
                        subjectsMap[sName] = (subjectsMap[sName] ?? 0) + 1;
                        teachersMap[sName] =
                            l.teacher.value?.name ?? 'بدون مدرس';
                      }

                      return ExpansionTile(
                        title: Text(classroomName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('إجمالي الدروس المطلوبة: ' +
                            classLessons.length.toString()),
                        children: subjectsMap.keys.map((sName) {
                          final subjectLesson = classLessons.firstWhere((l) => (l.subject.value?.name ?? 'بدون مادة') == sName);
                          return ListTile(
                            title: Text(sName),
                            subtitle: Text('المدرس: ' +
                                (teachersMap[sName] ?? 'غير محدد')),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                    subjectsMap[sName].toString() + ' دروس',
                                    style: const TextStyle(
                                        color: Colors.teal,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {
                                    _showEditAssignmentDialog(context, subjectLesson);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    if (subjectLesson.classroom.value != null && subjectLesson.subject.value != null) {
                                      ref.read(timetableNotifierProvider.notifier).deleteAssignment(
                                          subjectLesson.classroom.value!.id,
                                          subjectLesson.subject.value!.id);
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                    childCount: grouped.keys.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator())),
            error: (e, st) => SliverToBoxAdapter(
                child: Center(child: Text('حدث خطأ: ' + e.toString()))),
          ),
        ],
      ),
    );
  }
}
