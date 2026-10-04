<div dir="rtl">

# تقرير نقل ميزة «الحِمل الأسبوعي» إلى الأهداف الثلاثة

* تاريخ التنفيذ: 2026-10-04
* فرع الجلسة: `arena/01a106af-jadwalv2`
* مصدر التغييرات: `arena/01a10437-jadwalv2` عند الالتزام `b522ff0fe40a03a804146ded4bff3e9b5374afcc`
* الملف المرفق `patch.diff` (فرق ملف واحد): تم فحصه ومقارنته، وهو **مُطبَّق أصلًا** في
  جميع الفروع الأربعة (انظر «ملاحظة الملف المرفق» أدناه)، لذلك اعتُمد فرق الميزة
  الفعلي `b362b5c..b522ff0` (40 ملفًا) كمادة النقل بعد التحقق من مطابقته حرفيًا
  لمحتوى PR #132.

## الجدول النهائي

| Target | Port | Analyze | Tests | Release | Smoke | Isar | Weekday | Commit | PR | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| main (Android) | PASS (مُقدّم في PR #132) | PASS | PASS 101/0/0 | PASS (APK موقّع 31.6MB) | N/A (Windows build PASS) | PASS | PASS | `b522ff0` (head) | [#132](https://github.com/kinanmjeed88/jadwalv2/pull/132) | VERIFIED |
| Windows 7 | PASS (رقعة 40 ملفًا، تطبيق نظيف) | PASS (Flutter 3.16.9) | PASS 111/0/0 | PASS | PASS | PASS | PASS | رقعة `757ab42…` (لم يُدفع — قيد الجلسة) | — (BLOCKED) | PORTED + VERIFIED |
| Windows 10/11 | PASS (رقعة 40 ملفًا، تطبيق نظيف) | PASS (stable) | PASS 111/0/0 | PASS | PASS | PASS | PASS | رقعة `3cfd958…` (لم يُدفع — قيد الجلسة) | — (BLOCKED) | PORTED + VERIFIED |

أعداد الاختبارات الفعلية المقيسة (لا منقولة عن المصدر):

* main: `Passed = 101, Failed = 0, Skipped = 0`
* Windows 7: `Passed = 111, Failed = 0, Skipped = 0`
* Windows 10/11: `Passed = 111, Failed = 0, Skipped = 0`

حالة الإنهاء: **PORTING PARTIAL** — النقل والتحقق نجحا للأهداف الثلاثة، لكن
دفع الفروع الرسمية لفرعي ويندوز وفتح PR مباشر إليهما متعذّر داخل هذه الجلسة
(سياسة الفرع تسمح بالدفع إلى `arena/01a106af-jadwalv2` فقط)، فسُلِّمت رقعتا
النقل موثّقتين ومُختبَرتين على CI جاهزتين للتطبيق بأمر واحد.

## تفصيل كل هدف

### 1) main — Android

* base: `b362b5cd429a201f1f50b62763808de8647df53e`
* نتيجة: فرق الميزة `b362b5c..b522ff0` = 40 ملفًا (+3847/−153)، وهو مطابق
  حرفيًا لقائمة ملفات PR #132 والتزاماته، لذا لم تُنشأ تغييرات مكررة.
* `flutter analyze --no-fatal-infos`: PASS (run 37199771331 و37197431759).
* `flutter test --machine`: PASS 101/0/0 (run 37199771331 و37197431759).
* Android Release APK: PASS في run 37197431755 (المرحلة «Build Android Release»
  ثم «Upload APK»)، والمُخرَج `release-apk` بحجم 33,127,434 بايت (موقّع).
* لم يلمس فرق الميزة أي ملف من `android/` أو `pubspec.yaml` أو `pubspec.lock`
  أو `windows/`: Application ID (`com.jadwal.jadwal_v2`)، وsigning، وversion
  (`1.0.0+1`)، وإعدادات Gradle كلها كما هي.
* Windows Release + Smoke للشجرة نفسها (من CI الخاص بـPR #132): PASS
  (run 37197431759، المراحل Build/Verify/Smoke/Installer).

### 2) Windows 7 — `برنامج-مخصص-لوندوز-٧`

* base: `b9b62154be64cb1b9cb5c6cf3063b57881aaa17d` (شجرة base `506f966a…`)
* الرقعة: `ports/port-windows7-weekly-load.patch`
  (sha256 `757ab42cf81c2836b11767affb1ee4135755efcc366701d9c6089bfa5f8e2791`،
  40 ملفًا، شجرة نتيجة التطبيق `1f12560a…`) وتُطبَّق بـ`git apply` نظيفة.
* Flutter المستخدم في التحقق: **3.16.9** كما في workflow الفرع (Dart 3.2).
* Analyze: PASS — Tests: PASS 111/0/0 — Windows Release (الهدف
  `lib/main_windows.dart`): PASS — bundle (`JadwalV2_Windows7.exe` + `data`):
  PASS — Smoke (`windows/packaging/smoke_test.ps1`): PASS (run 37199771331).

### 3) Windows 10/11 — `برنامج-مخصص-لوندوز-١٠-و-١١`

* base: `6b253a397b64a6260b96d9d9e608b8e2dd5ec6c6` (شجرة base `db2d05a6…`)
* الرقعة: `ports/port-windows10-11-weekly-load.patch`
  (sha256 `3cfd95828fa5eeec39cdeea992871f188e926e56c0be46b1a6ee440e6e2187ff`،
  40 ملفًا، شجرة نتيجة التطبيق `650f7d9b…`).
* Flutter: قناة stable كما في workflow الفرع.
* Analyze: PASS — Tests: PASS 111/0/0 — Windows Release: PASS — bundle
  (`JadwalV2_Windows10_11.exe` + `data`): PASS — Smoke: PASS (run 37199771331).

## التعارضات وكيف حُلّت

* نقطة التعارض الوحيدة في الفرعين: قائمة مشغّلات
  `.github/workflows/build_windows.yml` (أرادت الميزة `arena/**` والفرعان
  يملكان أسماء فرعيهما). الحل: **الإبقاء على مشغّلات الفرع وإضافة `arena/**`**،
  مع الإبقاء على إصدار Flutter المثبّت في فرع ويندوز ٧ (3.16.9)، وعلى اسم
  المنفذ التنفيذي الخاص بكل فرع، وعلى استبعاد `backup_service_benchmark_test.dart`
  من تشغيل الاختبارات. ونُقل من الميزة تقرير أعداد الاختبارات
  (`flutter test --machine` + عدد Passed/Failed/Skipped) لأن ذلك مطلوب للتحقق.
* بقية الملفات طُبِّقت بدمج ثلاثي نظيف، بما فيها `settings_page.dart` و
  `timetable_page.dart` حيث دُمج واجه الميزة مع كود المنصة (FileSaveService)
  دون فقدان أي سلوك خاص بالويندوز.

## ملفات بقيت platform-specific (لم تُستبدل من المصدر)

`lib/features/management/presentation/pages/settings_page.dart`،
`lib/features/timetable/presentation/pages/timetable_page.dart`،
`.github/workflows/build.yml`، `.github/workflows/build_windows.yml`،
`lib/main_windows.dart`، `lib/app/app_bootstrap.dart`، `lib/app/jadwal_app.dart`،
`lib/app/jadwal_windows_app.dart`، `lib/core/services/file_save_service.dart`،
`pubspec.yaml`/`pubspec.lock` (فرع ويندوز ٧)، `windows/**`، `tools/**`،
`WINDOWS*.md`.

## Isar

* الحقول الجديدة هي `weeklyLessonsOverride` (long) و`dailyPeriodsOverride`
  (longList) داخل `Classroom` فقط، مع إعادة توليد `classroom.g.dart` بنفس
  Collection ID (`-8186663030834931469`) وبدون تغيير `schema identifier`،
  وبدون حقول أو migrations إضافية.
* اختبار الترحيل الحقيقي `test/core/models/weekly_load_migration_test.dart`
  (يفتح قاعدة Isar بالبنية القديمة ثم يعيد فتحها بالبنية الجديدة ويعدّلها ثم
  يعيد الفتح) موجود في الأهداف الثلاثة ونجح ضمن المجموعة (ضمن 101/111).

## Weekday

* الخريطة الموحّدة `0=الأحد … 5=الجمعة, 6=السبت` معرّفة مرة واحدة في
  `Weekday` (weekly_load_policy.dart)، ويستهلكها الجدولان وPDF وExcel عبر
  `timetableDayLabels`، وتوافر المعلمين عبر `Weekday.workingDays`، وسياسة
  الحِمل والتوزيع اليومي وتخصيص الصفوف عبر نفس الـenum.
* اختبارا الانحدار `test/core/models/weekday_mapping_regression_test.dart`
  و`test/features/timetable/domain/usecases/weekday_excel_export_test.dart`
  منقولان ويعملان في الأهداف الثلاثة (ضمن المجموعات الناجحة).

## ملاحظة الملف المرفق `patch.diff`

الملف المرفق يقع في جذر المستودع، وهو فرق **ملف واحد** فقط
(`lib/features/timetable/presentation/providers/timetable_provider.dart`،
+32/−19) يغلّف تمرير بيانات التوليد في `GenerationPayload`. عند فحصه:

* `git apply --check patch.diff` **يفشل** على `main`: نصّ «ما قبل» لم يعد موجودًا.
* النصّ «بعد» (بما فيه `class GenerationPayload` و`_generateInIsolate(payload)`)
  **موجود فعلًا** في `main` و`b522ff0` وفي فرعي ويندوز (997 سطرًا في كل فرع).
* الملف لم يتغيّر منذ التزام الاستيراد الأول في المستودع.

لذلك هو ملف تاريخي مُطبَّق، وليس مادة نقل الميزة؛ ومادة النقل هي فرق الميزة
الكامل (40 ملفًا) الذي وُصف بدقة في الطلب، وقد نُقل واختُبر كما في هذا التقرير.

## ما تبقّى لإنهاء التسليم (أمر واحد لكل فرع)

```bash
git checkout برنامج-مخصص-لوندوز-٧
git apply ports/port-windows7-weekly-load.patch
git add -A
git commit -m "feat(weekly-load): سياسة الحِمل الأسبوعي والتوزيع اليومي للصفوف"
git push origin برنامج-مخصص-لوندوز-٧
```

وكذلك للفرع الآخر بالرقعة المقابلة. وبعد الدفع سيعمل
`.github/workflows/build_windows.yml` الخاص بالفرع تلقائيًا (بما فيه Analyze و
Tests وWindows Release وSmoke) لأن الرقعة تضيف `arena/**` إلى مشغّلاته.

> تنبيه: رقعتا `ports/windows-7-feature.patch` و`ports/windows-10-11-feature.patch`
> القديمتان أصبحتا **مُطبَّقتين أصلًا** على الفرعين (تُفشل `git apply --check`
> برسائل «already exists»)، فهما تاريخيتان ولا تُعادا.

</div>
