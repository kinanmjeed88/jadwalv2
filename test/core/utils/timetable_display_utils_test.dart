import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/utils/timetable_display_utils.dart';

void main() {
  group('timetable display utilities', () {
    test('cleans the subject and builds a single-line label', () {
      expect(
        formatTimetableCellLabel(
          subjectName: 'رياضيات (متقدم)',
          companionName: 'حوراء أحمد',
        ),
        'رياضيات | حوراء أحمد',
      );
    });

    test('uses safe fallbacks for missing values', () {
      expect(
        formatTimetableCellLabel(subjectName: null, companionName: ' '),
        '- | -',
      );
    });

    test('extracts the first name token without creating empty values', () {
      expect(firstTimetableName('  حوراء أحمد  '), 'حوراء');
      expect(firstTimetableName(null), '-');
      expect(firstTimetableName('   '), '-');
    });

    test('normalizes whitespace-only values with a custom fallback', () {
      expect(
        normalizeTimetableDisplayValue(' ', fallback: 'فارغ'),
        'فارغ',
      );
    });
  });
}
