#define AppName "Jadwal V2 - Windows 10 and 11"
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
AppId={{5C0A9A7B-7F56-4C44-9B0B-4B6E2F3E7D10}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Jadwal V2
DefaultDirName={localappdata}\Programs\Jadwal V2 Windows 10 and 11
DefaultGroupName=Jadwal V2 - Windows 10 and 11
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=Jadwal-V2-Windows-10-11-{#AppVersion}-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
WizardStyle=modern
UninstallDisplayIcon={app}\JadwalV2_Windows10_11.exe

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Jadwal V2 - Windows 10 and 11"; Filename: "{app}\JadwalV2_Windows10_11.exe"
Name: "{autodesktop}\Jadwal V2 - Windows 10 and 11"; Filename: "{app}\JadwalV2_Windows10_11.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Run]
Filename: "{app}\JadwalV2_Windows10_11.exe"; Description: "Launch Jadwal V2 - Windows 10 and 11"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\Jadwal V2 Windows 10 and 11"
