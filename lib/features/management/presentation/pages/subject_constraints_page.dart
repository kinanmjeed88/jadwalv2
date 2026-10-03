import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../../../core/models/classroom.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/subject_constraint.dart';
import '../../../../core/models/subject_constraint_key.dart';
import '../../../../core/models/subject_consecutiveness.dart';
import '../../../../core/providers/app_config_provider.dart';
import '../../../../core/providers/database_provider.dart';
import '../providers/management_provider.dart';
import '../providers/subject_constraint_auto_sync_provider.dart';

class SubjectConstraintsPage extends ConsumerStatefulWidget {
  const SubjectConstraintsPage({super.key});

  @override
  ConsumerState<SubjectConstraintsPage> createState() =>
      _SubjectConstraintsPageState();
}

class _SubjectConstraintsPageState
    extends ConsumerState<SubjectConstraintsPage> {
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
    final grades =
        classrooms.map((classroom) => classroom.grade).toSet().toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _constraints = constraints;
      _subjects = subjects;
      _grades = grades;
    });
  }

  Subject? _subjectByName(String? subjectName) {
    if (subjectName == null) {
      return null;
    }

    for (final subject in _subjects) {
      if (subject.name == subjectName) {
        return subject;
      }
    }

    return null;
  }

  Future<void> _saveConstraint({
    required int? constraintId,
    required String grade,
    required String subjectName,
    required int maxPeriods,
    required SubjectConsecutiveness consecutiveness,
  }) async {
    await ref.read(subjectsNotifierProvider.notifier).saveSubjectConstraint(
          constraintId: constraintId,
          grade: grade,
          subjectName: subjectName,
          maxPeriodsPerDay: maxPeriods,
          consecutiveness: consecutiveness,
        );

    // القيد الذي يكتبه المستخدم يدويًا يصبح ملكًا له، فتتوقف المزامنة التلقائية
    // عن إدارته ولا تعيد إنشاءه إن حذفه لاحقًا.
    await ref.read(subjectConstraintAutoSyncProvider).recordManualDefinition(
          SubjectConstraintKey(grade: grade, subjectName: subjectName),
        );

    await _loadData();
  }

  Future<void> _deleteConstraint(SubjectConstraint constraint) async {
    await ref.read(subjectConstraintAutoSyncProvider).recordManualDeletion(
          SubjectConstraintKey.fromConstraint(constraint),
        );

    final isar = await ref.read(isarDatabaseProvider.future);
    await isar.writeTxn(() async {
      await isar.subjectConstraints.delete(constraint.id);
    });
    await _loadData();
  }

  void _showConstraintDialog({SubjectConstraint? existingConstraint}) {
    String? selectedGrade = existingConstraint?.grade ??
        (_grades.isNotEmpty ? _grades.first : null);
    String? selectedSubject = existingConstraint?.subjectName ??
        (_subjects.isNotEmpty ? _subjects.first.name : null);
    int maxPeriods = existingConstraint?.maxPeriodsPerDay ?? 2;
    SubjectConsecutiveness selectedConsecutiveness =
        _subjectByName(selectedSubject)?.consecutiveness ??
            SubjectConsecutiveness.any;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(
            existingConstraint == null ? 'إضافة قيد مادة' : 'تعديل قيد مادة',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_grades.isEmpty)
                  const Text('لا يوجد صفوف مضافة')
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey(selectedGrade),
                    initialValue: selectedGrade,
                    decoration: const InputDecoration(
                      labelText: 'المرحلة / الصف',
                    ),
                    items: _grades
                        .map(
                          (grade) => DropdownMenuItem(
                            value: grade,
                            child: Text(grade),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setStateDialog(() => selectedGrade = value);
                    },
                  ),
                const SizedBox(height: 16),
                if (_subjects.isEmpty)
                  const Text('لا يوجد مواد مضافة')
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey(selectedSubject),
                    initialValue: selectedSubject,
                    decoration: const InputDecoration(labelText: 'المادة'),
                    items: _subjects
                        .map(
                          (subject) => DropdownMenuItem(
                            value: subject.name,
                            child: Text(subject.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedSubject = value;
                        selectedConsecutiveness =
                            _subjectByName(value)?.consecutiveness ??
                                SubjectConsecutiveness.any;
                      });
                    },
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: maxPeriods.toString(),
                  decoration: const InputDecoration(
                    labelText: 'الحد الأقصى للحصص في اليوم',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    maxPeriods = int.tryParse(value) ?? 1;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SubjectConsecutiveness>(
                  key: ValueKey(selectedConsecutiveness),
                  initialValue: selectedConsecutiveness,
                  decoration: const InputDecoration(
                    labelText: 'سياسة تتابع الحصص',
                    helperText:
                        'تُحفظ هذه السياسة مع المادة وتطبق على توليد الجدول',
                  ),
                  items: const [
                    SubjectConsecutiveness.consecutive,
                    SubjectConsecutiveness.nonConsecutive,
                    SubjectConsecutiveness.any,
                  ]
                      .map(
                        (option) => DropdownMenuItem(
                          value: option,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setStateDialog(() => selectedConsecutiveness = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed:
                  isSaving || selectedGrade == null || selectedSubject == null
                      ? null
                      : () async {
                          setStateDialog(() => isSaving = true);
                          try {
                            await _saveConstraint(
                              constraintId: existingConstraint?.id,
                              grade: selectedGrade!,
                              subjectName: selectedSubject!,
                              maxPeriods: maxPeriods,
                              consecutiveness: selectedConsecutiveness,
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (_) {
                            if (context.mounted) {
                              setStateDialog(() => isSaving = false);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('تعذر حفظ قيد المادة'),
                                ),
                              );
                            }
                          }
                        },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigNotifierProvider).valueOrNull;
    final managedAutoConstraints =
        config?.managedAutoConstraints ?? const <String, int>{};
    final isPrimaryStage =
        config?.schoolStage.enablesAutomaticConstraintBypass ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('قيود المواد')),
      body: Column(
        children: [
          if (isPrimaryStage) _buildPrimaryStageBanner(context),
          Expanded(
            child: _constraints.isEmpty
                ? const Center(
                    child: Text(
                        'لا توجد قيود مخصصة. كل المواد حدها حصة واحدة يومياً.'),
                  )
                : ListView.builder(
                    itemCount: _constraints.length,
                    itemBuilder: (context, index) {
                      final constraint = _constraints[index];
                      final key =
                          SubjectConstraintKey.fromConstraint(constraint);
                      final isAutoManaged =
                          managedAutoConstraints[key.storageKey] ==
                              constraint.maxPeriodsPerDay;
                      final subject =
                          _subjectByName(constraint.subjectName);
                      final consecutiveness = subject?.consecutiveness ??
                          SubjectConsecutiveness.any;

                      return ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${constraint.subjectName} - ${constraint.grade}',
                              ),
                            ),
                            if (isAutoManaged)
                              const Chip(
                                label: Text('تلقائي'),
                                labelStyle: TextStyle(fontSize: 11),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                          ],
                        ),
                        subtitle: Text(
                          'الحد الأقصى: ${constraint.maxPeriodsPerDay} حصص/يوم\n'
                          'التتابع: ${consecutiveness.label}'
                          '${isAutoManaged ? '\nقيد أنشأه النظام للمرحلة الابتدائية، ويمكنك تعديله أو حذفه.' : ''}',
                        ),
                        isThreeLine: true,
                        onTap: () => _showConstraintDialog(
                          existingConstraint: constraint,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'تعديل',
                              onPressed: () => _showConstraintDialog(
                                existingConstraint: constraint,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'حذف',
                              onPressed: () => _deleteConstraint(constraint),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showConstraintDialog,
        tooltip: 'إضافة قيد',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// تنبيه يشرح سياسة القيود التلقائية عند اختيار المرحلة الابتدائية.
  Widget _buildPrimaryStageBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, size: 20, color: Colors.teal.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'المرحلة الابتدائية: يُنشئ التطبيق قيودًا تلقائية لأي مادة '
              'نصابها الأسبوعي ٦ حصص أو أكثر (اللغة العربية والرياضيات غالبًا) '
              'بدءًا من قاعدة الست حصص (حصتان في اليوم)، وتُحدَّث هذه القيود '
              'تلقائيًا عند تغيير عدد الحصص. القيود المعلّمة بـ«تلقائي» قابلة '
              'للتعديل والحذف.',
              style: TextStyle(fontSize: 12.5, color: Colors.teal.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
