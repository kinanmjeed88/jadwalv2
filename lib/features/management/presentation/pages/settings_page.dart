import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../../../core/models/settings.dart';
import '../../../../core/providers/repository_provider.dart';
import '../providers/management_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);

    return Scaffold(
      body: settingsAsync.when(
        data: (settings) => _SettingsForm(settings: settings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('حدث خطأ: \$e')),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  final AppSettings settings;
  const _SettingsForm({required this.settings});

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late int _periodsPerDay;
  late int _daysPerWeek;
  late String _exportPageSize;
  late String _exportOrientation;
  late bool _exportAutoScale;

  @override
  void initState() {
    super.initState();
    _periodsPerDay = widget.settings.periodsPerDay;
    _daysPerWeek = widget.settings.daysPerWeek;
    _exportPageSize = widget.settings.exportPageSize;
    _exportOrientation = widget.settings.exportOrientation;
    _exportAutoScale = widget.settings.exportAutoScale;
  }

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final newSettings = widget.settings
        ..periodsPerDay = _periodsPerDay
        ..daysPerWeek = _daysPerWeek
        ..exportPageSize = _exportPageSize
        ..exportOrientation = _exportOrientation
        ..exportAutoScale = _exportAutoScale;

      ref.read(settingsNotifierProvider.notifier).saveSettings(newSettings);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الإعدادات بنجاح')),
      );
    }
  }

  Future<void> _exportData() async {
    try {
      final backupService = await ref.read(backupServiceProvider.future);
      final jsonStr = await backupService.exportDatabaseToJson();

      // In a real device we'd use a file picker to choose location,
      // here we just simulate saving to a default location for demo purposes.
      // We will try to use file_picker to get a directory.
      String? outputFile = await FilePicker.saveFile(
        dialogTitle: 'احفظ النسخة الاحتياطية',
        fileName: 'jadwal_backup.json',
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(jsonStr);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تصدير البيانات بنجاح')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في التصدير: \$e')),
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final jsonStr = await file.readAsString();

        final backupService = await ref.read(backupServiceProvider.future);
        await backupService.importDatabaseFromJson(jsonStr);

        if (mounted) {
          // Refresh data providers
          ref.invalidate(teachersNotifierProvider);
          ref.invalidate(subjectsNotifierProvider);
          ref.invalidate(classroomsNotifierProvider);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم استيراد البيانات بنجاح')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في الاستيراد: \$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الإعدادات العامة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _periodsPerDay.toString(),
                      decoration: const InputDecoration(labelText: 'عدد الحصص في اليوم', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || int.tryParse(val) == null ? 'أدخل رقماً صحيحاً' : null,
                      onSaved: (val) => _periodsPerDay = int.parse(val!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _daysPerWeek.toString(),
                      decoration: const InputDecoration(labelText: 'عدد أيام الدوام في الأسبوع', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || int.tryParse(val) == null ? 'أدخل رقماً صحيحاً' : null,
                      onSaved: (val) => _daysPerWeek = int.parse(val!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('إعدادات التصدير (PDF)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _exportPageSize,
                      decoration: const InputDecoration(labelText: 'حجم الصفحة', border: OutlineInputBorder()),
                      items: ['A4', 'A3', 'Custom'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) => setState(() => _exportPageSize = newValue!),
                      onSaved: (val) => _exportPageSize = val!,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _exportOrientation,
                      decoration: const InputDecoration(labelText: 'اتجاه الصفحة', border: OutlineInputBorder()),
                      items: ['Portrait', 'Landscape'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) => setState(() => _exportOrientation = newValue!),
                      onSaved: (val) => _exportOrientation = val!,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('التمدد التلقائي للجدول'),
                      value: _exportAutoScale,
                      onChanged: (val) => setState(() => _exportAutoScale = val ?? true),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('نظام النسخ الاحتياطي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('تصدير البيانات (Backup)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.teal.shade100,
                      foregroundColor: Colors.teal.shade900,
                    ),
                    onPressed: _exportData,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('استيراد البيانات (Restore)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.orange.shade100,
                      foregroundColor: Colors.orange.shade900,
                    ),
                    onPressed: _importData,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: const Text('حفظ الإعدادات', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
