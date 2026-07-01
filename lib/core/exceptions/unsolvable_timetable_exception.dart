class UnsolvableTimetableException implements Exception {
  final String message;
  UnsolvableTimetableException([this.message = 'تعذر توليد الجدول. القيود صارمة جداً أو لا توجد أوقات فراغ كافية. يرجى تخفيف القيود والمحاولة مجدداً.']);

  @override
  String toString() => message;
}
