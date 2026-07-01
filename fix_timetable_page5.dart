import 'dart:io';

void main() {
  var file = File('lib/features/timetable/presentation/pages/timetable_page.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    '''  Widget _buildCell(Lesson? lesson, Classroom classroom, int dayIndex, int periodIndex) {
    if (lesson == null) {
      return DragTarget<Lesson>(
        onWillAcceptWithDetails: (details) => true,

        onAcceptWithDetails: (details) async {''',
    '''  Widget _buildCell(Lesson? lesson, Classroom classroom, int dayIndex, int periodIndex) {
    if (lesson == null) {
      return DragTarget<Lesson>(
        onWillAcceptWithDetails: (details) {
          final incoming = details.data;

          if (incoming.isPinned) return false;

          // Basic constraint checks for visual feedback without full async DB read
          // 1. Same subject already has this period allowed
          if (incoming.subject.value != null && incoming.subject.value!.allowedPeriods.isNotEmpty && !incoming.subject.value!.allowedPeriods.contains(periodIndex)) return false;
          // 2. Teacher unavailable days
          if (incoming.teacher.value != null && incoming.teacher.value!.unavailableDays.contains(dayIndex)) return false;

          return true;
        },
        onAcceptWithDetails: (details) async {'''
  );

  file.writeAsStringSync(content);
}
