import 'dart:io';

void main() {
  var file = File('lib/features/timetable/presentation/pages/timetable_page.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    '''        builder: (context, candidateData, rejectedData) {
          return Container(
            width: 80,
            height: 40,
            decoration: BoxDecoration(
              color: candidateData.isNotEmpty ? Colors.green.withValues(alpha: 0.3) : Colors.transparent,
            ),
          );
        },''',
    '''        builder: (context, candidateData, rejectedData) {
          return Container(
            width: 80,
            height: 40,
            decoration: BoxDecoration(
              color: candidateData.isNotEmpty
                  ? Colors.green.withValues(alpha: 0.3)
                  : (rejectedData.isNotEmpty ? Colors.red.withValues(alpha: 0.3) : Colors.transparent),
            ),
          );
        },'''
  );

  file.writeAsStringSync(content);
}
