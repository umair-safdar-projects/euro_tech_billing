#ifndef MyAppVersion
  #define MyAppVersion "1.0.2"
#endif

#define MyAppName "Euro Tech Billing"
#define MyAppPublisher "Euro Tech Edging and Cutting"
#define MyAppExeName "EuroTechBilling.exe"

[Setup]
AppId={{F451451D-6F23-4C44-96AC-08F7B3A538BE}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Euro Tech Billing
DefaultGroupName=Euro Tech Billing
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=EuroTechBilling-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#MyAppVersion}.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Euro Tech Billing installer
VersionInfoProductName={#MyAppName}

[Code]
const
  VcRuntimeKey = 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64';

function HasVcRuntime(RootKey: Integer): Boolean;
var
  Installed, Major, Minor: Cardinal;
begin
  Result :=
    RegQueryDWordValue(RootKey, VcRuntimeKey, 'Installed', Installed) and
    (Installed = 1) and
    RegQueryDWordValue(RootKey, VcRuntimeKey, 'Major', Major) and
    RegQueryDWordValue(RootKey, VcRuntimeKey, 'Minor', Minor) and
    ((Major > 14) or ((Major = 14) and (Minor >= 44)));
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if not (HasVcRuntime(HKLM32) or HasVcRuntime(HKLM64)) then
    Result := 'Install the Microsoft Visual C++ v14 Redistributable (x64) ' +
      'from https://aka.ms/vc14/vc_redist.x64.exe, then run Setup again.';
end;

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Euro Tech Billing"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\Euro Tech Billing"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Euro Tech Billing"; Flags: nowait postinstall skipifsilent

; Operator data is intentionally outside {app}, in the Windows application-data
; directory selected by path_provider. No [UninstallDelete] entry targets it, so
; uninstall and in-place upgrades preserve invoices, payments, and backups.
