@echo off
setlocal
cd /d "%~dp0"

echo ============================================================
echo  HAP PHYSICAL WORKBENCH
echo ============================================================
echo.
echo Starting the guided physical-test menu...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PHYSICAL_WORKBENCH_MENU.ps1" -WorkbenchDir "%~dp0"

set HAP_EXIT=%ERRORLEVEL%
echo.
if "%HAP_EXIT%"=="0" (
  echo HAP Physical Workbench closed normally.
) else (
  echo HAP Physical Workbench returned exit code %HAP_EXIT%.
)
echo.
pause
exit /b %HAP_EXIT%
