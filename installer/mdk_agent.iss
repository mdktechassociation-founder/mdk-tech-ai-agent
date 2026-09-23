#define AppName "MDK Agent"
#define AppVersion "0.1.2"
#define AppPublisher "MDK Tech Association"
#define AppExeName "mdk_agent_desktop.exe"
#define BuildOutput "..\\apps\\flutter_agent\\build\\windows\\x64\\runner\\Release"

[Setup]
AppId={{A7C3B5D2-8F5E-4C7D-9A3E-1D0D4E2B6C91}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/mdktechassociation-founder/mdk-tech-ai-agent
AppSupportURL=https://github.com/mdktechassociation-founder/mdk-tech-ai-agent/issues
AppUpdatesURL=https://github.com/mdktechassociation-founder/mdk-tech-ai-agent/releases
DefaultDirName={localappdata}\Programs\MDK Agent
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=MDK-Agent-Setup-v{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile=
UninstallDisplayIcon={app}\{#AppExeName}
Uninstallable=yes
CreateUninstallRegKey=yes
ChangesAssociations=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
; The installer embeds the full Flutter release directory, including the EXE,
; DLLs, data folder, ICU files, and all runtime assets.
Source: "{#BuildOutput}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "..\services\agent_api\dist\mdk-agent-api.exe"; DestDir: "{app}\backend"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{cmd}"; Parameters: "/C taskkill /IM mdk-agent-api.exe /F"; Flags: runhidden waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
