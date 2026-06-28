import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/classroom.dart';
import '../providers/management_provider.dart';

class ClassroomsPage extends ConsumerWidget {
  const ClassroomsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classroomsAsync = ref.watch(classroomsNotifierProvider);

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
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(classroom.name),
                  subtitle: Text('المرحلة: ' + classroom.grade),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
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
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Classroom classroom) {
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
              ref.read(classroomsNotifierProvider.notifier).deleteClassroom(classroom.id);
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditDialog(BuildContext context, WidgetRef ref, Classroom? existingClassroom) {
    showDialog(
      context: context,
      builder: (context) => _ClassroomDialog(existingClassroom: existingClassroom),
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
  late String _name;
  late String _grade;

  @override
  void initState() {
    super.initState();
    _name = widget.existingClassroom?.name ?? '';
    _grade = widget.existingClassroom?.grade ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingClassroom == null ? 'إضافة صف' : 'تعديل صف'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(
                  labelText: 'اسم الصف/الشعبة',
                  helperText: 'مثال: الصف الأول / أ'),
              validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
              onSaved: (val) => _name = val!,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _grade,
              decoration: const InputDecoration(
                  labelText: 'المرحلة الدراسية',
                  helperText: 'مثال: المتوسطة'),
              validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
              onSaved: (val) => _grade = val!,
            ),
          ],
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
      final classroom = widget.existingClassroom ?? Classroom();
      classroom
        ..name = _name
        ..grade = _grade;

      ref.read(classroomsNotifierProvider.notifier).addClassroom(classroom);
      Navigator.pop(context);
    }
  }
}
