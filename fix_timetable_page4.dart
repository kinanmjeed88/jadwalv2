import 'dart:io';

void main() {
  var file = File('lib/features/timetable/presentation/pages/timetable_page.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    '''        onWillAcceptWithDetails: (details) => true,'' // Simplified to just accept, logic inside onAccept handles errors
    ''',
    '''        onWillAcceptWithDetails: (details) => true,
    '''
  );

  file.writeAsStringSync(content);
}
