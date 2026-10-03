import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/features/management/presentation/pages/home_shell.dart';

void main() {
  test('فهرس تبويب الهيكل يبقى في المزوّد ولا يعود للجدول تلقائيًا', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(homeShellTabIndexProvider), HomeShellTabs.timetable);
    container.read(homeShellTabIndexProvider.notifier).state =
        HomeShellTabs.management;
    expect(container.read(homeShellTabIndexProvider), HomeShellTabs.management);
  });
}
