# Changelog

## Unreleased

- Replaced unavailable Inno input dialog API with two explicit destructive-action confirmations.

- Fixed Inno Setup uninstall confirmation input for sandbox destruction.

- Fixed Flutter analyzer cleanliness for the bundled backend startup path.

- Added Arena-style Flutter desktop shell for Windows.
- Added FastAPI Agent Controller with Kilo Gateway integration.
- Added plan → tool-call → approval → verify orchestration foundation.
- Added secret-safe local setup and output redaction.
- Added backend tests, Flutter tests, CI, Windows build artifacts, Dependabot, and issue templates.
- Added Inno Setup single-file Windows installer with embedded Flutter DLLs/assets and automatic uninstaller.
- Bundled the FastAPI backend as a Windows executable and auto-started it from the Flutter desktop client.
- Added uninstall cleanup for the bundled backend process.
- Added a Hyper-V isolated guest lifecycle broker with a fixed action allowlist and UAC elevation for sensitive lifecycle operations.
- Added the VM sandbox panel, exact-phrase destruction confirmation, and uninstall-time managed guest cleanup.
- Disabled host fallback for packaged computer-level execution until the isolated guest bridge is connected.
