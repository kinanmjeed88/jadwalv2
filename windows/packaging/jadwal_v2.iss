#define AppName "Jadwal V2 - Windows 7"
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

[Setup]
AppId={{5C0A9A7B-7F56-4C44-9B0B-4B6E2F3E7D07}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Jadwal V2
DefaultDirName={localappdata}\Programs\Jadwal V2 Windows 7
DefaultGroupName=Jadwal V2 - Windows 7
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=Jadwal-V2-Windows-7-{#AppVersion}-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
WizardStyle=modern
UninstallDisplayIcon={app}\JadwalV2_Windows7.exe

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Jadwal V2 - Windows 7"; Filename: "{app}\JadwalV2_Windows7.exe"
Name: "{autodesktop}\Jadwal V2 - Windows 7"; Filename: "{app}\JadwalV2_Windows7.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Run]
Filename: "{app}\JadwalV2_Windows7.exe"; Description: "Launch Jadwal V2 - Windows 7"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\Jadwal V2 Windows 7"
