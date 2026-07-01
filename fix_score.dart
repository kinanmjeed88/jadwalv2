import 'dart:io';

void main() {
  var file = File('lib/features/timetable/domain/usecases/timetable_generator.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll(
    'score -= lesson.teacher.value!.unavailableDays.length * maxPeriods;',
    'score -= (lesson.teacher.value!.unavailableDays.length * maxPeriods).toInt();'
  );
  content = content.replaceAll(
    'score -= maxDays * restrictedPeriods;',
    'score -= (maxDays * restrictedPeriods).toInt();'
  );
  content = content.replaceAll(
    'score += lesson.teacher.value!.maxLessonsPerWeek;',
    'score += (lesson.teacher.value!.maxLessonsPerWeek).toInt();'
  );
  file.writeAsStringSync(content);
}
