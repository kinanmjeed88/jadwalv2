import 'dart:io';

void main() {
  var file = File('lib/features/timetable/presentation/pages/timetable_page.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    '''            child: Container(
              width: 80,
              height: 40,
              decoration: BoxDecoration(
                color: lesson.isPinned
                    ? Colors.orange.shade100
                    : (candidateData.isNotEmpty ? Colors.teal.shade100 : Colors.transparent),
                border: lesson.isPinned ? Border.all(color: Colors.orange, width: 2) : null,
              ),''',
    '''            child: Container(
              width: 80,
              height: 40,
              decoration: BoxDecoration(
                color: lesson.isPinned
                    ? Colors.orange.shade100
                    : (candidateData.isNotEmpty ? Colors.red.shade100 : Colors.teal.shade50), // Show invalid by default on hover, valid handled elsewhere
                border: lesson.isPinned ? Border.all(color: Colors.orange, width: 2) : null,
              ),'''
  );

  // Wait, I actually need to make drag hover smart. Let's do it in `_buildCell`'s builder.
  // Actually, standard Flutter Draggable doesn't easily let candidateData know if it's valid without state.
  // But onWillAcceptWithDetails returns true/false which controls candidateData/rejectedData.

  content = content.replaceFirst(
    '''      onWillAcceptWithDetails: (details) {
        final incoming = details.data;
        return incoming.id != lesson.id;
      },''',
    '''      onWillAcceptWithDetails: (details) {
        final incoming = details.data;
        return incoming.id != lesson.id && !lesson.isPinned;
      },'''
  );

  content = content.replaceFirst(
    '''        onWillAcceptWithDetails: (details) => true,''',
    '''        onWillAcceptWithDetails: (details) => true,'' // Simplified to just accept, logic inside onAccept handles errors
    '''
  );

  file.writeAsStringSync(content);
}
