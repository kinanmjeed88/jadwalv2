import 'package:isar/isar.dart';

part 'subject_constraint.g.dart';

@collection
class SubjectConstraint {
  Id id = Isar.autoIncrement;

  late String grade; // E.g., "الصف الأول", "الصف الرابع"
  late String subjectName; // E.g., "اللغة العربية", "الرياضيات"

  /// The maximum number of periods allowed per day for this subject in this grade
  late int maxPeriodsPerDay;
}
