@echo off
setlocal
cd /d "%~dp0"

echo [BLZOOM] Creating build environment...
if not exist ".venv-build\Scripts\python.exe" (
    py -3 -m venv .venv-build
    if errorlevel 1 goto :error
)

echo [BLZOOM] Installing dependencies...
".venv-build\Scripts\python.exe" -m pip install --upgrade pip
if errorlevel 1 goto :error
".venv-build\Scripts\python.exe" -m pip install -r requirements-build.txt
if errorlevel 1 goto :error

echo [BLZOOM] Building Windows executable...
".venv-build\Scripts\python.exe" -m PyInstaller --noconfirm --clean --onefile --windowed --name BLZOOM --collect-all dxcam --collect-all PySide6 --collect-all pynput --collect-all psutil --hidden-import pynput.keyboard._win32 --hidden-import pynput.mouse._win32 blzoom.py
if errorlevel 1 goto :error

echo.
echo Build complete: dist\BLZOOM.exe
pause
exit /b 0

:error
echo.
echo Build failed. Check the error above.
pause
exit /b 1
