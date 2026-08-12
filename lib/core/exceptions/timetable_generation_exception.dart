import 'conflict_reason.dart';

class TimetableGenerationException implements Exception {
  final List<ConflictReason> reasons;

  TimetableGenerationException(this.reasons);

  @override
  String toString() => 'TimetableGenerationException: ${reasons.length} conflicts';
}
