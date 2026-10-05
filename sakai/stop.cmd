@echo off
setlocal EnableExtensions
cd /d "%~dp0"
call "%~dp0env.cmd"
if errorlevel 1 exit /b 1

set "FOUND=0"
%SystemRoot%\System32\netstat.exe -ano | %SystemRoot%\System32\findstr.exe /R /C:":8005 .*LISTENING" >nul 2>&1
if not errorlevel 1 set "FOUND=1"
%SystemRoot%\System32\netstat.exe -ano | %SystemRoot%\System32\findstr.exe /R /C:":8080 .*LISTENING" >nul 2>&1
if not errorlevel 1 set "FOUND=1"

if "%FOUND%"=="0" (
  echo Tomcat is not running ^(ports 8080 and 8005 are free^).
) else (
  echo Stopping Tomcat ...
  if exist "%CATALINA_HOME%\bin\shutdown.bat" call "%CATALINA_HOME%\bin\shutdown.bat"
  %SystemRoot%\System32\timeout.exe /t 5 /nobreak >nul

  %SystemRoot%\System32\netstat.exe -ano | %SystemRoot%\System32\findstr.exe /R /C:":8080 .*LISTENING" >nul 2>&1
  if not errorlevel 1 (
    echo Tomcat still listening on 8080. Forcing stop ...
    for /f "tokens=5" %%P in ('%SystemRoot%\System32\netstat.exe -ano ^| %SystemRoot%\System32\findstr.exe /R /C:":8080 .*LISTENING"') do (
      %SystemRoot%\System32\taskkill.exe /F /PID %%P >nul 2>&1
    )
  )
  %SystemRoot%\System32\netstat.exe -ano | %SystemRoot%\System32\findstr.exe /R /C:":8005 .*LISTENING" >nul 2>&1
  if not errorlevel 1 (
    for /f "tokens=5" %%P in ('%SystemRoot%\System32\netstat.exe -ano ^| %SystemRoot%\System32\findstr.exe /R /C:":8005 .*LISTENING"') do (
      %SystemRoot%\System32\taskkill.exe /F /PID %%P >nul 2>&1
    )
  )
)

docker info >nul 2>&1
if errorlevel 1 (
  echo Docker is not running. Databases could not be stopped.
  exit /b 0
)

echo Stopping MariaDB container sakai-mariadb ...
docker inspect sakai-mariadb >nul 2>&1
if errorlevel 1 (
  echo MariaDB container does not exist.
) else (
  docker stop sakai-mariadb >nul
  if errorlevel 1 (
    echo docker stop sakai-mariadb failed. Try: docker ps -a
    exit /b 1
  )
)

echo Stopping MongoDB container sakai-mongodb ...
docker inspect sakai-mongodb >nul 2>&1
if errorlevel 1 (
  echo MongoDB container does not exist.
) else (
  docker stop sakai-mongodb >nul
  if errorlevel 1 (
    echo docker stop sakai-mongodb failed. Try: docker ps -a
    exit /b 1
  )
)

echo Stopping Neo4j container sakai-neo4j ...
docker inspect sakai-neo4j >nul 2>&1
if errorlevel 1 (
  echo Neo4j container does not exist.
) else (
  docker stop sakai-neo4j >nul
  if errorlevel 1 (
    echo docker stop sakai-neo4j failed. Try: docker ps -a
    exit /b 1
  )
)

echo Done. Tomcat, MariaDB, MongoDB, and Neo4j are stopped.
exit /b 0
