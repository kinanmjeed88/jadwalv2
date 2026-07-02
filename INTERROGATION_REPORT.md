# 🎯 تقرير الاستجواب المعماري (Architectural Interrogation Report)

## 💡 التناقض (The Discrepancy)
التصميم النظري يدعي أنه تم عزل كائنات `Isar` تماماً من خلال تحويلها إلى DTOs، وأنه تم استخدام دالة من المستوى الأعلى (`_generateInIsolate`) لمنع التقاط الـ `this`.

**لكن الفشل يكمن في طبيعة لغة Dart في التعامل مع الـ Closures (Anonymous Functions):**
في السطر البرمجي:
`await Isolate.run(() => _generateInIsolate(payload));`

الدالة المجهولة `() => ...` تم تعريفها داخل النطاق المحلي (Lexical Scope) لدالة `generateTimetable`. في لغة Dart، الـ Closure يقوم أحياناً بالتقاط متغيرات من النطاق المحيط به (Context) حتى لو لم يتم استدعاؤها مباشرة داخل الـ Closure، أو أن مترجم Dart يحتفظ بمرجع للنطاق (Scope) ككل الذي يحتوي بدوره على كائنات غير قابلة للإرسال (Unsendable Objects) مثل `IsarImpl`.

هذا يعني أن محاولة عزل الـ `payload` فشلت لأن الـ Closure التقط النطاق المحلي الذي يعج بكائنات قاعدة البيانات.

---

## 🎯 المتغيرات المحتجزة (Captured Variables)
الرسالة `Context num_variables: 6` تشير إلى أن الـ Closure التقط 6 متغيرات من النطاق المحيط في `generateTimetable`. بالنظر إلى النطاق المحلي قبل الـ `Isolate.run` مباشرة، نجد الكائنات التالية التي تحمل أو ترتبط بـ `IsarImpl`:
1. `this` (كائن الـ `TimetableNotifier` الذي قد يحمل مرجعاً بطريقة غير مباشرة).
2. `isar` (نسخة قاعدة البيانات `IsarImpl`).
3. `teachers` (قائمة كائنات Isar).
4. `subjects` (قائمة كائنات Isar).
5. `classrooms` (قائمة كائنات Isar).
6. `existingLessons` (قائمة كائنات Isar).

*حتى لو لم تُكتب هذه المتغيرات حرفياً داخل الـ `()`، فإن المترجم يقوم بتمرير الـ Context الذي يحويها لتكوين بيئة الـ Closure، مما يؤدي إلى انهيار الـ Isolate فور محاولة إرسال هذا النطاق عبر منافذ الاتصال (Ports).*

---

## 💻 السطر المعيب (The Faulty Code)
يوجد السطر الكارثي في ملف `lib/features/timetable/presentation/providers/timetable_provider.dart`:

```dart
// السطر المعيب الذي يسمح بتسرب الـ Lexical Scope:
final resultDtos = await Isolate.run(() => _generateInIsolate(payload));
```

**لماذا هو معيب؟**
لأن `() => ...` تلتقط بيئة دالة `generateTimetable`.

**الحل المعماري الصحيح (للعلم فقط):**
يجب أن يتم الاستدعاء بتمرير دالة ثابتة (Tear-off) تأخذ الـ Payload كمعامل، دون إنشاء دالة مجهولة داخل النطاق المحلي، مثل:
`await Isolate.run<List<LessonDto>>((payload) => _generateInIsolate(payload), payload);`
*(أو بالأحرى استخدام `compute(_generateInIsolate, payload)` لتجنب الـ Closures تماماً).*