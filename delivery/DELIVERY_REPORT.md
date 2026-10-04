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

## 7) عائق التسليم المباشر — صلاحيات الجلسة

صلاحيات GitHub نفسها **كافية** (التحقق الحي: `gh api` → `admin/push: true` باسم مالك المستودع).
العائق هو **ربط الجلسة**: هذه الجلسة مقيّدة من المنصة بالفرع `arena/01a106f4-jadwalv2`
فقط — يُحظر عليها التبديل إلى فرع آخر أو الإنشاء أو الـpush إليه. لذا لم يُنفَّذ
الـpush المباشر إلى الفرعين الرسميين ولم يُفتح PR رسمي منهما، وأي ادعاء بغير ذلك
يكون غير صحيح. الـPR من فرع الـarena نحو فرعي وندوز مرفوض هندسياً أيضاً لأن الفرع
الجلسي مبني على `main` وسيجرّ ~29 commit غير متعلقة تتجاوز خصوصيات وندوز.

### أوامر التنفيذ الفورية (جلسة غير مقيّدة أو يدوياً)

```bash
# وندوز 7 — دفع مباشر (سيشغّل الـpush في CI لأن الفرع في قائمة الـpush)
git fetch origin 'برنامج-مخصص-لوندوز-٧'
git checkout -B برنامج-مخصص-لوندوز-٧ origin/برنامج-مخصص-لوندوز-٧
git am delivery/win7-weekly-load.patch
git push origin برنامج-مخصص-لوندوز-٧

# وندوز 10/11 — دفع مباشر
git fetch origin 'برنامج-مخصص-لوندوز-١٠-و-١١'
git checkout -B برنامج-مخصص-لوندوز-١٠-و-١١ origin/برنامج-مخصص-لوندوز-١٠-و-١١
git am delivery/win10-weekly-load.patch
git push origin برنامج-مخصص-لوندوز-١٠-و-١١
```

أو بمسار PR: إنشاء فرع من كل `git am` ثم
`gh pr create --base 'برنامج-مخصص-لوندوز-٧' …` — مشغّل الـ`pull_request`
الذي أُضيف لهذه الغاية سيشغّل الفحوص على الـPR.

## 8) الجدول الختامي

| Target | Branch | Commit | PR | Tests | Analyze | Release | Smoke | Status |
|---|---|---|---|---|---|---|---|---|
| Android/main | `main` | `b522ff0` (رأس الميزة نفسه) | #132 مفتوح وجاهز | PASS (CI حي) | PASS (CI حي) | PASS (CI حي) | PASS (CI حي) | **DONE** |
| Windows 7 | `برنامج-مخصص-لوندوز-٧` | محضّر: `86cc324` (باتش مُتحقَّق) | لم يُفتح — عائق جلسة | UNVERIFIED بانتظار CI | UNVERIFIED بانتظار CI | UNVERIFIED بانتظار CI | UNVERIFIED بانتظار CI | **BLOCKED** (صلاحيات الجلسة) |
| Windows 10/11 | `برنامج-مخصص-لوندوز-١٠-و-١١` | محضّر: `980b44d` (باتش مُتحقَّق) | لم يُفتح — عائق جلسة | UNVERIFIED بانتظار CI | UNVERIFIED بانتظار CI | UNVERIFIED بانتظار CI | UNVERIFIED بانتظار CI | **BLOCKED** (صلاحيات الجلسة) |

ملاحظة: نتائج "111 passed / 0 failed" السابقة تخص جلسات سابقة على `main`؛ القاعدة
المطلوبة هي إعادة التحقق من الفرع المدفوع فعلياً — وهذا ما سيتكفل به CI فور تنفيذ
الـpush أعلاه (العدّاد المنقول في الـworkflow يطبع `Passed/Failed/Skipped` في ملخص الخطوة).
