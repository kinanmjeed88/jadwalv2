import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:isar/isar.dart';
import 'dart:async';
import 'dart:isolate';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/models/teacher.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/lesson.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/entities/lesson_entity.dart';
import '../../../../core/entities/teacher_entity.dart';
import '../../../../core/entities/subject_entity.dart';
import '../../../../core/entities/classroom_entity.dart';
import '../../../../core/entities/app_settings_entity.dart';
import '../../../../core/models/subject_constraint.dart';
import '../../../../core/entities/subject_constraint_entity.dart';

import '../../domain/usecases/timetable_generator.dart';
import '../../domain/usecases/smart_auto_fix_usecase.dart';
import '../providers/timetable_interaction_index.dart';
import '../../../../core/exceptions/timetable_generation_exception.dart';

part 'timetable_provider.g.dart';

const _smartAutoFixTimeout = Duration(seconds: 30);

enum TimetableAutoFixStatus { idle, ready, fixing, failed }

class TimetableAutoFixState {
  final TimetableAutoFixStatus status;
  final int bestCost;
  final List<ConflictDiagnostic> diagnostics;
  final int currentAttempt;
  final int totalAttempts;

  const TimetableAutoFixState({
    this.status = TimetableAutoFixStatus.idle,
    this.bestCost = 0,
    this.diagnostics = const [],
    this.currentAttempt = 0,
    this.totalAttempts = SmartAutoFixUseCase.maxAttempts,
  });

  bool get isPreview =>
      status == TimetableAutoFixStatus.ready ||
      status == TimetableAutoFixStatus.fixing ||
      status == TimetableAutoFixStatus.failed;

  bool get canFix => isPreview && status != TimetableAutoFixStatus.fixing;

  bool get isFixing => status == TimetableAutoFixStatus.fixing;

  TimetableAutoFixState copyWith({
    TimetableAutoFixStatus? status,
    int? bestCost,
    List<ConflictDiagnostic>? diagnostics,
    int? currentAttempt,
    int? totalAttempts,
  }) {
    return TimetableAutoFixState(
      status: status ?? this.status,
      bestCost: bestCost ?? this.bestCost,
      diagnostics: diagnostics ?? this.diagnostics,
      currentAttempt: currentAttempt ?? this.currentAttempt,
      totalAttempts: totalAttempts ?? this.totalAttempts,
    );
  }
}

final timetableAutoFixStateProvider = StateProvider<TimetableAutoFixState>(
    (ref) => const TimetableAutoFixState());

@riverpod
class TimetableNotifier extends _$TimetableNotifier {
  GenerationPayload? _lastPayload;
  List<LessonEntity>? _previewEntities;
  List<Lesson>? _persistedLessonsCache;
  Map<int, Lesson>? _persistedLessonsById;
  List<Lesson>? _visibleLessonsCache;
  List<SubjectConstraint>? _subjectConstraintsCache;
  TimetableInteractionIndex? _interactionIndex;
  bool _dragDropOperationInProgress = false;
  bool _referenceDataDirty = false;
  bool _referenceWatchersInitialized = false;

  @override
  Future<List<Lesson>> build() async {
    final isar = await ref.watch(isarDatabaseProvider.future);
    _startReferenceWatchers(isar);
    return _loadPersistedLessons(isar, force: true);
  }

  void _startReferenceWatchers(Isar isar) {
    if (_referenceWatchersInitialized) {
      return;
    }
    _referenceWatchersInitialized = true;

    final subscriptions = <StreamSubscription<void>>[
      isar.teachers.watchLazy().listen((_) => _markReferenceDataDirty()),
      isar.subjects.watchLazy().listen((_) => _markReferenceDataDirty()),
      isar.classrooms.watchLazy().listen((_) => _markReferenceDataDirty()),
      isar.subjectConstraints
          .watchLazy()
          .listen((_) => _markReferenceDataDirty()),
    ];
    ref.onDispose(() {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    });
  }

  void _markReferenceDataDirty() {
    _referenceDataDirty = true;
    _persistedLessonsCache = null;
    _persistedLessonsById = null;
    _subjectConstraintsCache = null;
    _interactionIndex = null;
  }

  Future<void> _refreshReferenceDataIfNeeded(Isar isar) async {
    if (!_referenceDataDirty) {
      return;
    }

    final lessons = await _loadPersistedLessons(isar, force: true);
    final previewEntities = _previewEntities;
    if (previewEntities != null) {
      final previewLessons = previewEntities
          .map((entity) => _toPreviewLesson(entity, lessons))
          .toList();
      _setVisibleLessons(previewLessons);
    } else {
      _setVisibleLessons(lessons);
    }
    _referenceDataDirty = false;
  }

  Future<List<Lesson>> _loadPersistedLessons(
    Isar isar, {
    bool force = false,
  }) async {
    if (!force && _persistedLessonsCache != null) {
      return _persistedLessonsCache!;
    }

    final lessons = await isar.lessons.where().findAll();
    for (final lesson in lessons) {
      lesson.classroom.loadSync();
      lesson.subject.loadSync();
      lesson.teacher.loadSync();
    }

    _persistedLessonsCache = lessons;
    _persistedLessonsById = {for (final lesson in lessons) lesson.id: lesson};
    if (_previewEntities == null) {
      _setVisibleLessons(lessons);
    }
    return lessons;
  }

  Future<List<SubjectConstraint>> _loadSubjectConstraints(
    Isar isar, {
    bool force = false,
  }) async {
    if (!force && _subjectConstraintsCache != null) {
      return _subjectConstraintsCache!;
    }

    final constraints = await isar.subjectConstraints.where().findAll();
    _subjectConstraintsCache = constraints;
    _interactionIndex = null;
    return constraints;
  }

  void _setPersistedLessons(List<Lesson> lessons) {
    _persistedLessonsCache = lessons;
    _persistedLessonsById = {for (final lesson in lessons) lesson.id: lesson};
    if (_previewEntities == null) {
      _setVisibleLessons(lessons);
    }
  }

  void _setVisibleLessons(List<Lesson> lessons) {
    _visibleLessonsCache = lessons;
    _interactionIndex = null;
  }

  Future<TimetableInteractionIndex> _ensureInteractionIndex(Isar isar) async {
    _startReferenceWatchers(isar);
    await _refreshReferenceDataIfNeeded(isar);
    final visibleLessons =
        _visibleLessonsCache ?? await _loadPersistedLessons(isar, force: false);
    final existingIndex = _interactionIndex;
    if (existingIndex != null &&
        identical(existingIndex.lessons, visibleLessons)) {
      return existingIndex;
    }

    final constraints = await _loadSubjectConstraints(isar);
    final index = TimetableInteractionIndex.build(
      lessons: visibleLessons,
      subjectConstraints: constraints,
    );
    _interactionIndex = index;
    return index;
  }

  List<Lesson> _visibleLessons() => _visibleLessonsCache ?? const <Lesson>[];

  void _publishVisibleLessons() {
    state = AsyncValue.data(_visibleLessons());
  }

  void _updatePreviewEntityPosition(
    int lessonId,
    int? dayIndex,
    int? periodIndex,
  ) {
    final previewEntities = _previewEntities;
    if (previewEntities == null) {
      return;
    }

    final entityIndex =
        previewEntities.indexWhere((entity) => entity.id == lessonId);
    if (entityIndex == -1) {
      return;
    }

    final entity = previewEntities[entityIndex];
    previewEntities[entityIndex] = LessonEntity(
      id: entity.id,
      teacher: entity.teacher,
      subject: entity.subject,
      classroom: entity.classroom,
      dayIndex: dayIndex,
      periodIndex: periodIndex,
      isPinned: entity.isPinned,
    );
  }

  void _invalidateInteractionCache() {
    _interactionIndex = null;
    _subjectConstraintsCache = null;
  }

  String? _validatePlacement({
    required TimetableInteractionIndex index,
    required Lesson lesson,
    required int newDay,
    required int newPeriod,
    required Set<int> excludedLessonIds,
    required String operationLabel,
  }) {
    final teacher = lesson.teacher.value;
    final subject = lesson.subject.value;
    final classroom = lesson.classroom.value;

    if (index.hasTeacherConflict(
      teacherId: teacher?.id,
      dayIndex: newDay,
      periodIndex: newPeriod,
      excludedLessonIds: excludedLessonIds,
    )) {
      return 'لا يمكن $operationLabel: الأستاذ (${teacher?.name ?? ''}) لديه حصة أخرى في نفس الوقت';
    }

    if (index.hasClassroomConflict(
      classroomId: classroom?.id,
      dayIndex: newDay,
      periodIndex: newPeriod,
      excludedLessonIds: excludedLessonIds,
    )) {
      return 'لا يمكن $operationLabel: الصف مشغول بالفعل في الحصة المقترحة';
    }

    if (subject != null && classroom != null) {
      final maxAllowed = index.maxPeriodsPerDay(
        grade: classroom.grade,
        subjectName: subject.name,
      );
      final subjectCountOnNewDay = index.subjectCountOnDay(
        classroomId: classroom.id,
        subjectId: subject.id,
        dayIndex: newDay,
        excludedLessonIds: excludedLessonIds,
      );
      if (subjectCountOnNewDay >= maxAllowed) {
        return 'لا يمكن $operationLabel: تجاوز الحد الأقصى ($maxAllowed حصص) لمادة (${subject.name}) في اليوم المقترح';
      }
    }

    if (lesson.dayIndex != newDay && teacher != null) {
      final teacherLessonsNewDay = index.teacherCountOnDay(
        teacherId: teacher.id,
        dayIndex: newDay,
        excludedLessonIds: excludedLessonIds,
      );
      if (teacherLessonsNewDay >= teacher.maxLessonsPerDay) {
        return 'لا يمكن $operationLabel: تجاوز الحد الأقصى للحصص اليومية للأستاذ (${teacher.name})';
      }
    }

    if (teacher?.unavailableDays.contains(newDay) ?? false) {
      return 'لا يمكن $operationLabel: الأستاذ مفرغ في اليوم المقترح ولا يمكن وضع حصة له';
    }

    if (subject != null &&
        subject.allowedPeriods.isNotEmpty &&
        !subject.allowedPeriods.contains(newPeriod)) {
      return 'لا يمكن $operationLabel: المادة غير مسموح بتدريسها في الحصة (${newPeriod + 1}) بناءً على إعداداتها';
    }

    return null;
  }

  bool get isDragDropOperationInProgress => _dragDropOperationInProgress;

  bool _beginDragDropOperation() {
    if (_dragDropOperationInProgress) {
      return false;
    }
    _dragDropOperationInProgress = true;
    return true;
  }

  void _endDragDropOperation() {
    _dragDropOperationInProgress = false;
  }

  Future<(bool, String?)> assignLessonsToPool(
      Classroom classroom, Subject subject, Teacher teacher) async {
    final isar = await ref.read(isarDatabaseProvider.future);

    final allLessons = await isar.lessons.where().findAll();

    // Check duplicate assignment
    bool duplicateAssignment = allLessons.any((l) =>
        l.classroom.value?.id == classroom.id &&
        l.subject.value?.id == subject.id);

    if (duplicateAssignment) {
      return (false, "تم إسناد هذه المادة لهذا الصف مسبقاً");
    }

    // Check real-time classroom capacity overload
    final settingsList = await isar.appSettings.where().findAll();
    final settings = settingsList.isNotEmpty
        ? settingsList.first
        : (AppSettings()..periodsPerDay = 7);
    int maxClassroomCapacity = settings.periodsPerDay * settings.daysPerWeek;

    int classAssignedLessons =
        allLessons.where((l) => l.classroom.value?.id == classroom.id).length;
    int proposedClassTotal = classAssignedLessons + subject.lessonsPerWeek;

    if (proposedClassTotal > maxClassroomCapacity) {
      return (
        false,
        "تحذير: لا يمكن الإسناد. الصف ${classroom.name} سيصل إلى $proposedClassTotal حصة، مما يتجاوز السعة القصوى للجدول الأسبوعي ($maxClassroomCapacity حصة)."
      );
    }

    // Check real-time teacher capacity overload
    int teacherAssignedLessons =
        allLessons.where((l) => l.teacher.value?.id == teacher.id).length;
    int proposedTeacherTotal = teacherAssignedLessons + subject.lessonsPerWeek;

    int activeUnavailableDays = teacher.unavailableDays
        .where((day) => day < settings.daysPerWeek)
        .length;
    int availableDays = settings.daysPerWeek - activeUnavailableDays;

    int maxCapacityDays = teacher.maxLessonsPerDay * availableDays;
    int absoluteMaxCapacity = teacher.maxLessonsPerWeek < maxCapacityDays
        ? teacher.maxLessonsPerWeek
        : maxCapacityDays;

    if (proposedTeacherTotal > absoluteMaxCapacity) {
      return (
        false,
        "تحذير: لا يمكن إسناد هذه المادة. المعلم ${teacher.name} سيصل إلى $proposedTeacherTotal حصة، مما يتجاوز حده المسموح ($absoluteMaxCapacity حصة). يرجى اختيار معلم آخر."
      );
    }

    final newLessons = <Lesson>[];
    for (int i = 0; i < subject.lessonsPerWeek; i++) {
      final lesson = Lesson()
        ..classroom.value = classroom
        ..subject.value = subject
        ..teacher.value = teacher;
      newLessons.add(lesson);
    }

    isar.writeTxnSync(() {
      isar.lessons.putAllSync(newLessons);
      for (var l in newLessons) {
        l.classroom.saveSync();
        l.subject.saveSync();
        l.teacher.saveSync();
      }
    });

    final lessons = await _loadPersistedLessons(isar, force: true);
    _setVisibleLessons(lessons);
    state = AsyncValue.data(lessons);
    return (true, null);
  }

  Future<void> deleteAssignment(int classroomId, int subjectId) async {
    final isar = await ref.read(isarDatabaseProvider.future);
    final allLessons = await isar.lessons.where().findAll();
    final toDelete = allLessons
        .where((l) =>
            l.classroom.value?.id == classroomId &&
            l.subject.value?.id == subjectId)
        .toList();

    isar.writeTxnSync(() {
      isar.lessons.deleteAllSync(toDelete.map((e) => e.id).toList());
    });
    final lessons = await _loadPersistedLessons(isar, force: true);
    _setVisibleLessons(lessons);
    state = AsyncValue.data(lessons);
  }

  Future<void> updateAssignment(
      int classroomId, int subjectId, Teacher newTeacher) async {
    final isar = await ref.read(isarDatabaseProvider.future);
    final allLessons = await isar.lessons.where().findAll();
    final toUpdate = allLessons
        .where((l) =>
            l.classroom.value?.id == classroomId &&
            l.subject.value?.id == subjectId)
        .toList();

    isar.writeTxnSync(() {
      for (var lesson in toUpdate) {
        lesson.teacher.value = newTeacher;
        isar.lessons.putSync(lesson);
        lesson.teacher.saveSync();
      }
    });
    final lessons = await _loadPersistedLessons(isar, force: true);
    _setVisibleLessons(lessons);
    state = AsyncValue.data(lessons);
  }

  Future<void> generateTimetable() async {
    state = const AsyncValue.loading();
    _previewEntities = null;
    _persistedLessonsCache = null;
    _persistedLessonsById = null;
    _visibleLessonsCache = null;
    _invalidateInteractionCache();
    ref.read(timetableAutoFixStateProvider.notifier).state =
        const TimetableAutoFixState();

    try {
      final isar = await ref.read(isarDatabaseProvider.future);

      final teachers = await isar.teachers.where().findAll();
      final subjects = await isar.subjects.where().findAll();
      final classrooms = await isar.classrooms.where().findAll();
      final constraints = await isar.subjectConstraints.where().findAll();
      _subjectConstraintsCache = constraints;
      final settingsList = await isar.appSettings.where().findAll();
      final settings = settingsList.isNotEmpty
          ? settingsList.first
          : (AppSettings()..periodsPerDay = 7);

      // Clear existing schedule assignments by resetting indexes
      final existingLessons = await isar.lessons.where().findAll();

      // Map Isar to DTOs
      final teachersMap = {
        for (var t in teachers) t.id: TeacherEntity.fromIsar(t)
      };
      final subjectsMap = {
        for (var s in subjects) s.id: SubjectEntity.fromIsar(s)
      };
      final classroomsMap = {
        for (var c in classrooms) c.id: ClassroomEntity.fromIsar(c)
      };

      final existingLessonsEntity = existingLessons
          .map((l) =>
              LessonEntity.fromIsar(l, teachersMap, subjectsMap, classroomsMap))
          .toList();

      final settingsEntity = AppSettingsEntity.fromIsar(settings);

      final teachersEntityList = teachersMap.values.toList();
      final subjectsEntityList = subjectsMap.values.toList();
      final classroomsEntityList = classroomsMap.values.toList();
      final constraintsEntityList =
          constraints.map((c) => SubjectConstraintEntity.fromIsar(c)).toList();

      // Create payload to avoid capturing anything from lexical scope
      final payload = GenerationPayload(
        teachers: teachersEntityList,
        subjects: subjectsEntityList,
        classrooms: classroomsEntityList,
        settings: settingsEntity,
        existingLessons: existingLessonsEntity,
        subjectConstraints: constraintsEntityList,
      );
      _lastPayload = payload;

      // Run Generator in an Isolate using a top-level function to avoid capturing `this`
      final resultEntities = await _spawnIsolateAndGenerate(payload);

      // Map DTOs back to existingLessons
      for (var lessonDto in resultEntities) {
        final lesson = existingLessons.firstWhere((l) => l.id == lessonDto.id);
        lesson.dayIndex = lessonDto.dayIndex;
        lesson.periodIndex = lessonDto.periodIndex;
      }

      // Ensure that we save the entire modified pool (even those unplaced/unscheduled)
      // Since generator modifies existingLessons in-place and returns it.
      isar.writeTxnSync(() {
        isar.lessons.putAllSync(existingLessons);
        for (var lesson in existingLessons) {
          lesson.teacher.saveSync();
          lesson.subject.saveSync();
          lesson.classroom.saveSync();
        }
      });

      for (var lesson in existingLessons) {
        lesson.classroom.loadSync();
        lesson.subject.loadSync();
        lesson.teacher.loadSync();
      }
      _setPersistedLessons(existingLessons);
      _setVisibleLessons(existingLessons);
      state = AsyncValue.data(existingLessons);
      ref.read(timetableAutoFixStateProvider.notifier).state =
          const TimetableAutoFixState();
    } on TimetableGenerationException catch (exception) {
      // Restore valid data state to avoid generic error widget
      final isar = await ref.read(isarDatabaseProvider.future);
      final lessons = await _loadPersistedLessons(isar, force: true);
      _setVisibleLessons(lessons);

      final snapshot = exception.bestSchedule;
      if (_lastPayload != null && snapshot != null) {
        _previewEntities = _applySnapshot(
          _lastPayload!.existingLessons,
          snapshot,
        );
        final previewLessons = _previewEntities!
            .map((lesson) => _toPreviewLesson(lesson, lessons))
            .toList();
        _setVisibleLessons(previewLessons);
        state = AsyncValue.data(previewLessons);
        ref.read(timetableAutoFixStateProvider.notifier).state =
            TimetableAutoFixState(
          status: TimetableAutoFixStatus.ready,
          bestCost: exception.bestCost,
          diagnostics: exception.diagnostics,
        );
      } else {
        _setVisibleLessons(lessons);
        state = AsyncValue.data(lessons);
      }

      // Rethrow to the UI try-catch block
      rethrow;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> runSmartAutoFix() async {
    final payload = _lastPayload;
    final preview = _previewEntities;
    final autoFixState = ref.read(timetableAutoFixStateProvider);
    if (payload == null || preview == null || !autoFixState.canFix) {
      return false;
    }

    ref.read(timetableAutoFixStateProvider.notifier).state =
        autoFixState.copyWith(
      status: TimetableAutoFixStatus.fixing,
      currentAttempt: 1,
      totalAttempts: SmartAutoFixUseCase.maxAttempts,
    );

    try {
      final result = await _spawnIsolateAndAutoFix(
        AutoFixPayload(
          teachers: payload.teachers,
          subjects: payload.subjects,
          classrooms: payload.classrooms,
          settings: payload.settings,
          existingLessons: preview,
          subjectConstraints: payload.subjectConstraints,
          diagnostics: autoFixState.diagnostics,
        ),
        (attempt, total) {
          final current = ref.read(timetableAutoFixStateProvider);
          if (!current.isFixing) return;
          ref.read(timetableAutoFixStateProvider.notifier).state =
              current.copyWith(
            currentAttempt: attempt,
            totalAttempts: total,
          );
        },
      );

      final isar = await ref.read(isarDatabaseProvider.future);
      final persistedLessons = await _loadPersistedLessons(isar, force: true);

      if (result.isResolved) {
        final placements = {
          for (final lesson in result.schedule) lesson.id: lesson,
        };
        for (final lesson in persistedLessons) {
          final placement = placements[lesson.id];
          if (placement == null) continue;
          lesson.dayIndex = placement.dayIndex;
          lesson.periodIndex = placement.periodIndex;
        }

        isar.writeTxnSync(() {
          isar.lessons.putAllSync(persistedLessons);
        });

        for (final lesson in persistedLessons) {
          lesson.classroom.loadSync();
          lesson.subject.loadSync();
          lesson.teacher.loadSync();
        }
        _previewEntities = null;
        _setPersistedLessons(persistedLessons);
        _setVisibleLessons(persistedLessons);
        ref.read(timetableAutoFixStateProvider.notifier).state =
            const TimetableAutoFixState();
        state = AsyncValue.data(persistedLessons);
        return true;
      }

      _previewEntities = result.schedule;
      final previewLessons = result.schedule
          .map((entity) => _toPreviewLesson(entity, persistedLessons))
          .toList();
      _setVisibleLessons(previewLessons);
      state = AsyncValue.data(previewLessons);
      ref.read(timetableAutoFixStateProvider.notifier).state =
          TimetableAutoFixState(
        status: TimetableAutoFixStatus.failed,
        bestCost: result.bestCost,
        // Keep the original diagnostics so a failed retry restores the
        // complete conflict dialog that opened after generation failed.
        diagnostics: autoFixState.diagnostics,
      );
      return false;
    } catch (error, stackTrace) {
      ref.read(timetableAutoFixStateProvider.notifier).state =
          autoFixState.copyWith(
        status: TimetableAutoFixStatus.failed,
        currentAttempt: 0,
        totalAttempts: SmartAutoFixUseCase.maxAttempts,
      );

      // Keep the best failed preview visible so the user can inspect it or retry
      // after a transient isolate/database failure. Never persist this preview.
      try {
        final isar = await ref.read(isarDatabaseProvider.future);
        final persistedLessons = await _loadPersistedLessons(isar);
        final preview = _previewEntities;
        if (preview != null) {
          final previewLessons = preview
              .map((entity) => _toPreviewLesson(entity, persistedLessons))
              .toList();
          _setVisibleLessons(previewLessons);
          state = AsyncValue.data(previewLessons);
        } else {
          state = AsyncValue.error(error, stackTrace);
        }
      } catch (_) {
        state = AsyncValue.error(error, stackTrace);
      }
      return false;
    }
  }

  List<LessonEntity> _applySnapshot(
    List<LessonEntity> source,
    TimetableScheduleSnapshot snapshot,
  ) {
    final placements = {
      for (final placement in snapshot.placements)
        placement.lessonId: placement,
    };
    return source.map(
      (lesson) {
        final placement = placements[lesson.id];
        return LessonEntity(
          id: lesson.id,
          teacher: lesson.teacher,
          subject: lesson.subject,
          classroom: lesson.classroom,
          dayIndex: placement?.dayIndex ?? lesson.dayIndex,
          periodIndex: placement?.periodIndex ?? lesson.periodIndex,
          isPinned: lesson.isPinned,
        );
      },
    ).toList();
  }

  Lesson _toPreviewLesson(LessonEntity entity, List<Lesson> persistedLessons) {
    final source = _persistedLessonsById?[entity.id] ??
        persistedLessons.firstWhere((lesson) => lesson.id == entity.id);
    return Lesson()
      ..id = source.id
      ..dayIndex = entity.dayIndex
      ..periodIndex = entity.periodIndex
      ..isPinned = source.isPinned
      ..teacher.value = source.teacher.value
      ..subject.value = source.subject.value
      ..classroom.value = source.classroom.value;
  }

  Future<void> togglePin(Lesson lesson) async {
    final isar = await ref.read(isarDatabaseProvider.future);
    final currentLesson = _visibleLessonsCache
            ?.where((item) => item.id == lesson.id)
            .firstOrNull ??
        _persistedLessonsCache
            ?.where((item) => item.id == lesson.id)
            .firstOrNull ??
        lesson;
    isar.writeTxnSync(() {
      currentLesson.isPinned = !currentLesson.isPinned;
      isar.lessons.putSync(currentLesson);
    });
    _persistedLessonsById?[currentLesson.id] = currentLesson;
    if (_previewEntities == null) {
      _publishVisibleLessons();
    }
  }

  Future<(bool, String?)> moveLessonToEmpty(
      Lesson lesson, int newDay, int newPeriod) async {
    if (!_beginDragDropOperation()) {
      return (false, "يرجى الانتظار حتى تكتمل عملية السحب الحالية");
    }

    try {
      return await _moveLessonToEmptyInternal(lesson, newDay, newPeriod);
    } finally {
      _endDragDropOperation();
    }
  }

  Future<(bool, String?)> _moveLessonToEmptyInternal(
      Lesson lesson, int newDay, int newPeriod) async {
    if (lesson.isPinned) return (false, "لا يمكن تحريك درس مقفل");

    final isar = await ref.read(isarDatabaseProvider.future);
    final persistedLessons = await _loadPersistedLessons(isar);
    final index = await _ensureInteractionIndex(isar);
    final currentLesson = index.lessonById(lesson.id) ?? lesson;
    final previewEntities = _previewEntities;

    final validationError = _validatePlacement(
      index: index,
      lesson: currentLesson,
      newDay: newDay,
      newPeriod: newPeriod,
      excludedLessonIds: {currentLesson.id},
      operationLabel: 'النقل',
    );
    if (validationError != null) {
      return (false, validationError);
    }

    index.moveLesson(
      lessonId: currentLesson.id,
      newDay: newDay,
      newPeriod: newPeriod,
    );

    if (previewEntities != null) {
      _updatePreviewEntityPosition(currentLesson.id, newDay, newPeriod);
      _publishVisibleLessons();
      return (true, null);
    }

    isar.writeTxnSync(() {
      isar.lessons.putSync(currentLesson);
    });
    _persistedLessonsCache = persistedLessons;
    _persistedLessonsById = {
      for (final item in persistedLessons) item.id: item
    };
    _publishVisibleLessons();
    return (true, null);
  }

  Future<(bool, String?)> swapLessons(Lesson lesson1, Lesson lesson2) async {
    if (!_beginDragDropOperation()) {
      return (false, "يرجى الانتظار حتى تكتمل عملية السحب الحالية");
    }

    try {
      return await _swapLessonsInternal(lesson1, lesson2);
    } finally {
      _endDragDropOperation();
    }
  }

  Future<(bool, String?)> _swapLessonsInternal(
      Lesson lesson1, Lesson lesson2) async {
    if (lesson1.dayIndex == null ||
        lesson1.periodIndex == null ||
        lesson2.dayIndex == null ||
        lesson2.periodIndex == null) {
      return (false, "لا يمكن تبديل دروس غير مجدولة");
    }

    if (lesson1.isPinned || lesson2.isPinned) {
      return (false, "لا يمكن تبديل دروس مقفلة");
    }

    final isar = await ref.read(isarDatabaseProvider.future);
    final persistedLessons = await _loadPersistedLessons(isar);
    final index = await _ensureInteractionIndex(isar);
    final currentLesson1 = index.lessonById(lesson1.id) ?? lesson1;
    final currentLesson2 = index.lessonById(lesson2.id) ?? lesson2;
    final previewEntities = _previewEntities;
    final excludedIds = {currentLesson1.id, currentLesson2.id};

    final firstValidationError = _validatePlacement(
      index: index,
      lesson: currentLesson1,
      newDay: currentLesson2.dayIndex!,
      newPeriod: currentLesson2.periodIndex!,
      excludedLessonIds: excludedIds,
      operationLabel: 'التبديل',
    );
    if (firstValidationError != null) {
      return (false, firstValidationError);
    }

    final secondValidationError = _validatePlacement(
      index: index,
      lesson: currentLesson2,
      newDay: currentLesson1.dayIndex!,
      newPeriod: currentLesson1.periodIndex!,
      excludedLessonIds: excludedIds,
      operationLabel: 'التبديل',
    );
    if (secondValidationError != null) {
      return (false, secondValidationError);
    }

    final firstDay = currentLesson1.dayIndex;
    final firstPeriod = currentLesson1.periodIndex;
    final secondDay = currentLesson2.dayIndex;
    final secondPeriod = currentLesson2.periodIndex;
    if (!index.swapLessons(
      firstId: currentLesson1.id,
      secondId: currentLesson2.id,
    )) {
      return (false, "تعذر العثور على الدروس المطلوب تبديلها");
    }

    if (previewEntities != null) {
      _updatePreviewEntityPosition(currentLesson1.id, secondDay, secondPeriod);
      _updatePreviewEntityPosition(currentLesson2.id, firstDay, firstPeriod);
      _publishVisibleLessons();
      return (true, null);
    }

    isar.writeTxnSync(() {
      isar.lessons.putAllSync([currentLesson1, currentLesson2]);
    });
    _persistedLessonsCache = persistedLessons;
    _persistedLessonsById = {
      for (final item in persistedLessons) item.id: item
    };
    _publishVisibleLessons();
    return (true, null);
  }
}

class GenerationPayload {
  final List<TeacherEntity> teachers;
  final List<SubjectEntity> subjects;
  final List<ClassroomEntity> classrooms;
  final AppSettingsEntity settings;
  final List<LessonEntity> existingLessons;
  final List<SubjectConstraintEntity> subjectConstraints;

  const GenerationPayload({
    required this.teachers,
    required this.subjects,
    required this.classrooms,
    required this.settings,
    required this.existingLessons,
    required this.subjectConstraints,
  });
}

Future<List<LessonEntity>> _spawnIsolateAndGenerate(
    GenerationPayload payload) async {
  // هذه الدالة موجودة في Top-Level، لذا لا يوجد هنا 'this' ولا 'isar' ليلتقطه الـ Closure!
  return await Isolate.run(() => _generateInIsolate(payload));
}

/// A top-level function that strictly accepts DTOs, isolating memory.
List<LessonEntity> _generateInIsolate(GenerationPayload payload) {
  final generator = TimetableGenerator(
    teachers: payload.teachers,
    subjects: payload.subjects,
    classrooms: payload.classrooms,
    settings: payload.settings,
    existingLessons: payload.existingLessons,
    subjectConstraints: payload.subjectConstraints,
  );
  return generator.generate();
}

class AutoFixPayload {
  final List<TeacherEntity> teachers;
  final List<SubjectEntity> subjects;
  final List<ClassroomEntity> classrooms;
  final AppSettingsEntity settings;
  final List<LessonEntity> existingLessons;
  final List<SubjectConstraintEntity> subjectConstraints;
  final List<ConflictDiagnostic> diagnostics;

  const AutoFixPayload({
    required this.teachers,
    required this.subjects,
    required this.classrooms,
    required this.settings,
    required this.existingLessons,
    required this.subjectConstraints,
    required this.diagnostics,
  });
}

class _AutoFixIsolateMessage {
  final AutoFixPayload payload;
  final SendPort resultPort;
  final SendPort progressPort;

  const _AutoFixIsolateMessage({
    required this.payload,
    required this.resultPort,
    required this.progressPort,
  });
}

Future<SmartAutoFixResult> _spawnIsolateAndAutoFix(
  AutoFixPayload payload,
  void Function(int attempt, int total) onProgress,
) async {
  final resultPort = ReceivePort();
  final progressPort = ReceivePort();
  final errorPort = ReceivePort();
  final isolate = await Isolate.spawn(
    _runAutoFixInIsolate,
    _AutoFixIsolateMessage(
      payload: payload,
      resultPort: resultPort.sendPort,
      progressPort: progressPort.sendPort,
    ),
    onError: errorPort.sendPort,
  );

  final progressSubscription = progressPort.listen((message) {
    if (message is List &&
        message.length == 2 &&
        message[0] is int &&
        message[1] is int) {
      onProgress(message[0] as int, message[1] as int);
    }
  });

  try {
    return await Future.any<SmartAutoFixResult>([
      resultPort.first.then((message) {
        if (message is SmartAutoFixResult) return message;
        throw StateError('تعذر استلام نتيجة Smart Auto-Fix من isolate.');
      }),
      errorPort.first.then((message) {
        throw StateError('فشل تنفيذ Smart Auto-Fix داخل isolate: $message');
      }),
      Future<SmartAutoFixResult>.delayed(
        _smartAutoFixTimeout,
        () => throw TimeoutException(
          'انتهت مهلة Smart Auto-Fix بعد 30 ثانية.',
        ),
      ),
    ]);
  } finally {
    await progressSubscription.cancel();
    resultPort.close();
    progressPort.close();
    errorPort.close();
    isolate.kill(priority: Isolate.immediate);
  }
}

void _runAutoFixInIsolate(_AutoFixIsolateMessage message) {
  final payload = message.payload;
  final useCase = SmartAutoFixUseCase(
    teachers: payload.teachers,
    subjects: payload.subjects,
    classrooms: payload.classrooms,
    settings: payload.settings,
    subjectLessons: payload.existingLessons,
    subjectConstraints: payload.subjectConstraints,
  );
  final result = useCase.execute(
    initialSchedule: payload.existingLessons,
    initialDiagnostics: payload.diagnostics,
    onProgress: (attempt, total) {
      message.progressPort.send([attempt, total]);
    },
  );
  message.resultPort.send(result);
}
