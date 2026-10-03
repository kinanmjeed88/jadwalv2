1. **Domain Layer:**
   - Delete `UnsolvableTimetableException`.
   - Create `TimetableGenerationException` and `ConflictReason` sealed class as specified with exclusive sub-types.
2. **Generators & Validations:**
   - Modify `PreValidationEngine` to collect errors, construct the `ConflictReason` models, and throw `TimetableGenerationException` when validation fails. Ensure all checks run to gather all errors (Collect-All).
   - Modify `TimetableGenerator`'s `_getConflicts` to return `List<ConflictReason>`, then update `generate()` to throw `TimetableGenerationException` populated with those reasons.
3. **Presentation Layer:**
   - Create `ConflictMessageMapper` class in presentation to map `ConflictReason` objects to localized Arabic Strings.
   - Update `timetable_page.dart` inside the `catch` block (and ONLY inside the catch block) to build an `AlertDialog` using `ConstrainedBox` (maxHeight 60% of screen height) containing a `SingleChildScrollView` displaying errors translated by `ConflictMessageMapper` as bullet points.
4. **Testing:**
   - Create tests for `ConflictMessageMapper`.
   - Create tests for `PreValidationEngine` ensuring `Collect-All` behavior is preserved and it maps errors to correct `ConflictReason` sub-types.
5. **Clean up & Pre-commit check:**
   - Ensure `flutter analyze` and `flutter test` pass before proceeding to submission.

---

## خطة الميزة الجديدة: الإعداد الأولي الإلزامي وسياسة قيود المرحلة الابتدائية

الحالة: **منجزة على فرع `arena/01a1032a-jadwalv2`** (تُنقل إلى فرعي ويندوز عبر رقع `ports/`).

1. **طبقة الإعدادات (خارج قاعدة البيانات):**
   - `AppConfig` + `AppConfigService` + `AppConfigNotifier` لحفظ: اكتمال الإعداد الأولي، المرحلة الدراسية، وسجلّ القيود التلقائية (المُدارة والمحذوفة) في `jadwal_app_config.json` بكتابة ذرّية وقراءة متسامحة.
2. **واجهة الإقلاع:**
   - `appSetupStatusProvider` يفرّق بين: إعداد مطلوب، ترقية مستخدم قديم (اعتماد صامت بمرحلة `fallback`)، وإعداد مكتمل.
   - `FirstRunSetupPage` إلزامية عند أول تشغيل: اسم المدرسة، اسم المدير، عدد الدروس يوميًا، عدد أيام الأسبوع، المرحلة (ابتدائي / متوسط+).
3. **سياسة المرحلة الابتدائية:**
   - `PrimaryStageConstraintPolicy` (كيان نقي قابل للاختبار): أي مادة يتجاوز حملها الأسبوعي **٦ حصص** تدخل سياسة التخطي، بحد أدنى **حصتان في اليوم**، مع الرفع الرياضي `ceil(load / daysPerWeek)`.
   - `SubjectConstraintAutoSyncService` يكتب القيود في جدول `SubjectConstraint` كأي قيد يدوي (قابل للتعديل والحذف)، ويتتبع: تعديل المستخدم → يتحول إلى يدوي، حذفه → لا يُعاد، وتغيير المرحلة إلى متوسط+ → إزالة قيود النظام فقط.
4. **النسخ الاحتياطي:**
   - `BackupService` يصدّر/يستورد الآن إعدادات المدرسة والمدير وقيود المواد (بمفاتيح اختيارية متوافقة مع النسخ القديمة).
   - `AppBackupService` يدمج مقطع `appConfig` للحفاظ على المرحلة وسجلّ القيود التلقائية.
5. **الاختبارات والتحقق:**
   - اختبارات وحدة للسياسة والإعدادات والتحقق من الحقول والنسخ الاحتياطي.
   - `flutter analyze --no-fatal-infos` بصفر أخطاء وتحذيرات، ونجاح كل الاختبارات في CI.
