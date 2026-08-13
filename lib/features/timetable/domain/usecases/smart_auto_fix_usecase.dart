import 'dart:math';

import '../../../../core/entities/app_settings_entity.dart';
import '../../../../core/entities/classroom_entity.dart';
import '../../../../core/entities/lesson_entity.dart';
import '../../../../core/entities/subject_constraint_entity.dart';
import '../../../../core/entities/subject_entity.dart';
import '../../../../core/entities/teacher_entity.dart';
import '../../../../core/exceptions/timetable_generation_exception.dart';
import 'timetable_generator.dart';

class SmartAutoFixResult {
  final List<LessonEntity> schedule;
  final List<ConflictDiagnostic> diagnostics;
  final int bestCost;

  const SmartAutoFixResult({
    required this.schedule,
    required this.diagnostics,
    required this.bestCost,
  });

  bool get isResolved => diagnostics.every((diagnostic) => !diagnostic.isHard);
}

class SmartAutoFixUseCase {
  static const int maxAttempts = 5;
  static const int maxIterationsPerAttempt = 120;

  final TimetableGenerator _generator;
  final int maxDays;
  final int maxPeriods;

  SmartAutoFixUseCase({
    required List<TeacherEntity> teachers,
    required List<SubjectEntity> subjects,
    required List<ClassroomEntity> classrooms,
    required AppSettingsEntity settings,
    required List<LessonEntity> subjectLessons,
    required List<SubjectConstraintEntity> subjectConstraints,
  })  : maxDays = settings.daysPerWeek,
        maxPeriods = settings.periodsPerDay,
        _generator = TimetableGenerator(
          teachers: teachers,
          subjects: subjects,
          classrooms: classrooms,
          settings: settings,
          existingLessons: subjectLessons,
          subjectConstraints: subjectConstraints,
        );

  SmartAutoFixResult execute({
    required List<LessonEntity> initialSchedule,
    required List<ConflictDiagnostic> initialDiagnostics,
  }) {
    var bestSchedule = _cloneState(initialSchedule);
    var bestScore = _score(bestSchedule);
    var bestDiagnostics = _generator.diagnose(bestSchedule);
    final random = Random();

    if (bestScore.hardConflicts == 0) {
      return SmartAutoFixResult(
        schedule: bestSchedule,
        diagnostics: bestDiagnostics,
        bestCost: bestScore.cost,
      );
    }

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      var currentSchedule = _cloneState(bestSchedule);
      var currentScore = _score(currentSchedule);

      for (var iteration = 0;
          iteration < maxIterationsPerAttempt;
          iteration++) {
        final currentDiagnostics = _generator.diagnose(currentSchedule);
        if (currentDiagnostics.every((diagnostic) => !diagnostic.isHard)) {
          return SmartAutoFixResult(
            schedule: currentSchedule,
            diagnostics: currentDiagnostics,
            bestCost: _generator.calculateCost(currentSchedule),
          );
        }

        final neighbors = _targetedNeighbors(
          currentSchedule,
          currentDiagnostics.isEmpty ? initialDiagnostics : currentDiagnostics,
          random,
        );
        if (neighbors.isEmpty) break;

        final candidateScores = neighbors
            .map((candidate) => _ScoredSchedule(candidate, _score(candidate)))
            .toList();
        candidateScores.sort((a, b) => a.score.compareTo(b.score));
        final bestCandidate = candidateScores.first;

        if (bestCandidate.score < currentScore) {
          currentSchedule = bestCandidate.schedule;
          currentScore = bestCandidate.score;

          if (currentScore < bestScore) {
            bestSchedule = _cloneState(currentSchedule);
            bestScore = currentScore;
            bestDiagnostics = _generator.diagnose(bestSchedule);
          }
        } else if (iteration % 12 == 0) {
          // A bounded random escape prevents a deterministic local minimum while
          // keeping every move targeted to a currently reported conflict.
          final exploratory =
              candidateScores[random.nextInt(candidateScores.length)].schedule;
          currentSchedule = exploratory;
          currentScore = _score(currentSchedule);
        }
      }

      if (bestScore.hardConflicts == 0) break;
    }

    return SmartAutoFixResult(
      schedule: bestSchedule,
      diagnostics: bestDiagnostics,
      bestCost: bestScore.cost,
    );
  }

  List<List<LessonEntity>> _targetedNeighbors(
    List<LessonEntity> schedule,
    List<ConflictDiagnostic> diagnostics,
    Random random,
  ) {
    final targetIds = diagnostics
        .where((diagnostic) => diagnostic.isHard)
        .expand((diagnostic) => diagnostic.lessonIds)
        .toSet()
        .toList()
      ..shuffle(random);

    if (targetIds.isEmpty) return const [];

    final candidates = <List<LessonEntity>>[];
    final unpinned = schedule.where((lesson) => !lesson.isPinned).toList();
    final targetLessons = targetIds
        .map((id) => schedule.where((lesson) => lesson.id == id).firstOrNull)
        .whereType<LessonEntity>()
        .where((lesson) => !lesson.isPinned)
        .toList()
      ..shuffle(random);

    for (final target in targetLessons.take(4)) {
      final swapPartners = unpinned
          .where((lesson) => lesson.id != target.id)
          .toList()
        ..shuffle(random);
      for (final partner in swapPartners.take(12)) {
        final candidate = _cloneState(schedule);
        final candidateTarget =
            candidate.firstWhere((lesson) => lesson.id == target.id);
        final candidatePartner =
            candidate.firstWhere((lesson) => lesson.id == partner.id);
        final day = candidateTarget.dayIndex;
        final period = candidateTarget.periodIndex;
        candidateTarget.dayIndex = candidatePartner.dayIndex;
        candidateTarget.periodIndex = candidatePartner.periodIndex;
        candidatePartner.dayIndex = day;
        candidatePartner.periodIndex = period;
        candidates.add(candidate);
      }

      for (var day = 0; day < maxDays; day++) {
        for (var period = 0; period < maxPeriods; period++) {
          final occupyingLesson = schedule.where((lesson) {
            return lesson.id != target.id &&
                lesson.classroom?.id == target.classroom?.id &&
                lesson.dayIndex == day &&
                lesson.periodIndex == period;
          }).firstOrNull;

          if (occupyingLesson != null && occupyingLesson.isPinned) continue;

          final candidate = _cloneState(schedule);
          final candidateTarget =
              candidate.firstWhere((lesson) => lesson.id == target.id);
          candidateTarget.dayIndex = day;
          candidateTarget.periodIndex = period;

          if (occupyingLesson != null) {
            final candidateOccupying = candidate
                .firstWhere((lesson) => lesson.id == occupyingLesson.id);
            candidateOccupying.dayIndex = target.dayIndex;
            candidateOccupying.periodIndex = target.periodIndex;
          }
          candidates.add(candidate);
        }
      }
    }

    final seen = <String>{};
    return candidates.where((candidate) {
      final key = candidate
          .map((lesson) =>
              '${lesson.id}:${lesson.dayIndex}:${lesson.periodIndex}')
          .join('|');
      return seen.add(key);
    }).toList();
  }

  _FixScore _score(List<LessonEntity> schedule) {
    final diagnostics = _generator.diagnose(schedule);
    final hardConflicts =
        diagnostics.where((diagnostic) => diagnostic.isHard).length;
    return _FixScore(
      hardConflicts: hardConflicts,
      cost: _generator.calculateCost(schedule),
    );
  }

  List<LessonEntity> _cloneState(List<LessonEntity> source) {
    return source
        .map(
          (lesson) => LessonEntity(
            id: lesson.id,
            teacher: lesson.teacher,
            subject: lesson.subject,
            classroom: lesson.classroom,
            dayIndex: lesson.dayIndex,
            periodIndex: lesson.periodIndex,
            isPinned: lesson.isPinned,
          ),
        )
        .toList();
  }
}

class _ScoredSchedule {
  final List<LessonEntity> schedule;
  final _FixScore score;

  const _ScoredSchedule(this.schedule, this.score);
}

class _FixScore implements Comparable<_FixScore> {
  final int hardConflicts;
  final int cost;

  const _FixScore({required this.hardConflicts, required this.cost});

  @override
  int compareTo(_FixScore other) {
    final hardComparison = hardConflicts.compareTo(other.hardConflicts);
    return hardComparison == 0 ? cost.compareTo(other.cost) : hardComparison;
  }

  bool operator <(_FixScore other) => compareTo(other) < 0;
}
