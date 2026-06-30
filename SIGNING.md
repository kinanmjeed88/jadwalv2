# التقرير الفني: نظام التوقيع الهجين (Hybrid Signing)

## ملخص التغييرات
تم تحديث ملف `android/app/build.gradle.kts` ليعتمد نظام التوقيع الهجين (Hybrid Signing) لتسهيل عملية بناء التطبيق محلياً وعبر أنظمة التكامل المستمر (CI/CD) مثل GitHub Actions.

يعتمد النظام الحالي على **أولوية القراءة** التالية:
1. **محلياً (Local):** يقوم النظام بالبحث أولاً عن ملف `android/key.properties`. إذا كان الملف موجوداً ويحتوي على القيم المطلوبة، يتم استخدامه لاستخراج بيانات التوقيع (Keystore).
2. **سحابياً (CI/CD):** في حال عدم وجود ملف `key.properties` أو كانت القيم بداخله فارغة، ينتقل النظام تلقائياً للبحث عن متغيرات البيئة (Environment Variables) المعرفة في النظام. هذا يتيح لمنصة GitHub Actions بناء نسخة `release` بنجاح دون الحاجة لرفع ملفات حساسة إلى المستودع.

## تأكيد الأمان
لضمان أمان المفاتيح الخاصة بالتطبيق، تم تكوين ملف `android/.gitignore` لتجاهل الملفات التالية ومنع رفعها إلى المستودع (Repository):
- `key.properties`
- أي ملف بامتداد `*.keystore`
- أي ملف بامتداد `*.jks`

بذلك نضمن عدم تسريب أي بيانات توقيع حساسة للعامة.

## إعداد المتغيرات في GitHub Actions (Secrets)
لضمان نجاح البناء في GitHub Actions، يجب إضافة المتغيرات التالية في قسم **GitHub Secrets** (`Settings` -> `Secrets and variables` -> `Actions`):

| اسم المتغير (Secret Name) | الوصف |
| --- | --- |
| `STORE_PASSWORD` | كلمة المرور الخاصة بملف الـ Keystore. |
| `KEY_ALIAS` | الاسم المستعار (Alias) للمفتاح داخل الـ Keystore. |
| `KEY_PASSWORD` | كلمة المرور الخاصة بالمفتاح (Key Password). |
| `STORE_FILE_BASE64` | محتوى ملف الـ Keystore (`.jks` أو `.keystore`) مشفر بنظام Base64. |

## كيفية تحويل ملف Keystore إلى Base64
بما أن GitHub Secrets لا يدعم رفع الملفات مباشرة، يجب تحويل ملف الـ Keystore إلى نص (String) بصيغة Base64.

يمكنك تنفيذ هذا الأمر في سطر الأوامر (Terminal) على جهازك (Mac/Linux) لتحويل الملف ونسخ الناتج:
```bash
base64 -i upload-keystore.jks | pbcopy
```
*ملاحظة: إذا كنت تستخدم Windows، يمكنك استخدام أداة Git Bash أو PowerShell:*
```powershell
[convert]::ToBase64String((Get-Content -Path "upload-keystore.jks" -Encoding byte)) | Set-Clipboard
```

الناتج المنسوخ هو ما يجب وضعه كقيمة للمتغير `STORE_FILE_BASE64` في GitHub Secrets.

## إرشاد لاستخدام المتغيرات في GitHub Actions Workflow
لكي يقوم سير العمل (Workflow) بقراءة كود الـ Base64 وتحويله مرة أخرى إلى ملف حقيقي ليستخدمه Gradle أثناء البناء، يجب إضافة خطوة (Step) قبل عملية البناء `flutter build apk --release` في ملف `build.yml` كما يلي:

```yaml
    - name: Decode Keystore
      env:
        STORE_FILE_BASE64: ${{ secrets.STORE_FILE_BASE64 }}
      run: |
        echo $STORE_FILE_BASE64 | base64 --decode > $RUNNER_TEMP/upload-keystore.jks

    - name: Build Android Release
      env:
        STORE_FILE: ${{ runner.temp }}/upload-keystore.jks
        STORE_PASSWORD: ${{ secrets.STORE_PASSWORD }}
        KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
        KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
      run: flutter build apk --release
```
هذه الخطوة تضمن فك تشفير الملف، حفظه في مسار مؤقت (`$RUNNER_TEMP`)، وتمرير هذا المسار للمتغير `STORE_FILE` ليقرأه ملف `build.gradle.kts`.
