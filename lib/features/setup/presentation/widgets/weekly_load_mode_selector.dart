// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../../../core/models/weekly_load_policy.dart';

/// مُحدِّد السياسة العامة لعدد الحصص الأسبوعية:
/// * `30 حصة لجميع الصفوف`
/// * `الخطة الدراسية الرسمية`
class WeeklyLoadModeSelector extends StatelessWidget {
  const WeeklyLoadModeSelector({
    super.key,
    required this.value,
    this.onChanged,
  });

  final WeeklyLoadMode? value;
  final ValueChanged<WeeklyLoadMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final mode in WeeklyLoadMode.values)
          RadioListTile<WeeklyLoadMode>(
            value: mode,
            groupValue: value,
            onChanged: onChanged == null
                ? null
                : (selected) {
                    if (selected != null) {
                      onChanged!(selected);
                    }
                  },
            title: Text(
              mode.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              mode.description,
              style: const TextStyle(fontSize: 12.5),
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
      ],
    );
  }
}
