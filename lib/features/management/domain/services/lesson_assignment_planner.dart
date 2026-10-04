import '../../../../core/models/app_config.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/lesson.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/teacher.dart';

/// سلوك التعامل مع زوج مادة×صف سبق إسناده.
enum DuplicateAssignmentBehavior {
  /// يفشل التخطيط برسالة واضحة (صفحة الإسناد الحالية).
  fail,

  /// يتخطّى الزوج المكرر ويكمل البقية (الإسناد الأولي عند إنشاء المعلم).
  skip,
}

/// زوج مادة/صف سيُنشأ له حصص في المسبح.
class AssignmentPair {
  AssignmentPair({required this.subject, required this.classroom});

  final Subject subject;
  final Classroom classroom;
}

/// نتيجة تخطيط الإسناد قبل أي كتابة في Isar.
class AssignmentPlan {
  AssignmentPlan({
    required this.pairsToCreate,
    required this.skippedDuplicates,
    this.errorMessage,
  });

  factory AssignmentPlan.failed(String errorMessage) {
    return AssignmentPlan(
      pairsToCreate: <AssignmentPair>[],
      skippedDuplicates: <AssignmentPair>[],
      errorMessage: errorMessage,
    );
  }

  /// الأزواج التي يجب إنشاء حصصها.
  final List<AssignmentPair> pairsToCreate;

  /// الأزواج التي تُركت لأنها موجودة مسبقًا.
  final List<AssignmentPair> skippedDuplicates;

  /// إن لم تكن `null` يجب إلغاء العملية بالكامل (بما فيها إنشاء المعلم).
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

/// منطق الإسناد المشترك: Teacher ↔ Subject ↔ Classroom عبر حصص [Lesson].
///
/// لا يكتب في قاعدة البيانات؛ يُنتج خطة يطبّقها المستدعي داخل معاملة Isar
/// حتى تبقى عملية إنشاء المعلم مع إسناداته الأولية متسقة.
class LessonAssignmentPlanner {
  /// يخطط إسناد كل تركيبات المواد×الصفوف المحددة إلى المعلم.
  static AssignmentPlan plan({
    required Teacher teacher,
    required Iterable<Subject> subjects,
    required Iterable<Classroom> classrooms,
    required List<Lesson> existingLessons,
    required AppSettings settings,
    AppConfig? appConfig,
    DuplicateAssignmentBehavior duplicateBehavior =
        DuplicateAssignmentBehavior.skip,
  }) {
    final uniqueSubjects = _uniqueSubjects(subjects);
    final uniqueClassrooms = _uniqueClassrooms(classrooms);

    if (uniqueSubjects.isEmpty || uniqueClassrooms.isEmpty) {
      return AssignmentPlan(
        pairsToCreate: <AssignmentPair>[],
        skippedDuplicates: <AssignmentPair>[],
      );
    }

    final assignedPairs = <String>{};
    final classroomCounts = <int, int>{};
    final teacherCounts = <int, int>{};

    for (final lesson in existingLessons) {
      final classroomId = lesson.classroom.value?.id;
      final subjectId = lesson.subject.value?.id;
      final teacherId = lesson.teacher.value?.id;
      if (classroomId != null && subjectId != null) {
        assignedPairs.add(_pairKey(classroomId, subjectId));
      }
      if (classroomId != null) {
        classroomCounts[classroomId] = (classroomCounts[classroomId] ?? 0) + 1;
      }
      if (teacherId != null) {
        teacherCounts[teacherId] = (teacherCounts[teacherId] ?? 0) + 1;
      }
    }

    final periodsPerDay =
        settings.periodsPerDay < 1 ? 1 : settings.periodsPerDay;
    final daysPerWeek = settings.daysPerWeek < 1 ? 5 : settings.daysPerWeek;

    final pairsToCreate = <AssignmentPair>[];
    final skippedDuplicates = <AssignmentPair>[];

    var teacherAssigned = teacherCounts[teacher.id] ?? 0;
    final teacherCapacity = _teacherCapacity(teacher, daysPerWeek);

    for (final subject in uniqueSubjects) {
      final weekly = subject.lessonsPerWeek < 1 ? 1 : subject.lessonsPerWeek;
      for (final classroom in uniqueClassrooms) {
        final pair = AssignmentPair(subject: subject, classroom: classroom);
        final key = _pairKey(classroom.id, subject.id);
        if (assignedPairs.contains(key)) {
          if (duplicateBehavior == DuplicateAssignmentBehavior.fail) {
            return AssignmentPlan.failed('تم إسناد هذه المادة لهذا الصف مسبقاً');
          }
          skippedDuplicates.add(pair);
          continue;
        }

        final maxClassroomCapacity = _classroomCapacity(
          classroom: classroom,
          periodsPerDay: periodsPerDay,
          daysPerWeek: daysPerWeek,
          appConfig: appConfig,
        );

        final classAssigned = classroomCounts[classroom.id] ?? 0;
        final proposedClassTotal = classAssigned + weekly;
        if (proposedClassTotal > maxClassroomCapacity) {
          return AssignmentPlan.failed(
            'تحذير: لا يمكن الإسناد. الصف ${classroom.name} سيصل إلى $proposedClassTotal حصة، مما يتجاوز السعة القصوى للجدول الأسبوعي ($maxClassroomCapacity حصة).',
          );
        }

        final proposedTeacherTotal = teacherAssigned + weekly;
        if (proposedTeacherTotal > teacherCapacity) {
          return AssignmentPlan.failed(
            'تحذير: لا يمكن إسناد هذه المادة. المعلم ${teacher.name} سيصل إلى $proposedTeacherTotal حصة، مما يتجاوز حده المسموح ($teacherCapacity حصة). يرجى اختيار معلم آخر.',
          );
        }

        pairsToCreate.add(pair);
        assignedPairs.add(key);
        classroomCounts[classroom.id] = proposedClassTotal;
        teacherAssigned = proposedTeacherTotal;
      }
    }

    return AssignmentPlan(
      pairsToCreate: pairsToCreate,
      skippedDuplicates: skippedDuplicates,
    );
  }

  static int _classroomCapacity({
    required Classroom classroom,
    required int periodsPerDay,
    required int daysPerWeek,
    required AppConfig? appConfig,
  }) {
    if (classroom.weeklyLessonsOverride != null &&
        classroom.weeklyLessonsOverride! > 0) {
      return classroom.weeklyLessonsOverride!;
    }
    if (appConfig != null) {
      return appConfig
          .resolveWeeklyConfigForClassroom(
            classroom,
            daysPerWeek: daysPerWeek,
          )
          .weeklyTarget;
    }
    return periodsPerDay * daysPerWeek;
  }

  /// يبني حصص المسبح غير المجدولة لكل زوج وفق نصاب المادة.
  static List<Lesson> buildPoolLessons({
    required Teacher teacher,
    required List<AssignmentPair> pairs,
  }) {
    final lessons = <Lesson>[];
    for (final pair in pairs) {
      final weekly =
          pair.subject.lessonsPerWeek < 1 ? 1 : pair.subject.lessonsPerWeek;
      for (var i = 0; i < weekly; i++) {
        final lesson = Lesson()
          ..classroom.value = pair.classroom
          ..subject.value = pair.subject
          ..teacher.value = teacher;
        lessons.add(lesson);
      }
    }
    return lessons;
  }

  static int _teacherCapacity(Teacher teacher, int daysPerWeek) {
    final activeUnavailableDays = teacher.unavailableDays
        .where((day) => day < daysPerWeek)
        .length;
    final availableDays = daysPerWeek - activeUnavailableDays;
    final maxCapacityDays = teacher.maxLessonsPerDay * availableDays;
    return teacher.maxLessonsPerWeek < maxCapacityDays
        ? teacher.maxLessonsPerWeek
        : maxCapacityDays;
  }

  static String _pairKey(int classroomId, int subjectId) {
    return '$classroomId|$subjectId';
  }

  static List<Subject> _uniqueSubjects(Iterable<Subject> items) {
    final seen = <int>{};
    final unique = <Subject>[];
    for (final item in items) {
      if (seen.contains(item.id)) {
        continue;
      }
      seen.add(item.id);
      unique.add(item);
    }
    return unique;
  }

  static List<Classroom> _uniqueClassrooms(Iterable<Classroom> items) {
    final seen = <int>{};
    final unique = <Classroom>[];
    for (final item in items) {
      if (seen.contains(item.id)) {
        continue;
      }
      seen.add(item.id);
      unique.add(item);
    }
    return unique;
  }
}
