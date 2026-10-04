# تسليم ميزة Weekly Load / Classroom Customization — التقرير النهائي

التاريخ: 2026-10-04
الجلسة: `arena/01a106f4-jadwalv2`
المصدر المعتمد (Source of Truth): `b522ff0fe40a03a804146ded4bff3e9b5374afcc` على الفرع `arena/01a10437-jadwalv2` (وهو نفسه head الخاص بـ PR #132).

---

## 1) نتيجة فحص ملف الـPatch المرفق (`patch.diff`)

الملف المرفق في جذر المستودع (`patch.diff`) **ليس Feature Patch الكامل**، بل جزء تاريخي صغير
يخص تعديل `GenerationPayload` في `timetable_provider.dart` فقط (تغليف مدخلات الـIsolate).
لا يتضمن أياً من حقول `weeklyLessonsOverride`/`dailyPeriodsOverride` ولا ملفات الميزة الـ40.

**القرار:** لم يتم تطبيقه حرفياً. اعتمدنا فرق الميزة الكامل والصحيح:

```
git diff b362b5cd429a201f1f50b62763808de8647df53e..b522ff0fe40a03a804146ded4bff3e9b5374afcc
```

40 ملفاً، ‏+3847/−153، عبر 16 commit على رأسها `362323a..b522ff0`.

## 2) حالة الفروع قبل التسليم (تحقق فعلي عبر `git ls-remote`)

| الفرع | رأس الفرع الفعلي | الـBase المطلوب | النتيجة |
|---|---|---|---|
| `برنامج-مخصص-لوندوز-٧` | `b9b62154be64cb1b9cb5c6cf3063b57881aaa17d` | نفس القيمة | مطابق تماماً |
| `برنامج-مخصص-لوندوز-١٠-و-١١` | `6b253a397b64a6260b96d9d9e608b8e2dd5ec6c6` | نفس القيمة | مطابق تماماً |
| `main` | `b362b5cd429a201f1f50b62763808de8647df53e` | نفس القيمة | مطابق تماماً |

## 3) main — PR #132 (تم التحقق الحي)

```
gh pr view 132 → OPEN, base=main, head=arena/01a10437-jadwalv2 @ b522ff0
mergeStateStatus=CLEAN, mergeable=MERGEABLE
CI: Flutter Build (build x2) = SUCCESS
    Flutter Windows Build (Analyze, Test, and Build Windows x2) = SUCCESS
```

لم يُنشأ أي تغيير ثانٍ على `main` (لا يوجد سبب حقيقي). الحالة: **جاهز للدمج**.

## 4) طريقة النقل إلى فرعي وندوز

لكل فرع: تصنيف الملفات الـ40 مقابل رأس الفرع، ثم:

1. **36 ملفاً** مطابقة للـBase أو جديدة كلياً ← نُقلت **بايت-ببايت** من `b522ff0`
   (`git checkout b522ff0 -- <files>`).
2. **ملفان متباعدان** (`settings_page.dart`، `timetable_page.dart`) ← دمج ثلاثي
   `git merge-file` (نسخة الفرع مقابل قاعدة main مقابل نسخة الميزة):
   **صفر تعارضات** على الفرعين. تحقق يدوي أن المتبقي مقابل المصدر هو فقط خصوصيات وندوز:
   - وندوز 7: حفظ الصادرات عبر `FileSaveService` (بلا `share_plus`/`path_provider`)
     و`value:` بدل `initialValue:` في Dropdowns (توافق Flutter 3.16).
   - وندوز 10/11: حفظ الصادرات عبر `FileSaveService` مع بقاء `share_plus`/`path_provider`
     (موجودة في pubspec الخاص به).
3. **`build_windows.yml`** لكل فرع: إضافة فقط (أ) مشغّل `pull_request` على اسم الفرع نفسه
   حتى يعمل CI على طلبات الدمج المستهدفة له، و(ب) خطوتا التحليل والاختبارات من المصدر
   (تعليقات `::error` لنتائج `flutter analyze` وعدّاد `flutter test --machine`
   ‏`Passed/Failed/Skipped`). باقي الملف — نسخة Flutter، الـrunner، حذف `android/`،
   `--target=lib/main_windows.dart`، اسم الـexe، التوقيع، المثبّت — **لم يُمس**.
4. **`build.yml`** (بناء أندرويد) لم يُمس في الفرعين.

لم تُغيَّر: `pubspec.yaml`، `pubspec.lock`، `lib/main_windows.dart`، مجلد `windows/`
(المثبّت/التوقيع/الـmanifest)، الإصدار `1.0.0+1`، أو أي سلوك منصة غير متعلق بالميزة.

### خصوصيات وندوز 7 المحفوظة
- تثبيت `flutter-version: '3.16.9'` و`windows-2022` و`JadwalV2_Windows7.exe`.
- الاعتمادات القديمة (`file_picker ^8.0.0+1`، بلا `share_plus`/`gal`، firebase 2.x…).
- مسح فحص: لا يوجد في ملفات الميزة أي `extension type` (يتطلب Dart ≥3.3) أو
  `WidgetState*` أو `.withValues()` أو غيرها من واجهات أحدث من Flutter 3.16/Dart 3.2.
  كل الاستيرادات الحزمية للميزة موجودة في `pubspec.yaml` الخاص بويندوز 7.

## 5) سجل التحققات الفعلية (من شجرتي الفرعين، ليست نتائج جلسة سابقة)

| الفحص | وندوز 7 | وندوز 10/11 |
|---|---|---|
| `git diff --check` | نظيف (0) | نظيف (0) |
| عدد الملفات | 39 (كل سطح الميزة عدا `build.yml`) | 39 (مطابق) |
| مطابقة `classroom.g.dart` للمصدر | **بايت-ببايت** | **بايت-بايت** |
| فحص Isar: اسم/معرّف الـCollection | `Classroom` / `-8186663030834931469` **بدون تغيير** مقابل الـBase | نفس النتيجة |
| حقول Isar | إضافة `weeklyLessonsOverride`(long) + `dailyPeriodsOverride`(longList) فقط؛ `grade`/`name` محفوظة؛ لا حذف حقول ولا migration | نفس النتيجة |
| خرائط أيام الأسبوع | المصدر الوحيد `Weekday` (0=الأحد…6=السبت) عبر `timetableDayLabels` في: صفحة الجدول، تصدير PDF، تصدير Excel، وأسماء أيام المدرّسين عبر `Weekday.arabicLabel`؛ لا مصفوفات أيام متبقية في كود الميزة | نفس النتيجة |
| اختبارات أيام الأسبوع | `weekday_mapping_regression_test.dart` + `weekday_excel_export_test.dart` منقولة من المصدر | نفس النتيجة |
| SmartAutoFix | ملف `smart_auto_fix_usecase.dart` مطابق للمصدر (حدود الحصص اليومية عبر `_periodsForClassroomOnDay`)؛ حالة 30 حصة ← `[6,6,6,6,6]` مثبتة في `weekly_load_policy_test.dart:246` و`weekly_capacity_boundary_test.dart` و`weekly_load_migration_test.dart:40` | نفس النتيجة |
| سلامة الاستيرادات النسبية | فحص آلي لكل `lib/`+`test/`: لا ملف مفقوداً | نفس النتيجة |
| صلاحية YAML لملفات الـworkflows | جميعها تُحلَّل بنجاح، بلا أسماء خطوات مكررة | نفس النتيجة |
| أمانة الـpatch | `git am` للباتش على رأس الفرع يعيد نفس الـtree بالضبط (`bd2dd81f…`) | نفس النتيجة (`e210bac4…`) |

### ما تعذّر تشغيله محلياً (موثّق، ليس تجاهلاً)
بيئة العمل هذه لا تملك اتصالاً بـ `storage.googleapis.com` ولا `pub.dev`
(القياس الفعلي: `000` لكليهما مقابل `200` لـGitHub)، لذا يستحيل هنا:
تنصيب Flutter، `flutter analyze`، `flutter test --machine`، بناء Windows، والـSmoke Test.
هذه تُغطّى حصراً عبر GitHub Actions على الفرع الرسمي/الـPR (الخطوات موجودة أصلاً في
`build_windows.yml` + عدّاد النتائج المنقول أعلاه). لذلك حالتها أدناه `UNVERIFIED` حتى يعمل CI.

## 6) الـcommits الجاهزة للتسليم

| الهدف | فوق الـBase | Commit التسليم | الشجرة |
|---|---|---|---|
| وندوز 7 | `b9b6215` | `86cc32480478072b4615a40250a4bc7565dbd83c` | `bd2dd81fc63868d2a0881ea091ce9de656bc5eee` |
| وندوز 10/11 | `6b253a3` | `980b44dac391149b70da930568ceca320b285637` | `e210bac4636184fb9d94279f210d5e84d93697ac` |

الباتشات القابلة للتطبيق مباشرة (`git am`):
- `delivery/win7-weekly-load.patch`
- `delivery/win10-weekly-load.patch`

## 7) التسليم المباشر — نُفِّذ بناءً على تفويض صريح من مالك المستودع (تحديث 2026-10-04)

بعد تقرير العائق الأولي (ربط الجلسة بفرع الـarena)، أصدر مالك المستودع تعليمات صريحة
ومكررة بالتنفيذ المباشر. نُفِّذ الآتي فعلياً:

1. فُرِع كل باتش من هذه الحزمة (`git am`) فوق رأس الفرع الرسمي الصحيح دون أي تعديل:
   - `برنامج-مخصص-لوندوز-٧` @ `b9b6215` ← الفرع `delivery/weekly-load-windows-7` @ `7c6d6a08af7aa41617a74fa3b908ae42519fc3a1`
   - `برنامج-مخصص-لوندوز-١٠-و-١١` @ `6b253a3` ← الفرع `delivery/weekly-load-windows-10-11` @ `af279415656378dbb1f710b29cc1e46e83cb7ff2`
2. دُفع الفرعان مباشرة إلى `origin`.
3. فُتح طلبا دمج رسميان:
   - **PR #134** → القاعدة `برنامج-مخصص-لوندوز-٧`
   - **PR #135** → القاعدة `برنامج-مخصص-لوندوز-١٠-و-١١`
4. انتُظر CI حتى اكتماله وتحُقِّق من النتائج خطوةً بخطوة.

## 8) نتائج CI الفعلية (من الفرعين المدفوعين، وليست نتائج جلسات سابقة)

### PR #134 — وندوز 7 (run 37205186322، `Analyze, Test, and Build Windows`)
| المرحلة | النتيجة |
|---|---|
| Analyze Dart and Flutter Sources | ✅ success |
| Run Flutter Tests | ✅ success — **Passed=111; Failed=0; Skipped=0** |
| Build Windows Release (`flutter build windows --release --target=lib/main_windows.dart`) | ✅ success |
| Verify Windows Release Bundle (`JadwalV2_Windows7.exe`) | ✅ success |
| Run Windows Smoke Test | ✅ success |
| Inno Setup installer + artifacts | ✅ success |
المدة: 4m41s — الخلاصة: `pass`، وحالة الـPR `CLEAN / MERGEABLE`.

### PR #135 — وندوز 10/11 (run 37205190080، `Analyze, Test, and Build Windows`)
| المرحلة | النتيجة |
|---|---|
| Analyze Dart and Flutter Sources | ✅ success |
| Run Flutter Tests | ✅ success — **Passed=111; Failed=0; Skipped=0** |
| Build Windows Release | ✅ success |
| Verify Windows Release Bundle (`JadwalV2_Windows10_11.exe`) | ✅ success |
| Run Windows Smoke Test | ✅ success |
| Inno Setup installer + artifacts | ✅ success |
المدة: 7m47s — الخلاصة: `pass`، وحالة الـPR `CLEAN / MERGEABLE`.

التغطية الضمنية داخل الـ111 اختباراً: `weekday_mapping_regression_test`،
`weekday_excel_export_test`، `weekly_load_policy_test` (ضمنها 30 حصة ← [6,6,6,6,6])،
`weekly_capacity_boundary_test`، `weekly_load_migration_test` (Isar)،
`weekly_load_timetable_integration_test`، و`app_backup_service_test`.
التنبيه الوحيد في السجلات: إيقاف Node.js 20 في actions/checkout@v4 و
actions/upload-artifact@v4 — تنبيه منصة قائم مسبقاً وغير متعلق بالميزة.

## 9) الجدول الختامي

| Target | Branch | Commit | PR | Tests | Analyze | Release | Smoke | Status |
|---|---|---|---|---|---|---|---|---|
| Android/main | `main` | `b522ff0` (رأس الميزة نفسه) | #132 مفتوح وجاهز للدمج | PASS | PASS | PASS | PASS | **DONE** |
| Windows 7 | `برنامج-مخصص-لوندوز-٧` | `7c6d6a0` (رأس `delivery/weekly-load-windows-7`) | #134 مفتوح | PASS (111/0/0) | PASS | PASS | PASS | **DONE** |
| Windows 10/11 | `برنامج-مخصص-لوندوز-١٠-و-١١` | `af27941` (رأس `delivery/weekly-load-windows-10-11`) | #135 مفتوح | PASS (111/0/0) | PASS | PASS | PASS | **DONE** |

الدمج النهائي للـPRات الثلاثة قرار مالك المستودع؛ الحالات كلها `CLEAN / MERGEABLE`.
