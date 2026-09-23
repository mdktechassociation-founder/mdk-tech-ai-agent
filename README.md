# MDK Tech AI Agent

An Arena-style desktop AI agent project by **MDK Tech Association**.

## Current milestone

- Flutter desktop client foundation for Windows
- Dark Agent Mode UI with chat, live workflow timeline, and safety status
- FastAPI backend foundation
- Kilo Gateway provider adapter
- Secret references kept server-side; raw keys are never sent to Flutter or the model tool context
- Gemini web automation explicitly disabled by default
- No Tor rate-limit or quota bypass logic

## Architecture

```text
Flutter Windows client
        ↓ local HTTP
FastAPI Agent Controller
        ↓ credential_ref only
Kilo / Gemini provider adapters
        ↓ approval-gated tools
Workspace, web, GitHub, image and browser tools
```

## Run locally

### Backend

```bash
cd services/agent_api
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
cp .env.example ~/.config/mdk-tech-ai-agent/secrets.env
chmod 600 ~/.config/mdk-tech-ai-agent/secrets.env
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Edit `~/.config/mdk-tech-ai-agent/secrets.env` locally. Never commit the real file.

### Flutter Windows client

Install Flutter with Windows desktop support, then:

```bash
cd apps/flutter_agent
flutter create .
flutter pub get
flutter run -d windows --dart-define=AGENT_API_BASE_URL=http://127.0.0.1:8000
```

`flutter create .` generates the platform runner files while preserving the Dart app source.

## Safety direction

This agent will use a plan → execute → verify loop. Destructive actions, external publishing, repository changes, and browser actions must pass approval gates. Provider keys, passwords, cookies, and tokens belong in a secure backend environment, never in the Flutter bundle, chat messages, logs, or Git history.

## Windows installer

The Windows workflow creates a single Inno Setup installer:

```text
MDK-Agent-Setup-v0.2.0.exe
```

It embeds the complete Flutter release directory, including the app EXE, DLLs, `data` folder, ICU files, and runtime assets. Users do not need to extract a ZIP manually. The installer creates Start Menu shortcuts, optionally creates a desktop shortcut, and registers an uninstaller in Windows Add/Remove Programs.

The installer also bundles the FastAPI backend as `backend\\mdk-agent-api.exe`. The Flutter desktop client starts this local backend automatically on Windows. The backend still reads credentials only from the user's secure local secret file; no keys are shipped in the installer.

## Isolated computer-control mode

The Windows installer includes a Hyper-V lifecycle broker and a dedicated sandbox control panel. In packaged mode, host fallback for computer-level tools is disabled: lifecycle operations are limited to the managed guest, and the included guest bridge must be installed inside the guest before terminal, browser, file, or UI automation can run. This prevents a missing sandbox from silently turning into unrestricted host control.

The sandbox uses the fixed `%LOCALAPPDATA%\\MDK Agent\\Sandbox` root and supports only status, create, start, stop, and destroy operations. Create/start/stop/destroy can request UAC elevation. Destruction requires the exact phrase `DESTROY MDK AGENT VM`. The uninstaller asks for the same explicit decision and cancels if the managed guest cannot be destroyed, preventing an orphaned VM.

Hyper-V Pro/Enterprise, hardware virtualization, and a user-provided licensed Windows ISO are required. MDK Agent does not redistribute Windows.
