import "package:isar/isar.dart";
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/models/subject_constraint.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/classroom.dart';

class SubjectConstraintsPage extends ConsumerStatefulWidget {
  const SubjectConstraintsPage({super.key});

  @override
  ConsumerState<SubjectConstraintsPage> createState() => _SubjectConstraintsPageState();
}

class _SubjectConstraintsPageState extends ConsumerState<SubjectConstraintsPage> {
  List<SubjectConstraint> _constraints = [];
  List<Subject> _subjects = [];
  List<String> _grades = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final isar = await ref.read(isarDatabaseProvider.future);
    final constraints = await isar.subjectConstraints.where().findAll();
    final subjects = await isar.subjects.where().findAll();
    final classrooms = await isar.classrooms.where().findAll();

    final grades = classrooms.map((c) => c.grade).toSet().toList();

    setState(() {
      _constraints = constraints;
      _subjects = subjects;
      _grades = grades;
    });
  }

  Future<void> _addOrUpdateConstraint(String grade, String subjectName, int maxPeriods) async {
    final isar = await ref.read(isarDatabaseProvider.future);

    await isar.writeTxn(() async {
      final existing = await isar.subjectConstraints.filter()
          .gradeEqualTo(grade)
          .and()
          .subjectNameEqualTo(subjectName)
          .findFirst();

      if (existing != null) {
        existing.maxPeriodsPerDay = maxPeriods;
        await isar.subjectConstraints.put(existing);
      } else {
        final newConstraint = SubjectConstraint()
          ..grade = grade
          ..subjectName = subjectName
          ..maxPeriodsPerDay = maxPeriods;
        await isar.subjectConstraints.put(newConstraint);
      }
    });

    _loadData();
  }

  Future<void> _deleteConstraint(int id) async {
    final isar = await ref.read(isarDatabaseProvider.future);
    await isar.writeTxn(() async {
      await isar.subjectConstraints.delete(id);
    });
    _loadData();
  }

  void _showAddDialog() {
    String? selectedGrade = _grades.isNotEmpty ? _grades.first : null;
    String? selectedSubject = _subjects.isNotEmpty ? _subjects.first.name : null;
    int maxPeriods = 2;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('إضافة قيد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_grades.isEmpty) const Text('لا يوجد صفوف مضافة')
              else DropdownButtonFormField<String>(
                value: selectedGrade,
                decoration: const InputDecoration(labelText: 'المرحلة / الصف'),
                items: _grades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) => setStateDialog(() => selectedGrade = val),
              ),
              const SizedBox(height: 16),
              if (_subjects.isEmpty) const Text('لا يوجد مواد مضافة')
              else DropdownButtonFormField<String>(
                value: selectedSubject,
                decoration: const InputDecoration(labelText: 'المادة'),
                items: _subjects.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name))).toList(),
                onChanged: (val) => setStateDialog(() => selectedSubject = val),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: maxPeriods.toString(),
                decoration: const InputDecoration(labelText: 'الحد الأقصى للحصص في اليوم'),
                keyboardType: TextInputType.number,
                onChanged: (val) => maxPeriods = int.tryParse(val) ?? 1,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                if (selectedGrade != null && selectedSubject != null) {
                  _addOrUpdateConstraint(selectedGrade!, selectedSubject!, maxPeriods);
                }
                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قيود المواد (الحد الأقصى اليومي)')),
      body: _constraints.isEmpty
          ? const Center(child: Text('لا توجد قيود مخصصة. كل المواد حدها حصة واحدة يومياً.'))
          : ListView.builder(
              itemCount: _constraints.length,
              itemBuilder: (context, index) {
                final constraint = _constraints[index];
                return ListTile(
                  title: Text('${constraint.subjectName} - ${constraint.grade}'),
                  subtitle: Text('الحد الأقصى: ${constraint.maxPeriodsPerDay} حصص/يوم'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteConstraint(constraint.id),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
