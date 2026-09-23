# MDK Agent isolated Windows guest

MDK Agent uses a dedicated Hyper-V guest for computer-level automation. The host-side application is deliberately limited to sandbox lifecycle operations; terminal, browser, file, and UI automation must run through the guest agent after the guest Windows setup is completed.

## Requirements

- Windows 10/11 Pro or Enterprise with Hyper-V available
- Hardware virtualization enabled in firmware
- A user-provided Windows ISO; Windows is not redistributed by MDK Agent
- At least 8 GB free RAM and 64 GB free disk space for the managed guest

## Lifecycle

`MDK-Agent-Sandbox.ps1` accepts only these actions:

- `status`
- `create`
- `start`
- `stop`
- `destroy`

Create/start/stop/destroy request UAC elevation when necessary. `destroy` additionally requires the exact phrase `DESTROY MDK AGENT VM`. The root is hard-coded to `%LOCALAPPDATA%\MDK Agent\Sandbox`; arbitrary host paths cannot be passed to the destructive action.

The uninstaller asks whether to destroy the managed VM. If the user declines, uninstallation is cancelled rather than leaving a running or orphaned guest behind.

## Guest command bridge

After Windows is installed in the guest, copy `MDK-Agent-Guest.ps1` into the guest and run PowerShell as Administrator:

```powershell
PowerShell -ExecutionPolicy Bypass -File .\MDK-Agent-Guest.ps1 -Install
```

The script creates an authenticated guest-only command bridge and prints a one-time token. Put that token into the backend's local `MDK_AGENT_GUEST_TOKEN` secret field; never paste it into chat or commit it. Packaged mode sends approved `run_command` actions only to this guest bridge and refuses host fallback.
