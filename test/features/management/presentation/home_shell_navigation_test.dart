import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/providers/app_config_provider.dart';
import 'package:jadwal_v2/features/management/presentation/pages/home_shell.dart';

void main() {
  testWidgets(
    'إعادة تحميل حالة الإعداد لا تستبدل الهيكل المكتمل بشاشة الانتظار',
    (tester) async {
      final reloading = const AsyncLoading<AppSetupStatus>().copyWithPrevious(
        const AsyncData(AppSetupStatus.completed),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: reloading.when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => const Text('splash'),
            error: (_, __) => const Text('error'),
            data: (_) => const Text('shell'),
          ),
        ),
      );

      expect(find.text('shell'), findsOneWidget);
      expect(find.text('splash'), findsNothing);
    },
  );

  test('فهرس تبويب الهيكل يبقى في المزوّد بعد إعادة إنشاء الحاوية الفرعية', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(homeShellTabIndexProvider), HomeShellTabs.timetable);
    container.read(homeShellTabIndexProvider.notifier).state =
        HomeShellTabs.management;
    expect(container.read(homeShellTabIndexProvider), HomeShellTabs.management);
  });
}
