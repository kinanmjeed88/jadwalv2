import '../../../../core/models/teacher.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/lesson.dart';
import '../../../../core/models/settings.dart';

class TeacherDto {
  final int id;
  final String name;
  final int maxLessonsPerDay;
  final int maxLessonsPerWeek;
  final List<int> unavailableDays;
  final List<int> allowedPeriods;

  TeacherDto({
    required this.id,
    required this.name,
    required this.maxLessonsPerDay,
    required this.maxLessonsPerWeek,
    required this.unavailableDays,
    required this.allowedPeriods,
  });

  factory TeacherDto.fromIsar(Teacher teacher) {
    return TeacherDto(
      id: teacher.id,
      name: teacher.name,
      maxLessonsPerDay: teacher.maxLessonsPerDay,
      maxLessonsPerWeek: teacher.maxLessonsPerWeek,
      unavailableDays: List.from(teacher.unavailableDays),
      allowedPeriods: List.from(teacher.allowedPeriods),
    );
  }
}

class SubjectDto {
  final int id;
  final String name;
  final int lessonsPerWeek;
  final bool preferEarlyPeriods;
  final List<int> allowedPeriods;

  SubjectDto({
    required this.id,
    required this.name,
    required this.lessonsPerWeek,
    required this.preferEarlyPeriods,
    required this.allowedPeriods,
  });

  factory SubjectDto.fromIsar(Subject subject) {
    return SubjectDto(
      id: subject.id,
      name: subject.name,
      lessonsPerWeek: subject.lessonsPerWeek,
      preferEarlyPeriods: subject.preferEarlyPeriods,
      allowedPeriods: List.from(subject.allowedPeriods),
    );
  }
}

class ClassroomDto {
  final int id;
  final String name;

  ClassroomDto({
    required this.id,
    required this.name,
  });

  factory ClassroomDto.fromIsar(Classroom classroom) {
    return ClassroomDto(
      id: classroom.id,
      name: classroom.name,
    );
  }
}

class AppSettingsDto {
  final int periodsPerDay;
  final int daysPerWeek;

  AppSettingsDto({
    required this.periodsPerDay,
    required this.daysPerWeek,
  });

  factory AppSettingsDto.fromIsar(AppSettings settings) {
    return AppSettingsDto(
      periodsPerDay: settings.periodsPerDay,
      daysPerWeek: settings.daysPerWeek,
    );
  }
}

class LessonDto {
  final int id;
  final TeacherDto? teacher;
  final SubjectDto? subject;
  final ClassroomDto? classroom;
  int? dayIndex;
  int? periodIndex;
  bool isPinned;

  LessonDto({
    required this.id,
    this.teacher,
    this.subject,
    this.classroom,
    this.dayIndex,
    this.periodIndex,
    required this.isPinned,
  });

  factory LessonDto.fromIsar(
    Lesson lesson,
    Map<int, TeacherDto> teachersMap,
    Map<int, SubjectDto> subjectsMap,
    Map<int, ClassroomDto> classroomsMap,
  ) {
    return LessonDto(
      id: lesson.id,
      teacher: lesson.teacher.value != null ? teachersMap[lesson.teacher.value!.id] : null,
      subject: lesson.subject.value != null ? subjectsMap[lesson.subject.value!.id] : null,
      classroom: lesson.classroom.value != null ? classroomsMap[lesson.classroom.value!.id] : null,
      dayIndex: lesson.dayIndex,
      periodIndex: lesson.periodIndex,
      isPinned: lesson.isPinned,
    );
  }
}
