@echo off
setlocal

:: Check for Visual C++ Runtime by looking for a required DLL
where /q vcruntime140.dll
if %errorlevel% neq 0 goto :missing_vcredist

:: Launch the app from the same directory as this script
start "" "%~dp0banana_split_flutter.exe"
exit /b 0

:missing_vcredist
echo.
echo  Visual C++ Runtime is not installed.
echo  Banana Split requires the Microsoft Visual C++ Redistributable to run.
echo.
set /p INSTALL="  Would you like to download and install it now? (Y/N): "
if /i "%INSTALL%" neq "Y" (
    echo.
    echo  You can install it manually from:
    echo  https://aka.ms/vs/17/release/vc_redist.x64.exe
    echo.
    pause
    exit /b 1
)

echo.
echo  Downloading Visual C++ Redistributable...
powershell -Command "Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile '%TEMP%\vc_redist.x64.exe'"
if %errorlevel% neq 0 (
    echo.
    echo  Download failed. Please install manually from:
    echo  https://aka.ms/vs/17/release/vc_redist.x64.exe
    echo.
    pause
    exit /b 1
)

echo  Installing... (you may see a UAC prompt)
start /wait "" "%TEMP%\vc_redist.x64.exe" /install /quiet /norestart
if %errorlevel% neq 0 (
    echo.
    echo  Installation may require administrator privileges.
    echo  Retrying with elevation...
    powershell -Command "Start-Process '%TEMP%\vc_redist.x64.exe' -ArgumentList '/install /quiet /norestart' -Verb RunAs -Wait"
)

del "%TEMP%\vc_redist.x64.exe" 2>nul

echo  Done! Launching Banana Split...
start "" "%~dp0banana_split_flutter.exe"
exit /b 0
