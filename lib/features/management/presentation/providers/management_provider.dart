import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/providers/repository_provider.dart';
import '../../../../core/models/teacher.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/subject_consecutiveness.dart';
import '../../../../core/models/subject_constraint.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';

part 'management_provider.g.dart';

@riverpod
class TeachersNotifier extends _$TeachersNotifier {
  @override
  Future<List<Teacher>> build() async {
    final repo = await ref.watch(managementRepositoryProvider.future);
    return repo.getTeachers();
  }

  Future<void> addTeacher(Teacher teacher) async {
    final repo = await ref.read(managementRepositoryProvider.future);
    await repo.addTeacher(teacher);
    state = AsyncValue.data(await repo.getTeachers());
  }

  Future<void> deleteTeacher(int id) async {
    final repo = await ref.read(managementRepositoryProvider.future);
    await repo.deleteTeacher(id);
    state = AsyncValue.data(await repo.getTeachers());
  }
}

@riverpod
class SubjectsNotifier extends _$SubjectsNotifier {
  @override
  Future<List<Subject>> build() async {
    final repo = await ref.watch(managementRepositoryProvider.future);
    return repo.getSubjects();
  }

  Future<void> addSubject(Subject subject) async {
    final repo = await ref.read(managementRepositoryProvider.future);
    await repo.addSubject(subject);
    state = AsyncValue.data(await repo.getSubjects());
  }

  Future<void> saveSubjectConstraint({
    int? constraintId,
    required String grade,
    required String subjectName,
    required int maxPeriodsPerDay,
    required SubjectConsecutiveness consecutiveness,
  }) async {
    final isar = await ref.read(isarDatabaseProvider.future);

    await isar.writeTxn(() async {
      SubjectConstraint? constraint;
      if (constraintId != null) {
        constraint = await isar.subjectConstraints.get(constraintId);
      }
      constraint ??= await isar.subjectConstraints
          .filter()
          .gradeEqualTo(grade)
          .and()
          .subjectNameEqualTo(subjectName)
          .findFirst();

      constraint ??= SubjectConstraint();
      constraint
        ..grade = grade
        ..subjectName = subjectName
        ..maxPeriodsPerDay = maxPeriodsPerDay;
      await isar.subjectConstraints.put(constraint);

      final subject =
          await isar.subjects.filter().nameEqualTo(subjectName).findFirst();
      if (subject != null) {
        subject.consecutiveness = consecutiveness;
        await isar.subjects.put(subject);
      }
    });

    final repo = await ref.read(managementRepositoryProvider.future);
    state = AsyncValue.data(await repo.getSubjects());
  }

  Future<void> deleteSubject(int id) async {
    final repo = await ref.read(managementRepositoryProvider.future);
    await repo.deleteSubject(id);
    state = AsyncValue.data(await repo.getSubjects());
  }
}

@riverpod
class ClassroomsNotifier extends _$ClassroomsNotifier {
  @override
  Future<List<Classroom>> build() async {
    final repo = await ref.watch(managementRepositoryProvider.future);
    return repo.getClassrooms();
  }

  Future<void> addClassroom(Classroom classroom) async {
    final repo = await ref.read(managementRepositoryProvider.future);
    await repo.addClassroom(classroom);
    state = AsyncValue.data(await repo.getClassrooms());
  }

  Future<void> deleteClassroom(int id) async {
    final repo = await ref.read(managementRepositoryProvider.future);
    await repo.deleteClassroom(id);
    state = AsyncValue.data(await repo.getClassrooms());
  }
}

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    final repo = await ref.watch(managementRepositoryProvider.future);
    final settings = await repo.getSettings();
    return settings ?? AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    final repo = await ref.read(managementRepositoryProvider.future);
    await repo.saveSettings(settings);
    state = AsyncValue.data(await repo.getSettings() ?? AppSettings());
  }
}
