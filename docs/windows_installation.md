# Windows installation and updates

## Build workstation requirements

- 64-bit Windows 10 or 11
- Flutter 3.38 compatible stable SDK with Dart 3.11+
- Visual Studio 2022 with **Desktop development with C++** and the Windows SDK
- Inno Setup 6
- Git/PowerShell and project dependencies available to `flutter pub get`

From the project root, run:

```powershell
flutter doctor -v
powershell -ExecutionPolicy Bypass -File scripts\build_windows_release.ps1 -Version 1.0.1 -BuildNumber 2
```

The script runs dependency resolution, analysis, all tests, `flutter build windows --release`, verifies the executable and required runtime bundle, and invokes Inno Setup. The installer is written to `dist\EuroTechBilling-Setup-1.0.1.exe`.

The current clean ET icon is a temporary vector-led brand asset. To replace it, update `assets\branding\euro_tech_icon.svg` and its 256-pixel PNG render, then run `dart run tool\generate_app_icon.dart`. That command rebuilds the multi-resolution Windows `.ico`; verify all sizes in Explorer before release.

Equivalent manual commands:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --release --build-name 1.0.1 --build-number 2 --dart-define=APP_BUILD_SHA=local --dart-define=APP_BUILD_RUN=local
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DMyAppVersion=1.0.1 installer\euro_tech_billing.iss
```

## Shop installation

1. Copy the installer to the shop computer and scan it with Windows Security.
2. Run as an administrator and accept the default Program Files destination.
3. Select the optional desktop shortcut if desired; the Start-menu shortcut is automatic.
4. Launch the application, verify company settings, choose a backup folder outside Program Files, and create a manual backup.
5. Complete the printer-validation checklist before production use.

Application files are installed under Program Files. Operator data is kept in the Windows application-support location through `path_provider`, never beside the executable. The installer and uninstaller do not delete that data.

## Updating

Create and verify a manual backup, close the application, then install the newer package over the existing installation. The stable Inno Setup AppId performs an in-place upgrade. Forward-only SQLite migrations run at next launch. Never copy a database into Program Files or remove the application-data folder during an update.

## Uninstall

Use Windows **Installed apps → Euro Tech Billing → Uninstall**. Shortcuts and installed binaries are removed. Customer invoices, payments, database files, and external backups are intentionally preserved. Delete them only through a separately approved data-retention process.
