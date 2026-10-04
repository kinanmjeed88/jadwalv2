import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/school_stage.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/models/weekly_load_policy.dart';
import '../../../../core/providers/app_config_provider.dart';
import '../../../management/presentation/providers/management_provider.dart';
import '../../../management/presentation/providers/subject_constraint_auto_sync_provider.dart';
import '../../domain/setup_validation.dart';
import '../widgets/school_stage_selector.dart';
import '../widgets/weekly_load_mode_selector.dart';

/// شاشة الإعداد الأولي الإلزامية.
///
/// تُعرض كواجهة إقلاع للتطبيق عند أول تشغيل، فلا يمكن استخدام التطبيق قبل
/// إدخال: اسم المدرسة، اسم المدير، عدد الدروس في اليوم، عدد أيام الأسبوع،
/// المرحلة الدراسية، وطريقة تحديد الحصص الأسبوعية.
///
/// عند اختيار المرحلة الابتدائية تُشغَّل سياسة تخطي قيود المواد تلقائيًا
/// (انظر `PrimaryStageConstraintPolicy`).
///
/// يمكن استخدام الشاشة نفسها من صفحة الإعدادات بوضع التعديل
/// ([isEditing] = true) لمراجعة البيانات لاحقًا.
class FirstRunSetupPage extends ConsumerStatefulWidget {
  const FirstRunSetupPage({super.key, this.isEditing = false});

  /// وضع التعديل: يُسمح بالرجوع وتُعرض الشاشة بوصفها صفحة عادية.
  final bool isEditing;

  @override
  ConsumerState<FirstRunSetupPage> createState() => _FirstRunSetupPageState();
}

class _FirstRunSetupPageState extends ConsumerState<FirstRunSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _schoolNameController = TextEditingController();
  final _principalNameController = TextEditingController();
  final _periodsPerDayController = TextEditingController(text: '7');
  final _daysPerWeekController = TextEditingController(text: '5');

  SchoolStage? _selectedStage;
  WeeklyLoadMode _selectedWeeklyLoadMode = WeeklyLoadMode.fallback;
  ProviderSubscription<AsyncValue<AppSettings>>? _settingsSubscription;
  bool _isPreparing = true;
  bool _isSaving = false;
  bool _showStageError = false;
  String? _preparationError;

  @override
  void initState() {
    super.initState();
    _settingsSubscription =
        ref.listenManual(settingsNotifierProvider, (_, __) {});
    _prepareForm();
  }

  @override
  void dispose() {
    _settingsSubscription?.close();
    _schoolNameController.dispose();
    _principalNameController.dispose();
    _periodsPerDayController.dispose();
    _daysPerWeekController.dispose();
    super.dispose();
  }

  /// يجلب الإعدادات الحالية ليعبّئ الحقول بالبيانات الموجودة مسبقًا.
  Future<void> _prepareForm() async {
    setState(() {
      _isPreparing = true;
      _preparationError = null;
    });

    try {
      final settings = await ref.read(settingsNotifierProvider.future);
      final config = await ref.read(appConfigNotifierProvider.future);
      if (!mounted) {
        return;
      }

      setState(() {
        _schoolNameController.text = settings.schoolName;
        _principalNameController.text = settings.principalName;
        _periodsPerDayController.text = settings.periodsPerDay.toString();
        _daysPerWeekController.text = settings.daysPerWeek.toString();
        _selectedStage = config.isSetupCompleted ? config.schoolStage : null;
        _selectedWeeklyLoadMode = config.weeklyLoadMode;
        _isPreparing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparing = false;
        _preparationError = 'تعذر تحميل الإعدادات الحالية: $error';
      });
    }
  }

  Future<void> _submit() async {
    final formIsValid = _formKey.currentState?.validate() ?? false;
    final stage = _selectedStage;

    if (stage == null) {
      setState(() => _showStageError = true);
    }
    if (!formIsValid || stage == null) {
      return;
    }

    // يُلتقط مُشغّل الرسائل قبل العمليات غير المتزامنة، لأن الشاشة تختفي فور
    // إتمام الإعداد الأولي (تتحول واجهة الإقلاع إلى الهيكل الرئيسي).
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSaving = true;
      _showStageError = false;
    });

    try {
      final existingSettings =
          await ref.read(settingsNotifierProvider.future);
      final updatedSettings = existingSettings
        ..schoolName = _schoolNameController.text.trim()
        ..principalName = _principalNameController.text.trim()
        ..periodsPerDay = int.parse(_periodsPerDayController.text.trim())
        ..daysPerWeek = int.parse(_daysPerWeekController.text.trim());

      await ref
          .read(settingsNotifierProvider.notifier)
          .saveSettings(updatedSettings);

      await ref.read(appConfigNotifierProvider.notifier).completeSetup(
            stage: stage,
            weeklyLoadMode: _selectedWeeklyLoadMode,
          );

      // تُنشأ قيود المواد التلقائية للمرحلة الابتدائية بعد حفظ المرحلة.
      final outcome =
          await ref.read(subjectConstraintAutoSyncProvider).run();

      final summary = outcome?.arabicSummary;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            summary == null
                ? 'تم حفظ الإعدادات بنجاح'
                : 'تم حفظ الإعدادات بنجاح، $summary',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() => _isSaving = false);

      if (widget.isEditing && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ الإعدادات: $error'),
          backgroundColor: Colors.red,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // إبقاء المزوّدات نشطة طوال عمر الشاشة لمنع التخلص التلقائي أثناء التحميل أو الحفظ.
    ref.watch(settingsNotifierProvider);
    ref.watch(appConfigNotifierProvider);

    return PopScope(
      // في وضع الإقلاع لا يُسمح بالخروج من الشاشة قبل إكمال البيانات.
      canPop: widget.isEditing,
      child: Scaffold(
        appBar: widget.isEditing
            ? AppBar(title: const Text('معالج الإعداد الأولي'))
            : null,
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isPreparing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('جارٍ تحضير الإعدادات...'),
          ],
        ),
      );
    }

    if (_preparationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(
                _preparationError!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _prepareForm,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                const SizedBox(height: 20),
                _buildBasicDataCard(),
                const SizedBox(height: 20),
                _buildStageCard(),
                if (_selectedStage == SchoolStage.primary) ...[
                  const SizedBox(height: 16),
                  _buildPrimaryPolicyNotice(),
                ],
                const SizedBox(height: 20),
                _buildWeeklyLoadCard(),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.isEditing
                              ? 'حفظ الإعدادات'
                              : 'حفظ وبدء الاستخدام',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isEditing
                      ? 'تعديل المرحلة يعيد ضبط قيود المواد التلقائية وفق السياسة الجديدة.'
                      : 'لا يمكن استخدام التطبيق قبل إكمال هذه البيانات.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.school_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          widget.isEditing ? 'بيانات المدرسة والمرحلة' : 'إعداد التطبيق لأول مرة',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'أدخل البيانات الأساسية للمدرسة وحدّد المرحلة الدراسية، '
          'لتبدأ بإسناد الدروس وتوليد الجدول الأسبوعي.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildBasicDataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _schoolNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم المدرسة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.apartment),
              ),
              validator: (value) => SetupValidation.requiredText(
                value,
                fieldLabel: 'اسم المدرسة',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _principalNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم المدير',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) => SetupValidation.requiredText(
                value,
                fieldLabel: 'اسم المدير',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _periodsPerDayController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'عدد الدروس في اليوم',
                      border: OutlineInputBorder(),
                    ),
                    validator: SetupValidation.periodsPerDay,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _daysPerWeekController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'عدد أيام الأسبوع',
                      border: OutlineInputBorder(),
                    ),
                    validator: SetupValidation.daysPerWeek,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المرحلة الدراسية',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SchoolStageSelector(
              value: _selectedStage,
              onChanged: (stage) {
                setState(() {
                  _selectedStage = stage;
                  _showStageError = false;
                });
              },
            ),
            if (_showStageError && _selectedStage == null) ...[
              const SizedBox(height: 8),
              Text(
                SetupValidation.schoolStage(_selectedStage) ?? '',
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ],
            if (_selectedStage != null) ...[
              const SizedBox(height: 12),
              Text(
                _selectedStage!.description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyLoadCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إعداد الحصص الأسبوعية',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'اختر الطريقة الأساسية التي تريد استخدامها لتحديد عدد الحصص للصفوف.',
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
            WeeklyLoadModeSelector(
              value: _selectedWeeklyLoadMode,
              onChanged: (mode) {
                setState(() {
                  _selectedWeeklyLoadMode = mode;
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              'يمكنك تعديل هذه الإعدادات لاحقًا من الإعدادات أو من تفاصيل الصف. هذا التخصيص اختياري.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryPolicyNotice() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.teal.shade800),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'سياسة تخطي قيود المواد للمرحلة الابتدائية',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'يُنشئ التطبيق تلقائيًا قيدًا لأي مادة يتجاوز نصابها الأسبوعي '
            '٦ حصص (اللغة العربية والرياضيات غالبًا)، بحيث يُسمح بتكرار '
            'حصتين في اليوم للشعبة الواحدة بدل حصة واحدة. '
            'تُضاف هذه القيود إلى صفحة «قيود المواد» ويمكنك تعديل قيمتها '
            'أو حذفه في أي وقت، ولا تُعاد إن حذفتها.',
            style: TextStyle(fontSize: 13, color: Colors.teal.shade900),
          ),
        ],
      ),
    );
  }
}
