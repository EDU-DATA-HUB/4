@echo off
rem Call from repo root:  call env.cmd
set "REPO_ROOT=%~dp0"
if "%REPO_ROOT:~-1%"=="\" set "REPO_ROOT=%REPO_ROOT:~0,-1%"
set "RUNTIME_DIR=%REPO_ROOT%\.runtime"
set "JAVA_HOME=%RUNTIME_DIR%\jdk\jdk-17.0.20.1+1"
set "MAVEN_HOME=%RUNTIME_DIR%\maven\apache-maven-3.9.9"
set "CATALINA_HOME=%RUNTIME_DIR%\tomcat\apache-tomcat-9.0.122"
set "CATALINA_BASE=%CATALINA_HOME%"
set "SAKAI_HOME=%CATALINA_HOME%\sakai"
set "M2_REPO=%RUNTIME_DIR%\m2"
if not defined MAVEN_OPTS set "MAVEN_OPTS=-Xms512m -Xmx2048m -Djava.awt.headless=true"

rem Git Bash puts GNU timeout ahead of Windows timeout; keep System32 and this JDK first.
set "PATH=%SystemRoot%\System32;%SystemRoot%\System32\Wbem;%JAVA_HOME%\bin;%MAVEN_HOME%\bin;%PATH%"

if not exist "%JAVA_HOME%\bin\java.exe" (
  echo Missing JDK: %JAVA_HOME%\bin\java.exe
  exit /b 1
)
if not exist "%MAVEN_HOME%\bin\mvn.cmd" (
  echo Missing Maven: %MAVEN_HOME%\bin\mvn.cmd
  exit /b 1
)
if not exist "%CATALINA_HOME%\bin\startup.bat" (
  echo Missing Tomcat: %CATALINA_HOME%
  exit /b 1
)

if not exist "%M2_REPO%" mkdir "%M2_REPO%"
if not exist "%SAKAI_HOME%" mkdir "%SAKAI_HOME%"
if not exist "%CATALINA_HOME%\components" mkdir "%CATALINA_HOME%\components"
if not exist "%CATALINA_HOME%\shared\lib" mkdir "%CATALINA_HOME%\shared\lib"

echo REPO_ROOT=%REPO_ROOT%
echo JAVA_HOME=%JAVA_HOME%
echo MAVEN_HOME=%MAVEN_HOME%
echo CATALINA_HOME=%CATALINA_HOME%
echo M2_REPO=%M2_REPO%
"%JAVA_HOME%\bin\java.exe" -version
call "%MAVEN_HOME%\bin\mvn.cmd" -version
exit /b 0
