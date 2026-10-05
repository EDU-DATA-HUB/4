@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "FORCE=0"
if /i "%~1"=="/force" set "FORCE=1"
if /i "%~1"=="-force" set "FORCE=1"

set "REPO_ROOT=%~dp0"
if "%REPO_ROOT:~-1%"=="\" set "REPO_ROOT=%REPO_ROOT:~0,-1%"
set "RUNTIME_DIR=%REPO_ROOT%\.runtime"
set "KIT=%REPO_ROOT%\offline-kit"
set "DL=%RUNTIME_DIR%\downloads"
set "STAGING=%RUNTIME_DIR%\tmp\setup-staging"

where 7z >nul 2>&1
if errorlevel 1 (
  if exist "%ProgramFiles%\7-Zip\7z.exe" (
    set "SEVEN=%ProgramFiles%\7-Zip\7z.exe"
  ) else (
    echo 7-Zip ^(7z^) is required. Install 7-Zip or add 7z to PATH, then run setup.cmd again.
    exit /b 1
  )
) else (
  set "SEVEN=7z"
)

docker info >nul 2>&1
if errorlevel 1 (
  echo Docker is not running. Install/start Docker Desktop, then run setup.cmd again.
  exit /b 1
)

if not exist "%KIT%" (
  echo Missing folder: %KIT%
  exit /b 1
)

call :require_kit 01-tools.zip
if errorlevel 1 exit /b 1
call :require_kit 02-docker-images.zip
if errorlevel 1 exit /b 1
call :require_kit 03-m2-repo.7z
if errorlevel 1 exit /b 1
call :require_kit 04-tomcat-sakai.7z
if errorlevel 1 exit /b 1

if exist "%RUNTIME_DIR%\jdk\jdk-17.0.20.1+1\bin\java.exe" if "%FORCE%"=="0" (
  if exist "%RUNTIME_DIR%\maven\apache-maven-3.9.9\bin\mvn.cmd" (
    if exist "%RUNTIME_DIR%\tomcat\apache-tomcat-9.0.122\bin\startup.bat" (
      if exist "%RUNTIME_DIR%\m2" (
        if exist "%DL%\mariadb-10.11.tar" (
          echo Runtime already looks set up. Use setup.cmd /force to overwrite.
          echo Next: start.cmd
          exit /b 0
        )
      )
    )
  )
)

echo Setting up runtime under %RUNTIME_DIR% from offline-kit\ ...
if not exist "%RUNTIME_DIR%" mkdir "%RUNTIME_DIR%"
if not exist "%DL%" mkdir "%DL%"
if not exist "%RUNTIME_DIR%\jdk" mkdir "%RUNTIME_DIR%\jdk"
if not exist "%RUNTIME_DIR%\maven" mkdir "%RUNTIME_DIR%\maven"
if not exist "%RUNTIME_DIR%\tomcat" mkdir "%RUNTIME_DIR%\tomcat"
if not exist "%RUNTIME_DIR%\m2" mkdir "%RUNTIME_DIR%\m2"
if not exist "%RUNTIME_DIR%\data\mysql" mkdir "%RUNTIME_DIR%\data\mysql"
if not exist "%RUNTIME_DIR%\data\mongodb" mkdir "%RUNTIME_DIR%\data\mongodb"
if not exist "%RUNTIME_DIR%\data\neo4j" mkdir "%RUNTIME_DIR%\data\neo4j"

if exist "%STAGING%" rmdir /s /q "%STAGING%"
mkdir "%STAGING%"

echo [1/4] Extracting tools ...
call :kit_extract 01-tools.zip "%STAGING%\tools"
if errorlevel 1 exit /b 1
if "%FORCE%"=="1" (
  if exist "%RUNTIME_DIR%\jdk\jdk-17.0.20.1+1" rmdir /s /q "%RUNTIME_DIR%\jdk\jdk-17.0.20.1+1"
  if exist "%RUNTIME_DIR%\maven\apache-maven-3.9.9" rmdir /s /q "%RUNTIME_DIR%\maven\apache-maven-3.9.9"
  if exist "%RUNTIME_DIR%\tomcat\apache-tomcat-9.0.122" rmdir /s /q "%RUNTIME_DIR%\tomcat\apache-tomcat-9.0.122"
)
"%SEVEN%" x -y -o"%RUNTIME_DIR%\jdk" "%STAGING%\tools\jdk17.zip" >nul
if errorlevel 1 (
  echo Failed to extract jdk17.zip
  exit /b 1
)
"%SEVEN%" x -y -o"%RUNTIME_DIR%\maven" "%STAGING%\tools\maven.zip" >nul
if errorlevel 1 (
  echo Failed to extract maven.zip
  exit /b 1
)
"%SEVEN%" x -y -o"%RUNTIME_DIR%\tomcat" "%STAGING%\tools\tomcat.zip" >nul
if errorlevel 1 (
  echo Failed to extract tomcat.zip
  exit /b 1
)

echo [2/4] Extracting Docker image tars ...
call :kit_extract 02-docker-images.zip "%DL%"
if errorlevel 1 exit /b 1

echo [3/4] Extracting Maven repo ^(can take a while^) ...
if "%FORCE%"=="1" if exist "%RUNTIME_DIR%\m2" (
  rmdir /s /q "%RUNTIME_DIR%\m2"
  mkdir "%RUNTIME_DIR%\m2"
)
call :kit_extract 03-m2-repo.7z "%RUNTIME_DIR%\m2"
if errorlevel 1 exit /b 1

echo [4/4] Applying deployed Sakai onto Tomcat ...
set "TC=%RUNTIME_DIR%\tomcat\apache-tomcat-9.0.122"
if not exist "%TC%\bin\startup.bat" (
  echo Vanilla Tomcat missing at %TC%
  exit /b 1
)
call :kit_extract 04-tomcat-sakai.7z "%TC%"
if errorlevel 1 exit /b 1

rmdir /s /q "%STAGING%" 2>nul

echo.
call "%REPO_ROOT%\env.cmd"
if errorlevel 1 (
  echo setup finished but env.cmd reported a problem. Check paths above.
  exit /b 1
)

echo.
echo Setup complete.
echo Next:
echo   start.cmd
echo   ^(optional^) create-p12-demo.cmd for certificate login
echo   ^(optional^) build.cmd after code changes
exit /b 0

:require_kit
set "NAME=%~1"
if exist "%KIT%\%NAME%" exit /b 0
if exist "%KIT%\%NAME%.001" exit /b 0
echo Missing offline-kit\%NAME% ^(or %NAME%.001^)
echo This file must be in the repository. Run pack-offline-kit.cmd on a built machine, then commit offline-kit\.
exit /b 1

:kit_extract
set "NAME=%~1"
set "OUT=%~2"
if exist "%KIT%\%NAME%.001" (
  "%SEVEN%" x -y -o"%OUT%" "%KIT%\%NAME%.001" >nul
) else if exist "%KIT%\%NAME%" (
  "%SEVEN%" x -y -o"%OUT%" "%KIT%\%NAME%" >nul
) else (
  echo Missing %KIT%\%NAME%
  exit /b 1
)
if errorlevel 1 (
  echo Failed to extract %NAME%
  exit /b 1
)
exit /b 0
