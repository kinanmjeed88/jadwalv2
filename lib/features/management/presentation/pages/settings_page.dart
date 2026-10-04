// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/models/app_config.dart';
import '../../../../core/models/school_stage.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/models/weekly_load_policy.dart';
import '../../../../core/providers/app_backup_provider.dart';
import '../../../../core/providers/app_config_provider.dart';
import '../../../setup/presentation/pages/first_run_setup_page.dart';
import '../../../setup/presentation/widgets/school_stage_selector.dart';
import '../../../setup/presentation/widgets/weekly_load_mode_selector.dart';
import '../../../timetable/presentation/providers/timetable_provider.dart';
import '../providers/management_provider.dart';
import '../providers/subject_constraint_auto_sync_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final configAsync = ref.watch(appConfigNotifierProvider);

    return Scaffold(
      body: settingsAsync.when(
        data: (settings) => configAsync.when(
          data: (config) => _SettingsForm(
            settings: settings,
            initialConfig: config,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('حدث خطأ: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('حدث خطأ: $e')),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  final AppSettings settings;
  final AppConfig initialConfig;

  const _SettingsForm({
    required this.settings,
    required this.initialConfig,
  });

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
  late String _schoolName;
  late String _principalName;
  late SchoolStage _schoolStage;
  late WeeklyLoadMode _weeklyLoadMode;
  late OfficialWeeklyPlan _officialWeeklyPlan;
  final Map<String, TextEditingController> _officialPlanControllers = {};
  bool _isSaving = false;
  double? _customPageWidth;
  double? _customPageHeight;

  @override
  void initState() {
    super.initState();
    _periodsPerDay = widget.settings.periodsPerDay;
    _daysPerWeek = widget.settings.daysPerWeek;
    _exportPageSize = widget.settings.exportPageSize;
    _exportOrientation = widget.settings.exportOrientation;
    _exportAutoScale = widget.settings.exportAutoScale;
    _schoolName = widget.settings.schoolName;
    _principalName = widget.settings.principalName;
    _schoolStage = widget.initialConfig.schoolStage;
    _weeklyLoadMode = widget.initialConfig.weeklyLoadMode;
    _officialWeeklyPlan = widget.initialConfig.officialWeeklyPlan;
    _customPageWidth = widget.settings.customPageWidth;
    _customPageHeight = widget.settings.customPageHeight;
    _initOfficialPlanControllers();
  }

  void _initOfficialPlanControllers() {
    for (final track in OfficialPlanTrack.values) {
      for (final grade in track.grades) {
        final key = _planEntryKey(track, grade);
        final lessons = _officialWeeklyPlan.lessonsFor(track, grade);
        _officialPlanControllers[key] =
            TextEditingController(text: lessons.toString());
      }
    }
  }

  String _planEntryKey(OfficialPlanTrack track, AcademicGrade grade) {
    return '${track.storageKey}:${grade.storageKey}';
  }

  void _resetOfficialPlanToDefaults() {
    const defaults = OfficialWeeklyPlan.standard();
    setState(() {
      _officialWeeklyPlan = defaults;
      for (final track in OfficialPlanTrack.values) {
        for (final grade in track.grades) {
          final key = _planEntryKey(track, grade);
          _officialPlanControllers[key]?.text =
              defaults.lessonsFor(track, grade).toString();
        }
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _officialPlanControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    var updatedOfficialPlan = _officialWeeklyPlan;
    for (final track in OfficialPlanTrack.values) {
      for (final grade in track.grades) {
        final key = _planEntryKey(track, grade);
        final raw = _officialPlanControllers[key]?.text.trim() ?? '';
        final parsed = int.tryParse(raw);
        if (parsed != null && parsed > 0) {
          updatedOfficialPlan = updatedOfficialPlan.copyWithEntry(
            track: track,
            grade: grade,
            weeklyLessons: parsed,
          );
        }
      }
    }
    _officialWeeklyPlan = updatedOfficialPlan;

    final newSettings = widget.settings
      ..schoolName = _schoolName
      ..principalName = _principalName
      ..periodsPerDay = _periodsPerDay
      ..daysPerWeek = _daysPerWeek
      ..exportPageSize = _exportPageSize
      ..exportOrientation = _exportOrientation
      ..exportAutoScale = _exportAutoScale
      ..customPageWidth = _customPageWidth
      ..customPageHeight = _customPageHeight;

    setState(() => _isSaving = true);

    try {
      await ref
          .read(settingsNotifierProvider.notifier)
          .saveSettings(newSettings);

      await ref.read(appConfigNotifierProvider.notifier).completeSetup(
            stage: _schoolStage,
            weeklyLoadMode: _weeklyLoadMode,
            officialWeeklyPlan: _officialWeeklyPlan,
          );

      final outcome = await ref.read(subjectConstraintAutoSyncProvider).run();

      if (!mounted) {
        return;
      }

      setState(() => _isSaving = false);
      final summary = outcome?.arabicSummary;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            summary == null
                ? 'تم حفظ الإعدادات بنجاح'
                : 'تم حفظ الإعدادات بنجاح، $summary',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ الإعدادات: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openSetupWizard() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const FirstRunSetupPage(isEditing: true),
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      final backupService = await ref.read(appBackupServiceProvider.future);
      final jsonStr = await backupService.exportToJson();

      final jsonBytes =
          Uint8List.fromList(const Utf8Encoder().convert(jsonStr));

      if (Platform.isWindows) {
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'حفظ النسخة الاحتياطية',
          fileName: 'jadwal_backup.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: jsonBytes,
          lockParentWindow: true,
        );

        if (mounted && savedPath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ النسخة الاحتياطية بنجاح')),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File(path.join(tempDir.path, 'jadwal_backup.json'));
      await file.writeAsBytes(jsonBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم تحضير البيانات، جاري فتح المشاركة...')),
        );
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'نسخة احتياطية لبيانات التطبيق',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في التصدير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final jsonStr = await file.readAsString();

        final backupService = await ref.read(appBackupServiceProvider.future);
        await backupService.importFromJson(jsonStr);

        if (mounted) {
          ref.invalidate(teachersNotifierProvider);
          ref.invalidate(subjectsNotifierProvider);
          ref.invalidate(classroomsNotifierProvider);
          ref.invalidate(settingsNotifierProvider);
          ref.invalidate(timetableNotifierProvider);
          // ملف الإعدادات (المرحلة وسجلّ القيود التلقائية) يُقرأ من القرص
          // من جديد بعد الاستيراد حتى تعكس الواجهة حالة النسخة المستوردة.
          ref.invalidate(appConfigNotifierProvider);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم استيراد البيانات بنجاح')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في الاستيراد: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchSocialMediaUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يمكن فتح الرابط: $urlString')),
        );
      }
    }
  }

  void _showDeveloperDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Center(
            child: Text(
              'حول مطور التطبيق',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'كنان الصائغ',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kinan Al-Sayegh',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'التطبيق حالياً مجاني',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'نسخة تجريبية',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12.0,
                runSpacing: 12.0,
                children: [
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.telegram,
                        color: Color(0xFF0088cc)),
                    onPressed: () =>
                        _launchSocialMediaUrl('https://t.me/techtouch7'),
                  ),
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.tiktok,
                        color: Colors.black),
                    onPressed: () => _launchSocialMediaUrl(
                        'https://www.tiktok.com/@techtouch6?_r=1&_t=ZT-97ououQ8tkk'),
                  ),
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.youtube,
                        color: Color(0xFFFF0000)),
                    onPressed: () => _launchSocialMediaUrl(
                        'https://youtube.com/@kinanmajeed?si=I2yuzJT2rRnEHLVg'),
                  ),
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.facebook,
                        color: Color(0xFF1877F2)),
                    onPressed: () => _launchSocialMediaUrl(
                        'https://www.facebook.com/share/1EsapVHA6W/'),
                  ),
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.instagram,
                        color: Color(0xFFE1306C)),
                    onPressed: () => _launchSocialMediaUrl(
                        'https://www.instagram.com/techtouch0'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOfficialPlanSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'الخطة الدراسية الرسمية',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: _resetOfficialPlanToDefaults,
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('استعادة الافتراضي'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'هذه القيم هي القيم الافتراضية ويمكن تعديلها حسب احتياج مدرستك. تعديلها لا يغير الصفوف التي لديها تخصيص مستقل.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 12),
            for (final track in OfficialPlanTrack.values) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  track.label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final grade in track.grades)
                    SizedBox(
                      width: 125,
                      child: TextFormField(
                        controller:
                            _officialPlanControllers[_planEntryKey(track, grade)],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: grade.label,
                          suffixText: 'حصة',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (val) {
                          final parsed = int.tryParse(val?.trim() ?? '');
                          if (parsed == null || parsed < 1 || parsed > 84) {
                            return 'رقم غير صالح';
                          }
                          return null;
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
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
            const Text('الإعدادات العامة',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _schoolName,
                      decoration: const InputDecoration(
                          labelText: 'اسم المدرسة',
                          border: OutlineInputBorder()),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'مطلوب' : null,
                      onSaved: (val) => _schoolName = val?.trim() ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _principalName,
                      decoration: const InputDecoration(
                          labelText: 'اسم المدير',
                          border: OutlineInputBorder()),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'مطلوب' : null,
                      onSaved: (val) => _principalName = val?.trim() ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _periodsPerDay.toString(),
                      decoration: const InputDecoration(
                          labelText: 'عدد الدروس في اليوم',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (val) =>
                          val == null || int.tryParse(val) == null
                              ? 'أدخل رقماً صحيحاً'
                              : null,
                      onSaved: (val) => _periodsPerDay = int.parse(val!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _daysPerWeek.toString(),
                      decoration: const InputDecoration(
                          labelText: 'عدد أيام الدوام في الأسبوع',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (val) =>
                          val == null || int.tryParse(val) == null
                              ? 'أدخل رقماً صحيحاً'
                              : null,
                      onSaved: (val) => _daysPerWeek = int.parse(val!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('المرحلة الدراسية',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SchoolStageSelector(
                      value: _schoolStage,
                      onChanged: (stage) =>
                          setState(() => _schoolStage = stage),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _schoolStage.description,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('إعداد الحصص الأسبوعية',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'اختر الطريقة الأساسية التي تريد استخدامها لتحديد عدد الحصص للصفوف.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    WeeklyLoadModeSelector(
                      value: _weeklyLoadMode,
                      onChanged: (mode) =>
                          setState(() => _weeklyLoadMode = mode),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يمكنك تعديل هذه الإعدادات لاحقًا من الإعدادات أو من تفاصيل الصف. هذا التخصيص اختياري.',
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildOfficialPlanSection(),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.assignment_outlined,
                    color: Colors.teal),
                title: const Text('معالج الإعداد الأولي'),
                subtitle: const Text(
                    'مراجعة بيانات المدرسة والمدير والحصص والمرحلة'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _openSetupWizard,
              ),
            ),
            const SizedBox(height: 24),
            const Text('إعدادات التصدير (PDF)',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _exportPageSize,
                      decoration: const InputDecoration(
                          labelText: 'حجم الصفحة',
                          border: OutlineInputBorder()),
                      items: ['A4', 'A3', 'Custom'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) =>
                          setState(() => _exportPageSize = newValue!),
                      onSaved: (val) => _exportPageSize = val!,
                    ),
                    if (_exportPageSize == 'Custom') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _customPageWidth?.toString() ?? '',
                              decoration: const InputDecoration(
                                  labelText: 'عرض الصفحة (cm)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              onSaved: (val) =>
                                  _customPageWidth = double.tryParse(val ?? ''),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              initialValue: _customPageHeight?.toString() ?? '',
                              decoration: const InputDecoration(
                                  labelText: 'طول الصفحة (cm)',
                                  border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              onSaved: (val) => _customPageHeight =
                                  double.tryParse(val ?? ''),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _exportOrientation,
                      decoration: const InputDecoration(
                          labelText: 'اتجاه الصفحة',
                          border: OutlineInputBorder()),
                      items: ['Portrait', 'Landscape'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) =>
                          setState(() => _exportOrientation = newValue!),
                      onSaved: (val) => _exportOrientation = val!,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('التمدد التلقائي للجدول'),
                      value: _exportAutoScale,
                      onChanged: (val) =>
                          setState(() => _exportAutoScale = val ?? true),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('نظام النسخ الاحتياطي',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
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
            const SizedBox(height: 24),
            const Text('مطور التطبيق',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.code, color: Colors.teal),
                title: const Text('حول مطور التطبيق'),
                subtitle: const Text('تواصل معنا، حقوق المطور، الإصدار'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showDeveloperDialog(context),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style:
                    ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ الإعدادات',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
