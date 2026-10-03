import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_config_provider.dart';
import '../../../setup/presentation/pages/first_run_setup_page.dart';
import 'home_shell.dart';

/// واجهة الإقلاع الموحّدة لكل المنصات (أندرويد، ويندوز ٧، ويندوز ١٠ و١١).
///
/// تقرأ حالة الإعداد الأولي وتقرر ما يُعرض:
/// * [AppSetupStatus.needsSetup]: معالج الإعداد الإلزامي (لا يمكن تجاوزه).
/// * [AppSetupStatus.legacyDataDetected]: مستخدم لديه بيانات سابقة، فيُعتمد
///   الإعداد تلقائيًا بمرحلة محايدة ثم يمكنه تغييرها من الإعدادات.
/// * [AppSetupStatus.completed]: الهيكل الرئيسي للتطبيق.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupStatusAsync = ref.watch(appSetupStatusProvider);

    return setupStatusAsync.when(
      loading: () => const _StartupSplash(),
      error: (error, _) => _StartupErrorView(
        error: error,
        onRetry: () {
          ref.invalidate(appConfigNotifierProvider);
          ref.invalidate(appSetupStatusProvider);
        },
      ),
      data: (status) => switch (status) {
        AppSetupStatus.completed => const HomeShell(),
        AppSetupStatus.needsSetup => const FirstRunSetupPage(),
        AppSetupStatus.legacyDataDetected => const _LegacyAdoptionView(),
      },
    );
  }
}

/// شاشة انتظار قصيرة أثناء تهيئة قاعدة البيانات وقراءة الإعدادات.
class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جارٍ تحضير التطبيق...'),
          ],
        ),
      ),
    );
  }
}

/// شاشة فشل الإقلاع مع إمكانية إعادة المحاولة.
class _StartupErrorView extends StatelessWidget {
  const _StartupErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 44),
              const SizedBox(height: 12),
              const Text(
                'تعذر تشغيل التطبيق',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// يعتمد إعدادًا صامتًا لمستخدم قائم (ترقية من نسخة سابقة) دون مقاطعته،
/// لأن بياناته موجودة أصلًا ولا يصح إجباره على معالج الإعداد الأولي.
class _LegacyAdoptionView extends ConsumerStatefulWidget {
  const _LegacyAdoptionView();

  @override
  ConsumerState<_LegacyAdoptionView> createState() =>
      _LegacyAdoptionViewState();
}

class _LegacyAdoptionViewState extends ConsumerState<_LegacyAdoptionView> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _adopt());
  }

  Future<void> _adopt() async {
    setState(() => _error = null);
    try {
      await ref.read(appConfigNotifierProvider.notifier).adoptLegacySetup();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error == null) {
      return const _StartupSplash();
    }

    return _StartupErrorView(error: error, onRetry: _adopt);
  }
}
