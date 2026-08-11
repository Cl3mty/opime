; Freenary Windows Installer
; Generated with Inno Setup

#define MyAppName "Freenary"
#define MyAppVersion "0.6.0"
#define MyAppPublisher "Freenary"
#define MyAppExeName "freenary.exe"

[Setup]

; Unique identifier of this application
AppId={{B3F02C1E-4012-4E3D-BC9B-89C5DA669962}

AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}

DefaultDirName={autopf}\{#MyAppName}

UninstallDisplayIcon={app}\{#MyAppExeName}

; ARM64 only
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64

DisableProgramGroupPage=yes

; Output
OutputDir=Output
OutputBaseFilename=Freenary-Setup-{#MyAppVersion}-ARM64

; Compression
Compression=lzma2
SolidCompression=yes

; Modern installer UI
WizardStyle=modern

; Windows file information
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Freenary Personal Wealth Manager
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}


[Languages]

Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"


[Tasks]

Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked


[Files]

Source: "..\build\windows\arm64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs


[Icons]

Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon


[Run]

Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent