class PeriodMapper {
  static const List<String> _arabicOrdinals = [
    'الأولى',
    'الثانية',
    'الثالثة',
    'الرابعة',
    'الخامسة',
    'السادسة',
    'السابعة',
    'الثامنة',
    'التاسعة',
    'العاشرة',
  ];

  static String toArabicName(int index) {
    if (index >= 0 && index < _arabicOrdinals.length) {
      return 'الحصة \${_arabicOrdinals[index]}';
    }
    return 'الحصة رقم \${index + 1}';
  }
}
