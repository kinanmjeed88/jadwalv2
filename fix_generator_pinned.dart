import 'dart:io';

void main() {
  var file = File('lib/features/timetable/domain/usecases/timetable_generator.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    '''      bool isPinned = false;
      try {
        isPinned = (l as dynamic).isPinned ?? false;
      } catch (_) {}

      if (isPinned && l.dayIndex != null && l.periodIndex != null) {''',
    '''      if (l.isPinned && l.dayIndex != null && l.periodIndex != null) {'''
  );

  file.writeAsStringSync(content);
}
