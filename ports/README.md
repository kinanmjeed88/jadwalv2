<div dir="rtl">

# رقع جاهزة لفرعي ويندوز

## لماذا رقعة (patch) بدل Pull Request؟

فرعا **`برنامج-مخصص-لوندوز-٧`** و**`برنامج-مخصص-لوندوز-١٠-و-١١`** لهما تاريخ
Git مستقل تمامًا عن `main` (لا يوجد سلف مشترك بينهما، فجذر `main` التزام واحد
مُنشأ كفرع منفصل بينما جذر فرعي ويندوز هو `461f308`). لذلك:

* دمج فرع الجلسة `arena/01a1032a-jadwalv2` في فرعي ويندوز عبر Pull Request
  يُظهر الفرق بين الشجرتين كاملًا، ويقترح إلغاء كل تعديلات ويندوز الخاصة
  (الأيقونة، حزم التثبيت، `main_windows.dart`، تعديلات `pubspec` … إلخ).
* الحل الآمن هو رقعة تحتوي **تعديلات الميزة فقط** ومبنية مباشرة على قمة كل فرع،
  وقد جُرّبت بـ `git apply --check` فتطبّق نظيفة دون أي تعارض.

## طريقة التطبيق

```bash
git checkout برنامج-مخصص-لوندوز-٧
git apply ports/windows-7-feature.patch
git add -A
git commit -m "feat: الإعداد الأولي الإلزامي وسياسة قيود المواد للمرحلة الابتدائية"
git push origin برنامج-مخصص-لوندوز-٧
```

ولفرع ويندوز ١٠ و١١:

```bash
git checkout برنامج-مخصص-لوندوز-١٠-و-١١
git apply ports/windows-10-11-feature.patch
git add -A
git commit -m "feat: الإعداد الأولي الإلزامي وسياسة قيود المواد للمرحلة الابتدائية"
git push origin برنامج-مخصص-لوندوز-١٠-و-١١
```

## ما الذي تحتويه الرقعة؟

نفس ملفات الميزة الموجودة في فرع `main` (انظر `FIRST_RUN_SETUP.md`):

* ملفات جديدة: طبقة `AppConfig`، معالج الإعداد الأولي، سياسة المرحلة
  الابتدائية، خدمة المزامنة، ومتحكّم المزامنة، وطبقة النسخ الاحتياطي الموحّدة
  (`app_backup_service.dart` + `app_backup_provider.dart`)، والاختبارات،
  والتوثيق (`FIRST_RUN_SETUP.md` و`CHANGELOG.md` وتحديث `plan.md`).
* تعديلات: `home_page.dart` (واجهة الإقلاع)، `settings_page.dart`
  (المرحلة + معالج الإعداد + النسخ الاحتياطي الموحّد)، `backup_service.dart`
  (المدرسة/المدير وقيود المواد)، `subject_constraints_page.dart` (شارة «تلقائي»
  وتسجيل قرارات المستخدم).

> نقطة التعارض الوحيدة أثناء البناء هي كتلة الاستيرادات في `settings_page.dart`:
> فرعا ويندوز يحتاجان `core/services/file_save_service.dart`، والميزة تحتاج
> `app_backup_provider.dart` و`app_config_provider.dart` وملفات معالج الإعداد،
> مع إسقاط استيراد `repository_provider.dart` الذي لم تبقَ له استخدامات في
> الملف بعد تمرير النسخ الاحتياطي عبر الخدمة الموحّدة.

الرقعة لا تتضمن أي ملف من `.github/` ولا من `ports/`، فلا يصل سير التشخيص
المؤقت (المحذوف أصلًا) ولا رقع الويندوز نفسها إلى فرعي ويندوز.

## التوافق

* الكود مكتوب بلغة لا تستخدم أي API أحدث من Flutter 3.16.9 / Dart 3.2
  (وهو الإصدار المثبّت في CI فرع ويندوز ٧): بدون `DropdownButtonFormField.initialValue`،
  وبدون `PopScope.onPopInvoked`، مع `AsyncNotifierProvider` من Riverpod 2.5.
* لا يعتمد على أي حزمة إضافية خارج `pubspec` الحالي، ولا يعدّل مخطط Isar.
* نقطة الدخول لم تُلمس: `lib/app/jadwal_app.dart` و`lib/app/jadwal_windows_app.dart`
  تستخدمان `HomePage` كما هي، وواجهة الإقلاع الجديدة داخل `HomePage` نفسها.

</div>

---

## رقعة ميزة «الحِمل الأسبوعي» (weekly load) — 2026-10-04

الرقعة الأصلية لهذه الميزة موجودة في فرع المصدر `arena/01a10437-jadwalv2`
(الالتزام `b522ff0`) وطُبِّقت على `main` عبر PR #132، وبقيت بحاجة إلى نقل
إلى فرعي ويندوز. الرقعتان:

* `ports/port-windows7-weekly-load.patch` — تُطبَّق على `برنامج-مخصص-لوندوز-٧`
  (قمة الفرع `b9b6215`) بـ 40 ملفًا.
* `ports/port-windows10-11-weekly-load.patch` — تُطبَّق على
  `برنامج-مخصص-لوندوز-١٠-و-١١` (قمة الفرع `6b253a3`) بـ 40 ملفًا.

### طريقة التطبيق

```bash
git checkout برنامج-مخصص-لوندوز-٧        # أو الفرع الآخر
git apply --check ports/port-windows7-weekly-load.patch
git apply ports/port-windows7-weekly-load.patch
git add -A
git commit -m "feat(weekly-load): سياسة الحِمل الأسبوعي والتوزيع اليومي للصفوف"
git push origin برنامج-مخصص-لوندوز-٧
```

### ما الذي تنقله الرقعة؟

نفس ملفات ميزة الحِمل الأسبوعي في `main`: `weekly_load_policy.dart`، تخصيص
الصفوف (`weeklyLessonsOverride` و`dailyPeriodsOverride` في `Classroom` مع
`classroom.g.dart` مولَّد بنفس معرّف المجموعة)، محرر الخطة الأسبوعية في
الإعدادات، أوضاع الحِمل، تكامل `SmartAutoFix` و`PreValidationEngine`، توحيد
خرائط الأيام في الجدول وPDF وExcel، والاختبارات (بما فيها اختبار ترحيل قاعدة
بيانات Isar القديمة واختبار انحدار خريطة الأيام)، والتوثيق.

### ما بقي خاصًّا بكل فرع ويندوز (لم تُستبدل ملفاته)

* `lib/features/management/presentation/pages/settings_page.dart` و
  `lib/features/timetable/presentation/pages/timetable_page.dart`
  (حفظ الملفات عبر `file_save_service.dart` بدل `FilePicker`/`SharePlus`).
* `.github/workflows/build.yml` و`.github/workflows/build_windows.yml`
  (اسم المنفذ التنفيذي، إصدار Flutter 3.16.9 في فرع ويندوز ٧، استبعاد
  `backup_service_benchmark_test.dart` من تشغيل الاختبارات)، مع إضافة
  `arena/**` إلى المشغّلات وتقرير أعداد الاختبارات عبر `flutter test --machine`.
* `lib/main_windows.dart`، `lib/app/*`، `windows/**`، `pubspec.yaml`
  (قيود الإصدارات)، `tools/**` وملفات `WINDOWS*.md`.

### التحقق

`.github/workflows/port-verify.yml` ينفّذ التحقق المستقل لكل هدف على بيئة CI
دون الدفع إلى الفروع الرسمية: يجلب الفرع، يطبّق الرقعة، ثم يشغّل
`flutter analyze --no-fatal-infos` و`flutter test --machine` وبناء
Windows Release واختبار الدخان. سكربتا المساعدة في `ports/ci/`.
