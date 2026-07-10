import 'package:isar/isar.dart';

import '../../../../core/models/teacher.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';
import '../../domain/repositories/management_repository.dart';

class ManagementRepositoryImpl implements ManagementRepository {
  final Isar _isar;

  ManagementRepositoryImpl(this._isar);

  @override
  Future<List<Teacher>> getTeachers() async {
    return await _isar.teachers.where().findAll();
  }

  @override
  Future<void> addTeacher(Teacher teacher) async {
    await _isar.writeTxn(() async {
      await _isar.teachers.put(teacher);
    });
  }

  @override
  Future<void> deleteTeacher(int id) async {
    await _isar.writeTxn(() async {
      await _isar.lessons.filter().teacher((q) => q.idEqualTo(id)).deleteAll();
      await _isar.assignments.filter().teacher((q) => q.idEqualTo(id)).deleteAll();
      await _isar.teachers.delete(id);
    });
  }

  @override
  Future<List<Subject>> getSubjects() async {
    return await _isar.subjects.where().findAll();
  }

  @override
  Future<void> addSubject(Subject subject) async {
    await _isar.writeTxn(() async {
      await _isar.subjects.put(subject);
    });
  }

  @override
  Future<void> deleteSubject(int id) async {
    await _isar.writeTxn(() async {
      await _isar.lessons.filter().subject((q) => q.idEqualTo(id)).deleteAll();
      await _isar.assignments.filter().subject((q) => q.idEqualTo(id)).deleteAll();
      await _isar.subjects.delete(id);
    });
  }

  @override
  Future<List<Classroom>> getClassrooms() async {
    return await _isar.classrooms.where().findAll();
  }

  @override
  Future<void> addClassroom(Classroom classroom) async {
    await _isar.writeTxn(() async {
      await _isar.classrooms.put(classroom);
    });
  }

  @override
  Future<void> deleteClassroom(int id) async {
    await _isar.writeTxn(() async {
      await _isar.lessons.filter().classroom((q) => q.idEqualTo(id)).deleteAll();
      await _isar.assignments.filter().classroom((q) => q.idEqualTo(id)).deleteAll();
      await _isar.classrooms.delete(id);
    });
  }

  @override
  Future<AppSettings?> getSettings() async {
    return await _isar.appSettings.where().findFirst();
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });
  }
}
