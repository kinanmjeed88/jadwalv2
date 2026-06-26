import '../../../../core/models/teacher.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';

abstract class ManagementRepository {
  Future<List<Teacher>> getTeachers();
  Future<void> addTeacher(Teacher teacher);
  Future<void> deleteTeacher(int id);

  Future<List<Subject>> getSubjects();
  Future<void> addSubject(Subject subject);
  Future<void> deleteSubject(int id);

  Future<List<Classroom>> getClassrooms();
  Future<void> addClassroom(Classroom classroom);
  Future<void> deleteClassroom(int id);

  Future<AppSettings?> getSettings();
  Future<void> saveSettings(AppSettings settings);
}
