import 'subject_constraint.dart';

/// مفتاح منطقي لقيد مادة: المرحلة/الصف + اسم المادة.
///
/// قاعدة البيانات تُخزّن القيد كصفّين نصّيين ([SubjectConstraint.grade] و
/// [SubjectConstraint.subjectName])، لذلك نحتاج غلافًا موحّدًا يُقارَن به
/// ويُخزَّن في ملف الإعدادات دون لبس. تُستخدم فاصلة تحكّم غير مرئية حتى لا
/// تتضارب الأسماء العربية التي قد تحتوي على محارف عادية مثل `-` أو `:`.
class SubjectConstraintKey {
  const SubjectConstraintKey({
    required this.grade,
    required this.subjectName,
  });

  /// المرحلة أو الصف كما هو مخزَّن في [Classroom.grade].
  final String grade;

  /// اسم المادة كما هو مخزَّن في [Subject.name].
  final String subjectName;

  static const String _separator = '\u001F';

  /// الصيغة المخزَّنة في ملف الإعدادات (مفاتيح خريطة JSON).
  String get storageKey => '$grade$_separator$subjectName';

  /// يبني المفتاح من قيد مادة مُخزَّن.
  static SubjectConstraintKey fromConstraint(SubjectConstraint constraint) {
    return SubjectConstraintKey(
      grade: constraint.grade,
      subjectName: constraint.subjectName,
    );
  }

  /// يستعيد المفتاح من [storageKey]، ويعيد `null` إذا كانت القيمة تالفة.
  static SubjectConstraintKey? tryParse(Object? storageKey) {
    if (storageKey is! String) {
      return null;
    }

    final separatorIndex = storageKey.indexOf(_separator);
    if (separatorIndex <= 0 || separatorIndex >= storageKey.length - 1) {
      return null;
    }

    return SubjectConstraintKey(
      grade: storageKey.substring(0, separatorIndex),
      subjectName: storageKey.substring(separatorIndex + 1),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SubjectConstraintKey &&
        other.grade == grade &&
        other.subjectName == subjectName;
  }

  @override
  int get hashCode => Object.hash(grade, subjectName);

  @override
  String toString() => '$subjectName - $grade';
}
