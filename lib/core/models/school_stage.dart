/// المرحلة الدراسية التي يخدمها التطبيق.
///
/// تُستخدم المرحلة لتحديد سياسة "تخطي قيود المواد" الافتراضية:
/// * [SchoolStage.primary]: تُفعَّل السياسة تلقائيًا للمواد التي يتجاوز
///   نصابها الأسبوعي ٦ حصص (اللغة العربية والرياضيات غالبًا)، فيسمح النظام
///   بتكرار حصتين في اليوم نفسه بدل حصة واحدة.
/// * [SchoolStage.middleAndAbove]: لا تُفعَّل أي سياسة تلقائية، وتبقى
///   القيود بيد المستخدم فقط.
enum SchoolStage {
  primary(
    label: 'ابتدائي',
    description: 'يُسمح للمواد التي يتجاوز نصابها الأسبوعي ٦ حصص '
        '(مثل اللغة العربية والرياضيات) بتكرار حصتين في اليوم نفسه.',
  ),
  middleAndAbove(
    label: 'متوسط فأعلى',
    description: 'تُطبَّق قيود المواد اليدوية فقط دون أي تخطٍّ تلقائي.',
  );

  const SchoolStage({
    required this.label,
    required this.description,
  });

  /// الاسم العربي المعروض في الواجهة.
  final String label;

  /// وصف مختصر يُعرض بجانب الاختيار ليوضح أثره على الجدول.
  final String description;

  /// القيمة المخزَّنة في ملف الإعدادات.
  String get storageName => name;

  /// المرحلة المستخدمة عند غياب قيمة صريحة (مستخدمون قدامى أو ملف تالف).
  ///
  /// اختيار [SchoolStage.middleAndAbove] مقصود لأنه لا يغيّر سلوك الجدول
  /// تلقائيًا، فلا نُدخل تعديلات غير متوقعة على بيانات مستخدم قائم.
  static const SchoolStage fallback = SchoolStage.middleAndAbove;

  /// هل تُفعَّل سياسة تخطي قيود المواد التلقائية لهذه المرحلة؟
  bool get enablesAutomaticConstraintBypass => this == SchoolStage.primary;

  /// يحوّل قيمة مخزَّنة (قد تكون تالفة أو قديمة) إلى مرحلة صحيحة.
  static SchoolStage fromStorage(Object? value) {
    for (final stage in SchoolStage.values) {
      if (stage.name == value) {
        return stage;
      }
    }
    return fallback;
  }
}
