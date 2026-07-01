import 'dart:io';

void main() {
  var file = File('lib/features/management/presentation/pages/assignments_page.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    '''  void _assignLesson() {
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
  }''',
    '''  Future<void> _assignLesson() async {
    if (_selectedClassroom != null &&
        _selectedSubject != null &&
        _selectedTeacher != null) {
      final (success, errorMessage) = await ref.read(timetableNotifierProvider.notifier).assignLessonsToPool(
            _selectedClassroom!,
            _selectedSubject!,
            _selectedTeacher!,
          );

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage ?? 'حدث خطأ غير معروف'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final subjectName = _selectedSubject!.name;
      final classroomName = _selectedClassroom!.name;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إسناد مادة ' +
                subjectName +
                ' لـ ' +
                classroomName +
                ' بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedSubject = null;
          _selectedTeacher = null;
        });
      }
    }
  }'''
  );

  file.writeAsStringSync(content);
}
