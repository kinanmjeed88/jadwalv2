import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/features/management/presentation/pages/home_shell.dart';

void main() {
  test('فهرس تبويب الهيكل يبقى بعد إعادة التعيين ولا يعود للجدول تلقائيًا', () {
    homeShellTabIndex = HomeShellTabs.timetable;
    homeShellTabIndex = HomeShellTabs.management;
    expect(homeShellTabIndex, HomeShellTabs.management);
    homeShellTabIndex = HomeShellTabs.timetable;
  });
}
