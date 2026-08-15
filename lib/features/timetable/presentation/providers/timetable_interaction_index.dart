import '../../../../core/models/lesson.dart';
import '../../../../core/models/subject_constraint.dart';

typedef TimetableTeacherSlotKey = ({
  int teacherId,
  int dayIndex,
  int periodIndex,
});

typedef TimetableClassroomSlotKey = ({
  int classroomId,
  int dayIndex,
  int periodIndex,
});

typedef TimetableSubjectDayKey = ({
  int classroomId,
  int subjectId,
  int dayIndex,
});

typedef TimetableTeacherDayKey = ({
  int teacherId,
  int dayIndex,
});

typedef TimetableConstraintKey = ({
  String grade,
  String subjectName,
});

/// Indexed view of the lessons currently visible to the user.
///
/// The index is intentionally independent from Isar. It can therefore be used
/// for both the persisted schedule and the failed-generation preview without
/// changing the source of truth for either one.
class TimetableInteractionIndex {
  TimetableInteractionIndex._({
    required this.lessons,
    required this.lessonsById,
    required this.teacherLessonsBySlot,
    required this.classroomLessonsBySlot,
    required this.subjectLessonsByDay,
    required this.teacherLessonsByDay,
    required this.maxPeriodsBySubject,
  });

  factory TimetableInteractionIndex.build({
    required List<Lesson> lessons,
    required List<SubjectConstraint> subjectConstraints,
  }) {
    final lessonsById = <int, Lesson>{};
    final teacherLessonsBySlot = <TimetableTeacherSlotKey, Set<int>>{};
    final classroomLessonsBySlot = <TimetableClassroomSlotKey, Set<int>>{};
    final subjectLessonsByDay = <TimetableSubjectDayKey, Set<int>>{};
    final teacherLessonsByDay = <TimetableTeacherDayKey, Set<int>>{};
    final maxPeriodsBySubject = <TimetableConstraintKey, int>{
      for (final constraint in subjectConstraints)
        (
          grade: constraint.grade,
          subjectName: constraint.subjectName,
        ): constraint.maxPeriodsPerDay,
    };

    final index = TimetableInteractionIndex._(
      lessons: lessons,
      lessonsById: lessonsById,
      teacherLessonsBySlot: teacherLessonsBySlot,
      classroomLessonsBySlot: classroomLessonsBySlot,
      subjectLessonsByDay: subjectLessonsByDay,
      teacherLessonsByDay: teacherLessonsByDay,
      maxPeriodsBySubject: maxPeriodsBySubject,
    );

    for (final lesson in lessons) {
      index._addLesson(lesson);
    }

    return index;
  }

  final List<Lesson> lessons;
  final Map<int, Lesson> lessonsById;
  final Map<TimetableTeacherSlotKey, Set<int>> teacherLessonsBySlot;
  final Map<TimetableClassroomSlotKey, Set<int>> classroomLessonsBySlot;
  final Map<TimetableSubjectDayKey, Set<int>> subjectLessonsByDay;
  final Map<TimetableTeacherDayKey, Set<int>> teacherLessonsByDay;
  final Map<TimetableConstraintKey, int> maxPeriodsBySubject;

  Lesson? lessonById(int id) => lessonsById[id];

  bool hasTeacherConflict({
    required int? teacherId,
    required int? dayIndex,
    required int? periodIndex,
    Set<int> excludedLessonIds = const <int>{},
  }) {
    if (teacherId == null || dayIndex == null || periodIndex == null) {
      return false;
    }

    return _hasOtherLesson(
      teacherLessonsBySlot[(
        teacherId: teacherId,
        dayIndex: dayIndex,
        periodIndex: periodIndex,
      )],
      excludedLessonIds,
    );
  }

  bool hasClassroomConflict({
    required int? classroomId,
    required int? dayIndex,
    required int? periodIndex,
    Set<int> excludedLessonIds = const <int>{},
  }) {
    if (classroomId == null || dayIndex == null || periodIndex == null) {
      return false;
    }

    return _hasOtherLesson(
      classroomLessonsBySlot[(
        classroomId: classroomId,
        dayIndex: dayIndex,
        periodIndex: periodIndex,
      )],
      excludedLessonIds,
    );
  }

  int subjectCountOnDay({
    required int? classroomId,
    required int? subjectId,
    required int? dayIndex,
    Set<int> excludedLessonIds = const <int>{},
  }) {
    if (classroomId == null || subjectId == null || dayIndex == null) {
      return 0;
    }

    return _countOtherLessons(
      subjectLessonsByDay[(
        classroomId: classroomId,
        subjectId: subjectId,
        dayIndex: dayIndex,
      )],
      excludedLessonIds,
    );
  }

  int teacherCountOnDay({
    required int? teacherId,
    required int? dayIndex,
    Set<int> excludedLessonIds = const <int>{},
  }) {
    if (teacherId == null || dayIndex == null) {
      return 0;
    }

    return _countOtherLessons(
      teacherLessonsByDay[(teacherId: teacherId, dayIndex: dayIndex)],
      excludedLessonIds,
    );
  }

  int maxPeriodsPerDay({
    required String? grade,
    required String? subjectName,
  }) {
    if (grade == null || subjectName == null) {
      return 1;
    }

    return maxPeriodsBySubject[(grade: grade, subjectName: subjectName)] ?? 1;
  }

  /// Moves one lesson and updates only the affected index buckets.
  Lesson? moveLesson({
    required int lessonId,
    required int newDay,
    required int newPeriod,
  }) {
    final lesson = lessonsById[lessonId];
    if (lesson == null) {
      return null;
    }

    _removeLesson(lesson);
    lesson.dayIndex = newDay;
    lesson.periodIndex = newPeriod;
    _addLesson(lesson);
    return lesson;
  }

  /// Swaps two lessons and updates only the buckets affected by their old and
  /// new placements.
  bool swapLessons({required int firstId, required int secondId}) {
    if (firstId == secondId) {
      return false;
    }

    final first = lessonsById[firstId];
    final second = lessonsById[secondId];
    if (first == null || second == null) {
      return false;
    }

    final firstDay = first.dayIndex;
    final firstPeriod = first.periodIndex;
    final secondDay = second.dayIndex;
    final secondPeriod = second.periodIndex;

    _removeLesson(first);
    _removeLesson(second);

    first.dayIndex = secondDay;
    first.periodIndex = secondPeriod;
    second.dayIndex = firstDay;
    second.periodIndex = firstPeriod;

    _addLesson(first);
    _addLesson(second);
    return true;
  }

  void _addLesson(Lesson lesson) {
    lessonsById[lesson.id] = lesson;

    final dayIndex = lesson.dayIndex;
    final periodIndex = lesson.periodIndex;
    if (dayIndex == null || periodIndex == null) {
      return;
    }

    final teacherId = lesson.teacher.value?.id;
    if (teacherId != null) {
      _addToIndex(
        teacherLessonsBySlot,
        (
          teacherId: teacherId,
          dayIndex: dayIndex,
          periodIndex: periodIndex,
        ),
        lesson.id,
      );
      _addToIndex(
        teacherLessonsByDay,
        (teacherId: teacherId, dayIndex: dayIndex),
        lesson.id,
      );
    }

    final classroomId = lesson.classroom.value?.id;
    if (classroomId != null) {
      _addToIndex(
        classroomLessonsBySlot,
        (
          classroomId: classroomId,
          dayIndex: dayIndex,
          periodIndex: periodIndex,
        ),
        lesson.id,
      );
    }

    final subjectId = lesson.subject.value?.id;
    if (classroomId != null && subjectId != null) {
      _addToIndex(
        subjectLessonsByDay,
        (
          classroomId: classroomId,
          subjectId: subjectId,
          dayIndex: dayIndex,
        ),
        lesson.id,
      );
    }
  }

  void _removeLesson(Lesson lesson) {
    lessonsById.remove(lesson.id);

    final dayIndex = lesson.dayIndex;
    final periodIndex = lesson.periodIndex;
    if (dayIndex == null || periodIndex == null) {
      return;
    }

    final teacherId = lesson.teacher.value?.id;
    if (teacherId != null) {
      _removeFromIndex(
        teacherLessonsBySlot,
        (
          teacherId: teacherId,
          dayIndex: dayIndex,
          periodIndex: periodIndex,
        ),
        lesson.id,
      );
      _removeFromIndex(
        teacherLessonsByDay,
        (teacherId: teacherId, dayIndex: dayIndex),
        lesson.id,
      );
    }

    final classroomId = lesson.classroom.value?.id;
    if (classroomId != null) {
      _removeFromIndex(
        classroomLessonsBySlot,
        (
          classroomId: classroomId,
          dayIndex: dayIndex,
          periodIndex: periodIndex,
        ),
        lesson.id,
      );
    }

    final subjectId = lesson.subject.value?.id;
    if (classroomId != null && subjectId != null) {
      _removeFromIndex(
        subjectLessonsByDay,
        (
          classroomId: classroomId,
          subjectId: subjectId,
          dayIndex: dayIndex,
        ),
        lesson.id,
      );
    }
  }

  static bool _hasOtherLesson(Set<int>? ids, Set<int> excludedLessonIds) {
    if (ids == null || ids.isEmpty) {
      return false;
    }
    if (excludedLessonIds.isEmpty) {
      return true;
    }
    return ids.any((id) => !excludedLessonIds.contains(id));
  }

  static int _countOtherLessons(
    Set<int>? ids,
    Set<int> excludedLessonIds,
  ) {
    if (ids == null || ids.isEmpty) {
      return 0;
    }
    if (excludedLessonIds.isEmpty) {
      return ids.length;
    }
    return ids.where((id) => !excludedLessonIds.contains(id)).length;
  }

  static void _addToIndex<K>(Map<K, Set<int>> index, K key, int lessonId) {
    (index[key] ??= <int>{}).add(lessonId);
  }

  static void _removeFromIndex<K>(Map<K, Set<int>> index, K key, int lessonId) {
    final ids = index[key];
    if (ids == null) {
      return;
    }
    ids.remove(lessonId);
    if (ids.isEmpty) {
      index.remove(key);
    }
  }
}
