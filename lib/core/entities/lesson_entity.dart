import '../models/lesson.dart';
import 'teacher_entity.dart';
import 'subject_entity.dart';
import 'classroom_entity.dart';

class LessonEntity {
  final int id;
  TeacherEntity? teacher;
  final SubjectEntity? subject;
  final ClassroomEntity? classroom;
  int? dayIndex;
  int? periodIndex;
  bool isPinned;

  LessonEntity({
    required this.id,
    this.teacher,
    this.subject,
    this.classroom,
    this.dayIndex,
    this.periodIndex,
    required this.isPinned,
  });

  factory LessonEntity.fromIsar(
    Lesson lesson,
    Map<int, TeacherEntity> teachersMap,
    Map<int, SubjectEntity> subjectsMap,
    Map<int, ClassroomEntity> classroomsMap,
  ) {
    return LessonEntity(
      id: lesson.id,
      teacher: lesson.teacher.value != null ? teachersMap[lesson.teacher.value!.id] : null,
      subject: lesson.subject.value != null ? subjectsMap[lesson.subject.value!.id] : null,
      classroom: lesson.classroom.value != null ? classroomsMap[lesson.classroom.value!.id] : null,
      dayIndex: lesson.dayIndex,
      periodIndex: lesson.periodIndex,
      isPinned: lesson.isPinned,
    );
  }

  bool get isUnassigned => dayIndex == null || periodIndex == null;
}
