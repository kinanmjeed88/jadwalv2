# برنامج مخصص لـWindows 10 و11

هذا الفرع ينتج برنامجًا واضح الاسم حتى لا يختلط مع نسخة Windows 7.

| العنصر | الاسم |
|---|---|
| اسم البرنامج | `Jadwal V2 - Windows 10 and 11` |
| الملف التنفيذي | `JadwalV2_Windows10_11.exe` |
| ZIP | `Jadwal-V2-Windows-10-11-<version>.zip` |
| المثبت | `Jadwal-V2-Windows-10-11-<version>-Setup.exe` |
| مجلد التثبيت | `Jadwal V2 Windows 10 and 11` |

يبني GitHub Actions هذا الفرع باستخدام `lib/main_windows.dart` ويجري فحص startup وSmoke Test قبل التغليف.

ملف `flutter_windows.dll` في هذه النسخة قد يستورد `GetHostNameW` من `WS2_32.dll`. هذا الاستدعاء صحيح لWindows 10 وWindows 11، لكنه ليس متوافقًا مع Windows 7؛ لذلك لا يجوز تشغيل هذا البرنامج على Windows 7 ولا نسخ DLLs النظام من Windows 10 إلى Windows 7.

يبقى APK منفصلًا ويُبنى من `lib/main.dart` في workflow Android.
