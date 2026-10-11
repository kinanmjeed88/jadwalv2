enum SubjectConsecutiveness {
  // Keep `any` first because Isar uses the first enum value as its
  // deserialization fallback for legacy or unknown values.
  any,
  consecutive,
  nonConsecutive,
}

extension SubjectConsecutivenessExtension on SubjectConsecutiveness {
  String get storageName => name;

  String get label {
    switch (this) {
      case SubjectConsecutiveness.consecutive:
        return 'متتالي (حصص اليوم الواحد متصلة)';
      case SubjectConsecutiveness.nonConsecutive:
        return 'غير متتالي (يُمنع تجاور حصص المادة)';
      case SubjectConsecutiveness.any:
        return 'بدون قيد';
    }
  }
}

SubjectConsecutiveness subjectConsecutivenessFromStorage(Object? value) {
  switch (value) {
    case 'consecutive':
      return SubjectConsecutiveness.consecutive;
    case 'nonConsecutive':
      return SubjectConsecutiveness.nonConsecutive;
    case 'any':
      return SubjectConsecutiveness.any;
    default:
      return SubjectConsecutiveness.any;
  }
}
