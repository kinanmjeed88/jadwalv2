import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/subject.dart';
import '../../../../core/utils/period_mapper.dart';
import '../providers/management_provider.dart';

class SubjectsPage extends ConsumerWidget {
  const SubjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsNotifierProvider);

    return Scaffold(
      body: subjectsAsync.when(
        data: (subjects) {
          if (subjects.isEmpty) {
            return const Center(child: Text('لا يوجد مواد مضافة بعد'));
          }
          return ListView.builder(
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(subject.name),
                  subtitle: Text(
                      'الدروس الأسبوعية: ' + subject.lessonsPerWeek.toString()),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'حذف',
                    onPressed: () => _confirmDelete(context, ref, subject),
                  ),
                  onTap: () => _showAddOrEditDialog(context, ref, subject),
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

  void _confirmDelete(BuildContext context, WidgetRef ref, Subject subject) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المادة'),
        content: Text('هل أنت متأكد من حذف المادة "' + subject.name + '"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref
                  .read(subjectsNotifierProvider.notifier)
                  .deleteSubject(subject.id);
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditDialog(
      BuildContext context, WidgetRef ref, Subject? existingSubject) {
    showDialog(
      context: context,
      builder: (context) => _SubjectDialog(existingSubject: existingSubject),
    );
  }
}

class _SubjectDialog extends ConsumerStatefulWidget {
  final Subject? existingSubject;
  const _SubjectDialog({this.existingSubject});

  @override
  ConsumerState<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends ConsumerState<_SubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late int _lessonsPerWeek;
  late bool _preferEarlyPeriods;
  late List<int> _allowedPeriods;

  @override
  void initState() {
    super.initState();
    _name = widget.existingSubject?.name ?? '';
    _lessonsPerWeek = widget.existingSubject?.lessonsPerWeek ?? 1;
    _preferEarlyPeriods = widget.existingSubject?.preferEarlyPeriods ?? false;
    _allowedPeriods = List.from(widget.existingSubject?.allowedPeriods ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsNotifierProvider);

    return AlertDialog(
      title: Text(widget.existingSubject == null ? 'إضافة مادة' : 'تعديل مادة'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(
                    labelText: 'اسم المادة', helperText: 'مثال: رياضيات, علوم'),
                validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
                onSaved: (val) => _name = val!,
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: _lessonsPerWeek.toString(),
                decoration: const InputDecoration(
                    labelText: 'الدروس الأسبوعية',
                    helperText: 'عدد الدروس المطلوبة خلال الأسبوع'),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || int.tryParse(val) == null
                    ? 'أدخل رقماً صحيحاً'
                    : null,
                onSaved: (val) => _lessonsPerWeek = int.parse(val!),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('تفضيل الدروس المبكرة'),
                value: _preferEarlyPeriods,
                onChanged: (val) =>
                    setState(() => _preferEarlyPeriods = val ?? false),
              ),
              const SizedBox(height: 10),
              const ListTile(
                title: Text('القيود الزمنية (الدروس المسموحة للمادة)'),
                subtitle: Text(
                    'تحديد درس معين هنا يجبر النظام على جدولة هذه المادة في هذا الوقت حصراً (مثلاً: إجبار مادة الرياضة لتكون دائماً في الدرس الأخير)'),
                contentPadding: EdgeInsets.zero,
              ),
              settingsAsync.when(
                data: (settings) {
                  return Wrap(
                    spacing: 8,
                    children: List.generate(settings.periodsPerDay, (index) {
                      final isSelected = _allowedPeriods.contains(index);
                      return FilterChip(
                        label: Text(PeriodMapper.toArabicName(index)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _allowedPeriods.add(index);
                            } else {
                              _allowedPeriods.remove(index);
                            }
                          });
                        },
                      );
                    }),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, st) => const Text('خطأ في تحميل الإعدادات'),
              ),
            ],
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
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final subject = widget.existingSubject ?? Subject();
      subject
        ..name = _name
        ..lessonsPerWeek = _lessonsPerWeek
        ..preferEarlyPeriods = _preferEarlyPeriods
        ..allowedPeriods = _allowedPeriods;

      ref.read(subjectsNotifierProvider.notifier).addSubject(subject);
      Navigator.pop(context);
    }
  }
}
