@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
call "%~dp0env.cmd"
if errorlevel 1 exit /b 1

set "KIT=%REPO_ROOT%\offline-kit"
set "DL=%RUNTIME_DIR%\downloads"
set "TC=%CATALINA_HOME%"
set "STAGING=%RUNTIME_DIR%\tmp\pack-staging"
rem GitHub rejects files over 100MB; keep each volume under that.
set "VOL=90m"

where 7z >nul 2>&1
if errorlevel 1 (
  if exist "%ProgramFiles%\7-Zip\7z.exe" (
    set "SEVEN=%ProgramFiles%\7-Zip\7z.exe"
  ) else (
    echo 7-Zip ^(7z^) is required to pack m2 and Tomcat. Install 7-Zip or add 7z to PATH.
    exit /b 1
  )
) else (
  set "SEVEN=7z"
)

for %%F in (jdk17.zip maven.zip tomcat.zip mariadb-10.11.tar mongo-7.tar neo4j-4.0.tar) do (
  if not exist "%DL%\%%F" (
    echo Missing %DL%\%%F
    exit /b 1
  )
)
if not exist "%RUNTIME_DIR%\m2" (
  echo Missing Maven repo: %RUNTIME_DIR%\m2
  exit /b 1
)
if not exist "%TC%\webapps\portal.war" if not exist "%TC%\webapps\portal\" (
  echo Sakai does not look deployed under %TC%\webapps
  echo Run build.cmd first, then pack again.
  exit /b 1
)

echo Creating %KIT% ^(split volumes ^<= %VOL% for GitHub^) ...
if not exist "%KIT%" mkdir "%KIT%"
if exist "%STAGING%" rmdir /s /q "%STAGING%"
mkdir "%STAGING%\tools"
mkdir "%STAGING%\docker"
mkdir "%STAGING%\tomcat-sakai"

del /f /q "%KIT%\01-tools.zip" "%KIT%\01-tools.zip.*" 2>nul
del /f /q "%KIT%\02-docker-images.zip" "%KIT%\02-docker-images.zip.*" 2>nul
del /f /q "%KIT%\03-m2-repo.7z" "%KIT%\03-m2-repo.7z.*" 2>nul
del /f /q "%KIT%\04-tomcat-sakai.7z" "%KIT%\04-tomcat-sakai.7z.*" 2>nul

echo [1/4] 01-tools.zip ...
copy /y "%DL%\jdk17.zip" "%STAGING%\tools\" >nul
copy /y "%DL%\maven.zip" "%STAGING%\tools\" >nul
copy /y "%DL%\tomcat.zip" "%STAGING%\tools\" >nul
"%SEVEN%" a -tzip -mx=1 -v%VOL% "%KIT%\01-tools.zip" "%STAGING%\tools\*" >nul
if errorlevel 1 (
  echo Failed to create 01-tools.zip
  exit /b 1
)

echo [2/4] 02-docker-images.zip ...
copy /y "%DL%\mariadb-10.11.tar" "%STAGING%\docker\" >nul
copy /y "%DL%\mongo-7.tar" "%STAGING%\docker\" >nul
copy /y "%DL%\neo4j-4.0.tar" "%STAGING%\docker\" >nul
"%SEVEN%" a -tzip -mx=1 -v%VOL% "%KIT%\02-docker-images.zip" "%STAGING%\docker\*" >nul
if errorlevel 1 (
  echo Failed to create 02-docker-images.zip
  exit /b 1
)

echo [3/4] 03-m2-repo.7z ^(this can take a long time^) ...
"%SEVEN%" a -t7z -mx=7 -mmt=on -v%VOL% "%KIT%\03-m2-repo.7z" "%RUNTIME_DIR%\m2\*" >nul
if errorlevel 1 (
  echo Failed to create 03-m2-repo.7z
  exit /b 1
)

echo [4/4] 04-tomcat-sakai.7z ...
robocopy "%TC%\webapps" "%STAGING%\tomcat-sakai\webapps" /E /NFL /NDL /NJH /NJS /nc /ns /np >nul
robocopy "%TC%\components" "%STAGING%\tomcat-sakai\components" /E /NFL /NDL /NJH /NJS /nc /ns /np >nul
robocopy "%TC%\lib" "%STAGING%\tomcat-sakai\lib" /E /NFL /NDL /NJH /NJS /nc /ns /np >nul
if exist "%TC%\sakai" robocopy "%TC%\sakai" "%STAGING%\tomcat-sakai\sakai" /E /NFL /NDL /NJH /NJS /nc /ns /np >nul
"%SEVEN%" a -t7z -mx=7 -mmt=on -v%VOL% "%KIT%\04-tomcat-sakai.7z" "%STAGING%\tomcat-sakai\*" >nul
if errorlevel 1 (
  echo Failed to create 04-tomcat-sakai.7z
  exit /b 1
)

echo Writing MANIFEST.txt ...
(
  echo offline-kit manifest
  echo created=%DATE% %TIME%
  echo repo=%REPO_ROOT%
  echo volume_size=%VOL%
  echo.
) > "%KIT%\MANIFEST.txt"
for %%F in ("%KIT%\01-tools.zip" "%KIT%\01-tools.zip.*" "%KIT%\02-docker-images.zip" "%KIT%\02-docker-images.zip.*" "%KIT%\03-m2-repo.7z" "%KIT%\03-m2-repo.7z.*" "%KIT%\04-tomcat-sakai.7z" "%KIT%\04-tomcat-sakai.7z.*") do (
  if exist %%~fF (
    set "SZ=%%~zF"
    set "HASH="
    for /f "skip=1 tokens=*" %%H in ('certutil -hashfile "%%~fF" SHA256 ^| findstr /v /c:":" /c:"CertUtil"') do if not defined HASH set "HASH=%%H"
    echo %%~nxF  size=!SZ!  sha256=!HASH!>> "%KIT%\MANIFEST.txt"
  )
)

rmdir /s /q "%STAGING%" 2>nul

echo.
echo Offline kit ready in %KIT%
echo Commit offline-kit\ into git ^(parts are split for GitHub's 100MB limit^).
dir /n "%KIT%\01-tools.zip*" "%KIT%\02-docker-images.zip*" "%KIT%\03-m2-repo.7z*" "%KIT%\04-tomcat-sakai.7z*"
echo.
echo Users: download/clone this repo, then setup.cmd then start.cmd
exit /b 0
