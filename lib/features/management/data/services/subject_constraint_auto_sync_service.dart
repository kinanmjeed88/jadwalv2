import 'package:isar/isar.dart';

import '../../../../core/models/app_config.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/lesson.dart';
import '../../../../core/models/school_stage.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/subject_constraint.dart';
import '../../../../core/models/subject_constraint_key.dart';
import '../../domain/services/primary_stage_constraint_policy.dart';

/// نتيجة مزامنة القيود التلقائية.
class AutoConstraintSyncOutcome {
  const AutoConstraintSyncOutcome({
    required this.createdKeys,
    required this.updatedKeys,
    required this.removedKeys,
    required this.releasedKeys,
    required this.config,
    required this.configChanged,
  });

  /// قيود أُنشئت تلقائيًا.
  final List<String> createdKeys;

  /// قيود أُعيد ضبط حدّها اليومي تبعًا لتغيّر عدد الحصص.
  final List<String> updatedKeys;

  /// قيود أُزيلت لأنها لم تعد مؤهلة (أو لتغيّر المرحلة).
  final List<String> removedKeys;

  /// قيود خرجت من الإدارة التلقائية لأن المستخدم عدّلها بنفسه.
  final List<String> releasedKeys;

  /// الإعدادات بعد تحديث سجلّ القيود المُدارة.
  final AppConfig config;

  /// هل تغيّر ملف الإعدادات نتيجة هذه المزامنة؟
  final bool configChanged;

  bool get hasChanges =>
      createdKeys.isNotEmpty ||
      updatedKeys.isNotEmpty ||
      removedKeys.isNotEmpty ||
      releasedKeys.isNotEmpty;

  /// ملخص عربي مختصر يُعرض للمستخدم بعد المزامنة، أو `null` عند عدم وجود تغيير.
  String? get arabicSummary {
    if (!hasChanges) {
      return null;
    }

    final parts = <String>[];
    if (createdKeys.isNotEmpty) {
      parts.add('أُضيف ${createdKeys.length} قيد تلقائي');
    }
    if (updatedKeys.isNotEmpty) {
      parts.add('حُدّث ${updatedKeys.length} قيد تلقائي');
    }
    if (removedKeys.isNotEmpty) {
      parts.add('أُزيل ${removedKeys.length} قيد تلقائي');
    }
    if (releasedKeys.isNotEmpty) {
      parts.add('${releasedKeys.length} قيد أصبح يدويًا بعد تعديلك');
    }
    return parts.join('، ');
  }
}

/// مزامنة قيود المواد التلقائية للمرحلة الابتدائية مع بيانات المُسنَد.
///
/// المسؤوليات:
/// 1. قراءة الأحمال الأسبوعية الفعلية لكل مادة من قاعدة البيانات.
/// 2. حساب القيود المطلوبة عبر [PrimaryStageConstraintPolicy] (منطق خالص).
/// 3. إنشاء/تحديث/إزالة القيود التي أنشأتها المزامنة فقط، مع احترام تعديلات
///    المستخدم وحذفه.
///
/// لا يكتب هذا الصنف في ملف الإعدادات؛ يعيد الإعدادات المعدَّلة ليحفظها
/// المستدعي، ما يجعل الآثار الجانبية واضحة ومحصورة.
class SubjectConstraintAutoSyncService {
  SubjectConstraintAutoSyncService(this._isar);

  final Isar _isar;

  /// الافتراضي عند غياب إعدادات محفوظة (يطابق القيمة الافتراضية في التطبيق).
  static const int _fallbackDaysPerWeek = 5;

  Future<AutoConstraintSyncOutcome> synchronize(AppConfig config) async {
    final settings = await _isar.appSettings.where().findFirst();
    final daysPerWeek = settings?.daysPerWeek ?? _fallbackDaysPerWeek;

    final classrooms = await _isar.classrooms.where().findAll();
    final grades = classrooms.map((classroom) => classroom.grade).toList();

    final Map<SubjectConstraintKey, int> desired;
    if (config.schoolStage.enablesAutomaticConstraintBypass) {
      final subjects = await _isar.subjects.where().findAll();
      final loads = await _buildSubjectLoads(subjects, classrooms);
      desired = PrimaryStageConstraintPolicy.planFor(
        grades: grades,
        subjects: loads,
        daysPerWeek: daysPerWeek,
      );
    } else {
      desired = const <SubjectConstraintKey, int>{};
    }

    final constraints = await _isar.subjectConstraints.where().findAll();
    final constraintsByKey = <SubjectConstraintKey, SubjectConstraint>{};
    for (final constraint in constraints) {
      constraintsByKey[SubjectConstraintKey.fromConstraint(constraint)] =
          constraint;
    }

    final managed = Map<String, int>.from(config.managedAutoConstraints);
    final dismissed = Set<String>.from(config.dismissedAutoConstraints);
    final desiredKeys = <String>{};

    final created = <String>[];
    final updated = <String>[];
    final removed = <String>[];
    final released = <String>[];

    final pendingUpserts = <SubjectConstraint>[];
    final pendingDeletions = <int>[];

    for (final entry in desired.entries) {
      final key = entry.key;
      final wantedValue = entry.value;
      final storageKey = key.storageKey;
      desiredKeys.add(storageKey);

      final existing = constraintsByKey[key];
      if (existing == null) {
        if (dismissed.contains(storageKey)) {
          // حذفه المستخدم صراحةً، فلا نعيد إنشاءه ما دام مؤهلًا.
          continue;
        }

        pendingUpserts.add(
          SubjectConstraint()
            ..grade = key.grade
            ..subjectName = key.subjectName
            ..maxPeriodsPerDay = wantedValue,
        );
        managed[storageKey] = wantedValue;
        created.add(storageKey);
        continue;
      }

      final managedValue = managed[storageKey];
      if (managedValue == null) {
        // قيد يدوي بالكامل: لا تلمسه المزامنة.
        continue;
      }

      if (managedValue != existing.maxPeriodsPerDay) {
        // المستخدم عدّل القيد بنفسه: يتوقف النظام عن إدارته ويبقى كما هو.
        managed.remove(storageKey);
        released.add(storageKey);
        continue;
      }

      if (managedValue != wantedValue) {
        existing.maxPeriodsPerDay = wantedValue;
        pendingUpserts.add(existing);
        updated.add(storageKey);
      }
      managed[storageKey] = wantedValue;
    }

    // إزالة القيود التي تولّاها النظام ولم تعد مؤهلة (تغيّر النصاب أو المرحلة).
    for (final storageKey in managed.keys.toList()) {
      if (desiredKeys.contains(storageKey)) {
        continue;
      }

      final managedValue = managed.remove(storageKey);
      final key = SubjectConstraintKey.tryParse(storageKey);
      if (key == null) {
        continue;
      }

      final existing = constraintsByKey[key];
      if (existing == null) {
        continue;
      }

      if (managedValue == existing.maxPeriodsPerDay) {
        pendingDeletions.add(existing.id);
        removed.add(storageKey);
      } else {
        released.add(storageKey);
      }
    }

    // سجلّات الحذف تُنسى بمجرد خروج الزوج من نطاق السياسة، حتى يُعاد تطبيقها
    // إن عاد النصاب ليتجاوز الحد لاحقًا.
    for (final storageKey in dismissed.toList()) {
      if (!desiredKeys.contains(storageKey)) {
        dismissed.remove(storageKey);
      }
    }

    if (pendingUpserts.isNotEmpty || pendingDeletions.isNotEmpty) {
      await _isar.writeTxn(() async {
        if (pendingUpserts.isNotEmpty) {
          await _isar.subjectConstraints.putAll(pendingUpserts);
        }
        if (pendingDeletions.isNotEmpty) {
          await _isar.subjectConstraints.deleteAll(pendingDeletions);
        }
      });
    }

    final updatedConfig = config.copyWith(
      managedAutoConstraints: managed,
      dismissedAutoConstraints: dismissed,
    );

    return AutoConstraintSyncOutcome(
      createdKeys: created,
      updatedKeys: updated,
      removedKeys: removed,
      releasedKeys: released,
      config: updatedConfig,
      configChanged: updatedConfig != config,
    );
  }

  /// يجمع الحمل الأسبوعي لكل مادة: النصاب المخطَّط + أعلى إسناد فعلي لكل مرحلة.
  Future<List<SubjectWeeklyLoad>> _buildSubjectLoads(
    List<Subject> subjects,
    List<Classroom> classrooms,
  ) async {
    final gradeByClassroomId = <int, String>{};
    for (final classroom in classrooms) {
      gradeByClassroomId[classroom.id] = classroom.grade;
    }

    final lessons = await _isar.lessons.where().findAll();
    // classroomId → subjectId → عدد الحصص المُسندة.
    final countsByClassroom = <int, Map<int, int>>{};
    for (final lesson in lessons) {
      final classroom = _resolveClassroom(lesson);
      final subject = _resolveSubject(lesson);
      if (classroom == null || subject == null) {
        continue;
      }

      final subjectCounts =
          countsByClassroom.putIfAbsent(classroom.id, () => <int, int>{});
      subjectCounts[subject.id] = (subjectCounts[subject.id] ?? 0) + 1;
    }

    final loads = <SubjectWeeklyLoad>[];
    for (final subject in subjects) {
      final assignedPerGrade = <String, int>{};
      for (final entry in countsByClassroom.entries) {
        final grade = gradeByClassroomId[entry.key];
        if (grade == null) {
          continue;
        }

        final assigned = entry.value[subject.id];
        if (assigned == null) {
          continue;
        }

        final currentMax = assignedPerGrade[grade] ?? 0;
        if (assigned > currentMax) {
          assignedPerGrade[grade] = assigned;
        }
      }

      loads.add(
        SubjectWeeklyLoad(
          subjectName: subject.name,
          plannedLessonsPerWeek: subject.lessonsPerWeek,
          assignedLessonsPerGrade: assignedPerGrade,
        ),
      );
    }

    return loads;
  }

  Classroom? _resolveClassroom(Lesson lesson) {
    if (lesson.classroom.value == null) {
      lesson.classroom.loadSync();
    }
    return lesson.classroom.value;
  }

  Subject? _resolveSubject(Lesson lesson) {
    if (lesson.subject.value == null) {
      lesson.subject.loadSync();
    }
    return lesson.subject.value;
  }
}
