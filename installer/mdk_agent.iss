#define AppName "MDK Agent"
#define AppVersion "0.2.2"
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
Source: "..\sandbox\*"; DestDir: "{app}\sandbox"; Flags: recursesubdirs createallsubdirs ignoreversion

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


[Code]
function InitializeUninstall(): Boolean;
var
  ResultCode: Integer;
  SandboxScript: String;
begin
  Result := True;
  SandboxScript := ExpandConstant('{app}\sandbox\MDK-Agent-Sandbox.ps1');
  if not FileExists(SandboxScript) then
    exit;

  { Exit code 10 means managed sandbox data exists. }
  if Exec(
    ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -ExecutionPolicy Bypass -File "' + SandboxScript + '" -Action status -Quiet',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 10) then
  begin
    if MsgBox(
      'A dedicated MDK Agent Windows sandbox exists. Uninstalling without destroying it would leave managed VM data behind.' + #13#10#13#10 +
      'Choose Yes to permanently destroy the sandbox and continue uninstalling, or No to cancel.',
      mbConfirmation, MB_YESNO) <> IDYES then
    begin
      Result := False;
      exit;
    end;

    if MsgBox(
      'Final confirmation: permanently destroy the MDK Agent VM, its disk, snapshots, and all data inside it?',
      mbConfirmation, MB_YESNO) <> IDYES then
    begin
      Result := False;
      exit;
    end;

    if (not Exec(
      ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
      '-NoProfile -ExecutionPolicy Bypass -File "' + SandboxScript + '" -Action destroy -ConfirmationPhrase "DESTROY MDK AGENT VM"',
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode)) or (ResultCode <> 0) then
    begin
      MsgBox('The sandbox could not be destroyed. Uninstallation was cancelled so no managed VM is orphaned.', mbError, MB_OK);
      Result := False;
    end;
  end;
end;
