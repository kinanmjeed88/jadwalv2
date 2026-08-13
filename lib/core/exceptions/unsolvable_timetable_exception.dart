@Deprecated(
    'Use TimetableGenerationException with structured ConflictReason values instead.')
class UnsolvableTimetableException implements Exception {
  final String message;

  const UnsolvableTimetableException(this.message);

  @override
  String toString() => message;
}
