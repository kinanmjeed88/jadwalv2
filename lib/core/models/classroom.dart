import 'package:isar/isar.dart';

part 'classroom.g.dart';

@collection
class Classroom {
  Id id = Isar.autoIncrement;

  /// E.g., "شعبة أ"
  late String name;

  /// E.g., "الصف الأول"
  late String grade;
}
