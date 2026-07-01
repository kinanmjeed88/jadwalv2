import 'dart:io';

void main() {
  var file = File('lib/features/management/presentation/pages/assignments_page.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    'const SizedBox(height: 16),\n                          teachersAsync.when(',
    '''const SizedBox(height: 16),
                          // Capacity Indicator
                          if (_selectedTeacher != null)
                            lessonsAsync.when(
                              data: (lessons) {
                                int assignedHours = lessons.where((l) => l.teacher.value?.id == _selectedTeacher!.id).length;
                                int maxHours = _selectedTeacher!.maxLessonsPerWeek;
                                int remaining = maxHours - assignedHours;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: remaining > 0 ? Colors.green.shade100 : Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'الحصص المتبقية للمدرس: \$remaining / \$maxHours',
                                      style: TextStyle(
                                        color: remaining > 0 ? Colors.green.shade800 : Colors.red.shade800,
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                  ),
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (e, st) => const SizedBox.shrink(),
                            ),
                          teachersAsync.when('''
  );

  file.writeAsStringSync(content);
}
