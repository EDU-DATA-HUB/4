@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "REPO_ROOT=%~dp0"
if "%REPO_ROOT:~-1%"=="\" set "REPO_ROOT=%REPO_ROOT:~0,-1%"
set "LOG=%REPO_ROOT%\.runtime\tomcat\apache-tomcat-9.0.122\logs\catalina.out"

echo Following %LOG%
echo Colors: ERROR red, WARN yellow, INFO cyan, Server startup green
echo Wait for: Server startup in
echo Ctrl+C stops this window only. Tomcat keeps running. Use stop.cmd to stop it.
echo.

if not exist "%LOG%" (
  echo Log file not created yet. Start the project with start.cmd in another window.
  echo Waiting for the file ...
)
:wait_log
if not exist "%LOG%" (
  %SystemRoot%\System32\timeout.exe /t 1 /nobreak >nul
  goto wait_log
)

if not exist "%~dp0logs.ps1" (
  echo Missing logs.ps1
  exit /b 1
)
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0logs.ps1" "%LOG%"
exit /b %ERRORLEVEL%
