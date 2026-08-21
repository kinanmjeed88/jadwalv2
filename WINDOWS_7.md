# برنامج مخصص لوندوز ٧

هذا الفرع منفصل عن فرع Windows 10 و11 وعن `main`، ويستخدم محاولة توافق خاصة مع Windows 7 SP1 x64.

## طريقة البناء

يستخدم workflow الخاص بهذا الفرع Flutter 3.16.9 وrunner من نوع Windows 2019، ثم يبني من نقطة الدخول المعزولة:

```bash
flutter build windows --release --target=lib/main_windows.dart
```

تم تعديل manifest إلى GUID الخاص بـWindows 7، واستُبدل `PerMonitorV2` بإعداد DPI أقدم مناسب للنظام. كما خُفضت بعض الحزم التي تتطلب Flutter 3.19 أو أحدث. وتستخدم نقطة دخول Windows واجهة مكتبية مستقلة لا تستورد Firebase أو خدمة analytics الخاصة بالـAPK. يحذف CI مجلد Android من مساحة البناء المؤقتة فقط حتى لا يفحص Flutter 3.16 embedding القديم؛ ملفات Android الأصلية لا تُحذف من المستودع.

## التحذير المهم

Flutter الحديث لا يدعم Windows 7. توثيق Flutter الحالي يصنف Windows 10 و11 كمنصات مدعومة، ويصنف Windows 8 وما قبله كمنصات غير مدعومة. كما أن Flutter 3.19 أسقط دعم Windows 7 وWindows 8، وقد ظهرت في Flutter 3.22 مشكلة تشغيل بسبب اعتماد `flutter_windows.dll` على `GetHostNameW` غير المتوفر بالطريقة المطلوبة في Windows 7.

لذلك فهذا الفرع **ليس ضمانًا نهائيًا لتشغيل Windows 7** قبل اختبار ملف التنفيذ الناتج على جهاز Windows 7 SP1 x64 نظيف. إذا فشل التشغيل بسبب DLL أو إحدى الإضافات، فالحل الصحيح سيكون استخدام Flutter أقدم أو إعادة بناء محرك Flutter/الاعتماد على تقنية Windows مختلفة، وليس تعديل APK.

## عزل APK

يبقى APK على نقطة الدخول `lib/main.dart`، بينما Windows يستخدم `lib/main_windows.dart`. لا ينبغي دمج هذا الفرع في `main` أو استخدامه لبناء APK.
