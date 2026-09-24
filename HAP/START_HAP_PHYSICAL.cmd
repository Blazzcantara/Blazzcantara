@echo off
setlocal
cd /d "%~dp0"

echo ============================================================
echo  HAP PHYSICAL WORKBENCH
echo ============================================================
echo.
echo Enter the full path to your local lego-umbau.zip archive.
echo Example: C:\Users\Name\Downloads\lego-umbau.zip
echo.
set /p HAP_ARCHIVE=Archive path: 

if "%HAP_ARCHIVE%"=="" (
  echo ERROR: No archive path entered.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN_PHYSICAL_CAMPAIGN.ps1" ^
  -ArchivePath "%HAP_ARCHIVE%" ^
  -WorkDir "%~dp0WORK"

set HAP_EXIT=%ERRORLEVEL%
echo.
if "%HAP_EXIT%"=="0" (
  echo Workbench finished without a script error.
) else (
  echo Workbench returned exit code %HAP_EXIT%.
)
echo.
echo Working data is stored in:
echo   %~dp0WORK
echo.
pause
exit /b %HAP_EXIT%
