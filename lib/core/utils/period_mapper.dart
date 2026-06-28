class PeriodMapper {
  static const List<String> _arabicLessons = [
    'الدرس الأول',
    'الدرس الثاني',
    'الدرس الثالث',
    'الدرس الرابع',
    'الدرس الخامس',
    'الدرس السادس',
    'الدرس السابع',
    'الدرس الثامن',
    'الدرس التاسع',
    'الدرس العاشر',
  ];

  static String toArabicName(int index) {
    if (index >= 0 && index < _arabicLessons.length) {
      return _arabicLessons[index];
    }
    // Fallback if needed, using string concatenation without RTL interpolation issues
    return 'الدرس رقم ' + (index + 1).toString();
  }
}
