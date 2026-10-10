import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/subject_consecutiveness.dart';
import 'package:jadwal_v2/core/models/subject_constraint.dart';
import 'package:jadwal_v2/core/models/teacher.dart';
import 'package:jadwal_v2/core/providers/app_config_provider.dart';
import 'package:jadwal_v2/core/providers/database_provider.dart';
import 'package:jadwal_v2/core/services/app_config_service.dart';
import 'package:jadwal_v2/features/timetable/presentation/providers/timetable_provider.dart';

/// السحب والتبديل عبر [TimetableNotifier] الحقيقي على قاعدة Isar حقيقية:
/// الحركة المرفوضة لا تترك أي تعديل جزئي، لا في القاعدة ولا في الحالة المعروضة.
void main() {
  late Isar isar;
  late Directory configDirectory;
  late ProviderContainer container;
  late ProviderSubscription<AsyncValue<List<Lesson>>> subscription;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    isar = await Isar.open(
      [
        TeacherSchema,
        SubjectSchema,
        ClassroomSchema,
        LessonSchema,
        AppSettingsSchema,
        SubjectConstraintSchema,
      ],
      directory: Directory.systemTemp.path,
      name: 'timetable_drag_rejection_persistence_test',
    );
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
  });

  setUp(() async {
    await _seed(isar);
    configDirectory = await Directory.systemTemp.createTemp(
      'jadwal_drag_config_',
    );
    container = ProviderContainer(
      overrides: [
        isarDatabaseProvider.overrideWith((ref) async => isar),
        appConfigServiceProvider.overrideWith(
          (ref) async => AppConfigService(
            file: File(
              '${configDirectory.path}${Platform.pathSeparator}'
              '${AppConfigService.fileName}',
            ),
          ),
        ),
      ],
    );
    subscription = container.listen(timetableNotifierProvider, (_, __) {});
    await container.read(timetableNotifierProvider.future);
  });

  tearDown(() async {
    subscription.close();
    container.dispose();
    await configDirectory.delete(recursive: true);
  });

  Future<List<String>> persistedPositions() async {
    final lessons = await isar.lessons.where().findAll();
    lessons.sort((a, b) => a.id.compareTo(b.id));
    return [
      for (final lesson in lessons)
        '${lesson.id}@${lesson.dayIndex}:${lesson.periodIndex}',
    ];
  }

  List<String> visiblePositions() {
    final lessons = List<Lesson>.of(
      container.read(timetableNotifierProvider).requireValue,
    )..sort((a, b) => a.id.compareTo(b.id));
    return [
      for (final lesson in lessons)
        '${lesson.id}@${lesson.dayIndex}:${lesson.periodIndex}',
    ];
  }

  Lesson visibleLesson(int id) {
    return container
        .read(timetableNotifierProvider)
        .requireValue
        .firstWhere((lesson) => lesson.id == id);
  }

  const initialPositions = ['1@0:0', '2@0:2', '3@1:0', '4@1:3'];

  test(
    'a move that carries a legacy gap to another day changes nothing',
    () async {
      expect(await persistedPositions(), initialPositions);
      expect(visiblePositions(), initialPositions);

      final notifier = container.read(timetableNotifierProvider.notifier);
      final (moved, error) = await notifier.moveLessonToEmpty(
        visibleLesson(2),
        1,
        2,
      );

      expect(moved, isFalse);
      expect(error, contains('«متتالي»'));
      expect(await persistedPositions(), initialPositions);
      expect(visiblePositions(), initialPositions);
      expect(notifier.isDragDropOperationInProgress, isFalse);
    },
  );

  test('a swap rejected by the group rules changes neither lesson', () async {
    final notifier = container.read(timetableNotifierProvider.notifier);
    final (swapped, error) = await notifier.swapLessons(
      visibleLesson(2),
      visibleLesson(4),
    );

    expect(swapped, isFalse);
    expect(error, contains('«متتالي»'));
    expect(await persistedPositions(), initialPositions);
    expect(visiblePositions(), initialPositions);
  });

  test('a move rejected by a placement check changes nothing', () async {
    final notifier = container.read(timetableNotifierProvider.notifier);
    // الحصة الرابعة في اليوم الثاني يشغلها درس الرياضيات.
    final (moved, error) = await notifier.moveLessonToEmpty(
      visibleLesson(1),
      1,
      3,
    );

    expect(moved, isFalse);
    expect(error, isNotNull);
    expect(await persistedPositions(), initialPositions);
    expect(visiblePositions(), initialPositions);
  });

  test(
    'after a rejection, a repairing move is applied and persisted',
    () async {
      final notifier = container.read(timetableNotifierProvider.notifier);
      final (rejected, _) = await notifier.moveLessonToEmpty(
        visibleLesson(2),
        1,
        2,
      );
      expect(rejected, isFalse);

      // الحصة تلتصق بحصة العربي في اليوم الثاني فيزول الفراغ القديم.
      final (moved, error) = await notifier.moveLessonToEmpty(
        visibleLesson(2),
        1,
        1,
      );

      expect(error, isNull);
      expect(moved, isTrue);
      const expected = ['1@0:0', '2@1:1', '3@1:0', '4@1:3'];
      expect(await persistedPositions(), expected);
      expect(visiblePositions(), expected);
    },
  );
}

/// العربي «متتالي» بحد يومي 2: اليوم 0 [1، 3] (فراغ قديم)، اليوم 1 [1].
/// الرياضيات حصة واحدة في اليوم 1، الحصة 4.
Future<void> _seed(Isar isar) async {
  await isar.writeTxn(() async {
    await isar.clear();

    final arabicTeacher = _teacher(1, 'Arabic teacher');
    final mathTeacher = _teacher(2, 'Math teacher');
    final arabic = Subject()
      ..id = 1
      ..name = 'Arabic'
      ..lessonsPerWeek = 3
      ..preferEarlyPeriods = false
      ..allowedPeriods = <int>[]
      ..consecutiveness = SubjectConsecutiveness.consecutive;
    final math = Subject()
      ..id = 2
      ..name = 'Math'
      ..lessonsPerWeek = 1
      ..preferEarlyPeriods = false
      ..allowedPeriods = <int>[]
      ..consecutiveness = SubjectConsecutiveness.any;
    final classroom = Classroom()
      ..id = 1
      ..name = 'Class 1'
      ..grade = 'Grade 1';

    await isar.teachers.putAll([arabicTeacher, mathTeacher]);
    await isar.subjects.putAll([arabic, math]);
    await isar.classrooms.put(classroom);
    await isar.appSettings.put(
      AppSettings()
        ..periodsPerDay = 6
        ..daysPerWeek = 5,
    );
    await isar.subjectConstraints.putAll([
      SubjectConstraint()
        ..grade = 'Grade 1'
        ..subjectName = 'Arabic'
        ..maxPeriodsPerDay = 2,
      SubjectConstraint()
        ..grade = 'Grade 1'
        ..subjectName = 'Math'
        ..maxPeriodsPerDay = 1,
    ]);

    final placements = [
      (id: 1, teacher: arabicTeacher, subject: arabic, day: 0, period: 0),
      (id: 2, teacher: arabicTeacher, subject: arabic, day: 0, period: 2),
      (id: 3, teacher: arabicTeacher, subject: arabic, day: 1, period: 0),
      (id: 4, teacher: mathTeacher, subject: math, day: 1, period: 3),
    ];
    for (final placement in placements) {
      final lesson = Lesson()
        ..id = placement.id
        ..dayIndex = placement.day
        ..periodIndex = placement.period
        ..teacher.value = placement.teacher
        ..subject.value = placement.subject
        ..classroom.value = classroom;
      await isar.lessons.put(lesson);
      await lesson.teacher.save();
      await lesson.subject.save();
      await lesson.classroom.save();
    }
  });
}

Teacher _teacher(int id, String name) {
  return Teacher()
    ..id = id
    ..name = name
    ..specialization = ''
    ..maxLessonsPerWeek = 30
    ..maxLessonsPerDay = 5
    ..unavailableDays = <int>[]
    ..allowedPeriods = <int>[];
}
