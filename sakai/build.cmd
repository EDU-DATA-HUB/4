@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
call "%~dp0env.cmd"
if errorlevel 1 exit /b 1

set "FRONTEND=%REPO_ROOT%\webcomponents\tool\src\main\frontend"
set "NODE_BIN=%REPO_ROOT%\webcomponents\tool\target\node"
set "SKIP_NPM=false"

if not exist "C:\sakaife" (
  echo Creating short path C:\sakaife for npm ...
  mklink /J "C:\sakaife" "%FRONTEND%"
)

if exist "%NODE_BIN%\node.exe" (
  set "PATH=%NODE_BIN%;%PATH%"
  if not exist "%FRONTEND%\node_modules\esbuild" (
    echo Running npm ci via C:\sakaife ...
    pushd "C:\sakaife"
    call npm.cmd ci --no-fund
    if errorlevel 1 (
      popd
      echo npm ci failed.
      exit /b 1
    )
    popd
  )
  dir /b "%FRONTEND%\bundles" >nul 2>&1
  if errorlevel 1 (
    echo Running npm run bundle ...
    pushd "C:\sakaife"
    call npm.cmd run bundle
    if errorlevel 1 (
      popd
      echo npm bundle failed.
      exit /b 1
    )
    popd
  )
  set "SKIP_NPM=true"
) else (
  echo Bundled Node not found yet. Maven will try to install Node ^(needs network on first frontend build^).
)

echo Building master POM ...
call "%MAVEN_HOME%\bin\mvn.cmd" -Dmaven.repo.local="%M2_REPO%" -DskipTests clean install -f "%REPO_ROOT%\master\pom.xml"
if errorlevel 1 exit /b 1

echo Building and deploying Sakai ...
set "MVN_EXTRA="
if "%SKIP_NPM%"=="true" set "MVN_EXTRA=-Dsakai.skip.webcomponents.npm=true"

call "%MAVEN_HOME%\bin\mvn.cmd" -Dmaven.repo.local="%M2_REPO%" -DskipTests -Dsakai.skip.webcomponents.tests=true -Dmaven.tomcat.home="%CATALINA_HOME%" -Dsakai.home="%SAKAI_HOME%" %MVN_EXTRA% clean install sakai:deploy
if errorlevel 1 exit /b 1

echo Build + deploy finished. Start with start.cmd
exit /b 0
