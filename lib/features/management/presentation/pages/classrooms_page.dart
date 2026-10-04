// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_config.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/models/weekly_load_policy.dart';
import '../../../../core/providers/app_config_provider.dart';
import '../providers/management_provider.dart';

class ClassroomsPage extends ConsumerWidget {
  const ClassroomsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classroomsAsync = ref.watch(classroomsNotifierProvider);
    final config = ref.watch(appConfigNotifierProvider).when(
          data: (c) => c,
          loading: AppConfig.initial,
          error: (_, __) => AppConfig.initial(),
        );
    final settings = ref.watch(settingsNotifierProvider).when(
          data: (s) => s,
          loading: () => AppSettings()..periodsPerDay = 7,
          error: (_, __) => AppSettings()..periodsPerDay = 7,
        );

    return Scaffold(
      body: classroomsAsync.when(
        data: (classrooms) {
          if (classrooms.isEmpty) {
            return const Center(child: Text('لا يوجد صفوف مضافة بعد'));
          }
          return ListView.builder(
            itemCount: classrooms.length,
            itemBuilder: (context, index) {
              final classroom = classrooms[index];
              final effective = config.resolveWeeklyConfigForClassroom(
                classroom,
                daysPerWeek: settings.daysPerWeek,
              );
              final sourceLabel = effective.isOverridden
                  ? 'تخصيص مستقل'
                  : 'يستخدم الإعداد العام';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(classroom.name),
                  subtitle: Text(
                    'المرحلة: ${classroom.grade} • ${effective.weeklyTarget} حصة أسبوعيًا ($sourceLabel)',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'حذف',
                    onPressed: () => _confirmDelete(context, ref, classroom),
                  ),
                  onTap: () => _showAddOrEditDialog(context, ref, classroom),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('حدث خطأ: ' + e.toString())),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEditDialog(context, ref, null),
        tooltip: 'إضافة',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, Classroom classroom) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الصف'),
        content: Text('هل أنت متأكد من حذف "' + classroom.name + '"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref
                  .read(classroomsNotifierProvider.notifier)
                  .deleteClassroom(classroom.id);
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditDialog(
      BuildContext context, WidgetRef ref, Classroom? existingClassroom) {
    showDialog(
      context: context,
      builder: (context) =>
          _ClassroomDialog(existingClassroom: existingClassroom),
    );
  }
}

class _ClassroomDialog extends ConsumerStatefulWidget {
  final Classroom? existingClassroom;
  const _ClassroomDialog({this.existingClassroom});

  @override
  ConsumerState<_ClassroomDialog> createState() => _ClassroomDialogState();
}

class _ClassroomDialogState extends ConsumerState<_ClassroomDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _gradeController;
  late final TextEditingController _weeklyLessonsController;

  bool _useCustomOverride = false;
  bool _useCustomDaySelection = false;
  final Set<int> _selectedExtraDays = <int>{};
  String? _distributionError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingClassroom;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _gradeController = TextEditingController(text: existing?.grade ?? '');

    final hasOverride = existing?.hasWeeklyOverride ?? false;
    _useCustomOverride = hasOverride;

    final initialWeekly = existing?.weeklyLessonsOverride ?? 30;
    _weeklyLessonsController =
        TextEditingController(text: initialWeekly.toString());

    final existingDaily = existing?.dailyPeriodsOverride;
    if (existingDaily != null && existingDaily.isNotEmpty) {
      final autoDist =
          DailyDistribution.buildAutomatic(initialWeekly, existingDaily.length);
      final elevated = DailyDistribution.extractElevatedDays(existingDaily);
      _selectedExtraDays.addAll(elevated);
      if (!_listsMatch(existingDaily, autoDist)) {
        _useCustomDaySelection = true;
      }
    }
  }

  bool _listsMatch(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    _weeklyLessonsController.dispose();
    super.dispose();
  }

  int _resolveDaysPerWeek() {
    final settings = ref.read(settingsNotifierProvider).when(
          data: (s) => s,
          loading: () => null,
          error: (_, __) => null,
        );
    final days = settings?.daysPerWeek ?? 5;
    return days < 1 ? 5 : days;
  }

  int _resolveGeneralDefaultTarget(AppConfig config) {
    return WeeklyLoadResolver.resolveDefaultWeeklyTarget(
      mode: config.weeklyLoadMode,
      officialPlan: config.officialWeeklyPlan,
      schoolStage: config.schoolStage,
      grade: _gradeController.text.trim(),
      classroomName: _nameController.text.trim(),
    );
  }

  void _syncExtraDaysWithWeeklyCount(int weeklyLessons, int daysPerWeek) {
    final remainder = weeklyLessons > 0 ? weeklyLessons % daysPerWeek : 0;
    _selectedExtraDays.removeWhere((day) => day < 0 || day >= daysPerWeek);
    if (!_useCustomDaySelection) {
      _selectedExtraDays
        ..clear()
        ..addAll(List<int>.generate(remainder, (index) => index));
    }
  }

  List<int> _buildSelectedDailyPeriods(int weeklyLessons, int daysPerWeek) {
    if (!_useCustomDaySelection) {
      return DailyDistribution.buildAutomatic(weeklyLessons, daysPerWeek);
    }
    return DailyDistribution.buildWithElevatedDays(
      weeklyTarget: weeklyLessons,
      daysPerWeek: daysPerWeek,
      elevatedDays: _selectedExtraDays,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigNotifierProvider).when(
          data: (c) => c,
          loading: AppConfig.initial,
          error: (_, __) => AppConfig.initial(),
        );
    final daysPerWeek = _resolveDaysPerWeek();
    final generalTarget = _resolveGeneralDefaultTarget(config);
    final parsedWeekly =
        int.tryParse(_weeklyLessonsController.text.trim()) ?? generalTarget;
    final remainder = parsedWeekly > 0 ? parsedWeekly % daysPerWeek : 0;
    final workingDays = Weekday.workingDays(daysPerWeek);
    final previewPeriods = _useCustomOverride
        ? _buildSelectedDailyPeriods(parsedWeekly, daysPerWeek)
        : DailyDistribution.buildAutomatic(generalTarget, daysPerWeek);

    return AlertDialog(
      title: Text(widget.existingClassroom == null ? 'إضافة صف' : 'تعديل صف'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الصف/الشعبة',
                    helperText: 'مثال: الصف الأول / أ',
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'مطلوب' : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _gradeController,
                  decoration: const InputDecoration(
                    labelText: 'المرحلة الدراسية',
                    helperText: 'مثال: المتوسطة أو الصف السادس',
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'مطلوب' : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'تخصيص عدد الحصص للصف — اختياري',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'يمكنك ترك هذه الإعدادات كما هي لاستخدام الإعداد العام.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تخصيص الحصص لهذا الصف'),
                  value: _useCustomOverride,
                  onChanged: (checked) {
                    setState(() {
                      _useCustomOverride = checked ?? false;
                      _distributionError = null;
                      if (_useCustomOverride) {
                        final currentDefault =
                            _resolveGeneralDefaultTarget(config);
                        if (widget.existingClassroom?.weeklyLessonsOverride ==
                            null) {
                          _weeklyLessonsController.text =
                              currentDefault.toString();
                        }
                        final currentWeekly = int.tryParse(
                                _weeklyLessonsController.text.trim()) ??
                            currentDefault;
                        _syncExtraDaysWithWeeklyCount(
                          currentWeekly,
                          daysPerWeek,
                        );
                      }
                    });
                  },
                ),
                if (!_useCustomOverride)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'يستخدم الإعداد العام ($generalTarget حصة أسبوعيًا).',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  )
                else ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _weeklyLessonsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'عدد الحصص الأسبوعية',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (!_useCustomOverride) return null;
                      final parsed = int.tryParse(val?.trim() ?? '');
                      if (parsed == null || parsed < 1) {
                        return 'أدخل رقمًا صحيحًا أكبر من صفر';
                      }
                      final maxWeekly =
                          daysPerWeek * WeeklyLoadValidator.defaultDailyMaximum;
                      if (parsed > maxWeekly) {
                        return 'الحد الأقصى الأسبوعي هو $maxWeekly حصة';
                      }
                      return null;
                    },
                    onChanged: (val) {
                      final parsed = int.tryParse(val.trim());
                      setState(() {
                        _distributionError = null;
                        if (parsed != null && parsed > 0) {
                          _syncExtraDaysWithWeeklyCount(parsed, daysPerWeek);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'توزيع الحصص على الأيام',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: false,
                    groupValue: _useCustomDaySelection,
                    title: const Text('تلقائي'),
                    onChanged: (val) {
                      setState(() {
                        _useCustomDaySelection = false;
                        _distributionError = null;
                        _syncExtraDaysWithWeeklyCount(
                          parsedWeekly,
                          daysPerWeek,
                        );
                      });
                    },
                  ),
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: true,
                    groupValue: _useCustomDaySelection,
                    title: const Text('تخصيص الأيام'),
                    onChanged: (val) {
                      setState(() {
                        _useCustomDaySelection = true;
                        _distributionError = null;
                        if (_selectedExtraDays.isEmpty && remainder > 0) {
                          _selectedExtraDays.addAll(
                            List<int>.generate(remainder, (i) => i),
                          );
                        }
                      });
                    },
                  ),
                  if (_useCustomDaySelection && remainder > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'الأيام ذات الحصة الإضافية (اختر $remainder):',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final day in workingDays)
                          FilterChip(
                            label: Text(day.arabicLabel),
                            selected:
                                _selectedExtraDays.contains(day.indexPosition),
                            onSelected: (selected) {
                              setState(() {
                                _distributionError = null;
                                if (selected) {
                                  if (remainder == 1) {
                                    _selectedExtraDays
                                      ..clear()
                                      ..add(day.indexPosition);
                                  } else {
                                    _selectedExtraDays.add(day.indexPosition);
                                  }
                                } else {
                                  _selectedExtraDays.remove(day.indexPosition);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'التوزيع اليومي: ' +
                          workingDays
                              .map((d) =>
                                  '${d.arabicLabel} (${previewPeriods[d.indexPosition]})')
                              .join(' ، '),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.teal.shade900,
                      ),
                    ),
                  ),
                  if (_distributionError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _distributionError!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('حفظ'),
        ),
      ],
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final classroom = widget.existingClassroom ?? Classroom();
    classroom
      ..name = _nameController.text.trim()
      ..grade = _gradeController.text.trim();

    if (!_useCustomOverride) {
      classroom.weeklyOverride = null;
    } else {
      final daysPerWeek = _resolveDaysPerWeek();
      final weeklyLessons =
          int.parse(_weeklyLessonsController.text.trim());
      final dailyPeriods =
          _buildSelectedDailyPeriods(weeklyLessons, daysPerWeek);

      final validation = WeeklyLoadValidator.validate(
        weeklyTarget: weeklyLessons,
        daysPerWeek: daysPerWeek,
        dailyPeriods: dailyPeriods,
      );
      if (!validation.isValid) {
        setState(() {
          _distributionError = validation.errorMessage;
        });
        return;
      }

      classroom.weeklyOverride = ClassroomWeeklyOverride(
        weeklyLessons: weeklyLessons,
        dailyPeriods: _useCustomDaySelection ? dailyPeriods : null,
      );
    }

    ref.read(classroomsNotifierProvider.notifier).addClassroom(classroom);
    Navigator.pop(context);
  }
}
