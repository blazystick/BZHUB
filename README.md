# BLZOOM

A Windows screen-zoom utility with a smooth magnified view and configurable controls.

> **Status: release preparation / testing required.** The executable has not yet been built and tested on Windows from this branch.

## Download and run

When a Windows build is published, download `BLZOOM.exe` from the project's **Releases** page and run it on Windows 10/11.

The application uses screen capture and global keyboard/mouse input. Windows may display security prompts, and some games or anti-cheat software may restrict overlays. Do not try to bypass anti-cheat protections.

## Build from source (Windows)

1. Install 64-bit Python 3.11 or newer.
2. Install Git and clone this repository.
3. Open the project folder.
4. Run `build.bat`.
5. The executable will be created at `dist\BLZOOM.exe`.

The build script creates an isolated `.venv-build` environment and installs packages from `requirements-build.txt`.

## Runtime data

BLZOOM stores `config.json` and `app.log` beside the executable. Keep the executable in a folder where the current Windows user can write files.

## Troubleshooting

- If the app does not start, check `app.log` beside the executable.
- If Windows or antivirus software blocks the executable, review the warning before allowing it.
- Capture behavior can vary by GPU, display driver, Windows version, and protected applications.

## License

No open-source license has been selected yet. Until a license is added, the source code remains subject to the author's default copyright; public visibility alone does not grant permission to redistribute or modify it.
