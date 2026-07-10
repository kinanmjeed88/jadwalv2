extension StringUtils on String {
  /// Removes any text inside parentheses (along with the parentheses themselves)
  /// and trims any extra whitespace. Useful for cleaning up subject names in grids.
  String cleanSubjectName() {
    return replaceAll(RegExp(r'\s*\(.*?\)\s*'), '').trim();
  }
}
