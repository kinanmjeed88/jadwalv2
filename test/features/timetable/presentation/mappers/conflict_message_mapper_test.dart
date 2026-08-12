import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/exceptions/conflict_reason.dart';
import 'package:jadwal_v2/features/timetable/presentation/mappers/conflict_message_mapper.dart';

void main() {
  group('ConflictMessageMapper Tests', () {
    test('TeacherLoadExceeded returns correct message', () {
      const reason = TeacherLoadExceeded('أحمد', 22, 20);
      final message = ConflictMessageMapper.toArabicMessage(reason);
      expect(message, 'المعلم "أحمد" تجاوز الحد الأقصى (20 حصة)، بينما المطلوب (22 حصة).');
    });

    test('InsufficientDaysForSubject returns correct message', () {
      const reason = InsufficientDaysForSubject('الرياضيات', 8, 5);
      final message = ConflictMessageMapper.toArabicMessage(reason);
      expect(message, 'مادة "الرياضيات" تحتاج 8 حصص وعدد الأيام المتاحة 5 فقط.');
    });

    test('TeacherTimeSlotConflict returns correct message', () {
      const reason = TeacherTimeSlotConflict('خالد', 0, 2); // Day 1, Period 3
      final message = ConflictMessageMapper.toArabicMessage(reason);
      expect(message, 'تعارض في وقت المعلم "خالد" يوم 1 الحصة 3.');
    });

    test('UnassignedSubject returns correct message', () {
      const reason = UnassignedSubject('العلوم', 'لم يتم تعيين معلم');
      final message = ConflictMessageMapper.toArabicMessage(reason);
      expect(message, 'المادة "العلوم": لم يتم تعيين معلم');
    });

    test('GenericSolverFailure returns correct message', () {
      const reason = GenericSolverFailure('خطأ في التوليد');
      final message = ConflictMessageMapper.toArabicMessage(reason);
      expect(message, 'خطأ عام في التوليد: خطأ في التوليد');
    });
  });
}
