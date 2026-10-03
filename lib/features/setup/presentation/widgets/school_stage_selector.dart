import 'package:flutter/material.dart';

import '../../../../core/models/school_stage.dart';

/// مُحدِّد المرحلة الدراسية (ابتدائي / متوسط فأعلى) على شكل أزرار اختيار.
///
/// استُخدم `ChoiceChip` بدل القوائم المنسدلة ليعمل على جميع إصدارات Flutter
/// المدعومة في فروع المشروع (أندرويد/ويندوز ٧/ويندوز ١٠ و١١) مع وضوح بصري
/// أكبر وعدد الخيارات المحدود.
class SchoolStageSelector extends StatelessWidget {
  const SchoolStageSelector({
    super.key,
    required this.value,
    this.onChanged,
  });

  /// المرحلة المختارة حاليًا (أو `null` قبل الاختيار).
  final SchoolStage? value;

  /// يُستدعى عند اختيار مرحلة جديدة؛ إذا كان `null` يصبح المُحدِّد للعرض فقط.
  final ValueChanged<SchoolStage>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: <Widget>[
        for (final stage in SchoolStage.values)
          ChoiceChip(
            label: Text(stage.label),
            selected: value == stage,
            onSelected: onChanged == null
                ? null
                : (selected) {
                    if (selected) {
                      onChanged!(stage);
                    }
                  },
          ),
      ],
    );
  }
}
