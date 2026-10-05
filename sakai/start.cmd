@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
call "%~dp0env.cmd"
if errorlevel 1 exit /b 1

if not exist "%CATALINA_HOME%\webapps\portal.war" if not exist "%CATALINA_HOME%\webapps\portal\" (
  echo Sakai is not deployed yet. Run build.cmd first.
  exit /b 1
)

%SystemRoot%\System32\netstat.exe -ano | %SystemRoot%\System32\findstr.exe /R /C:":8080 .*LISTENING" >nul 2>&1
if not errorlevel 1 (
  echo Port 8080 is already in use. A Tomcat is probably running.
  echo Run stop.cmd first. A second instance breaks Ignite and port 8005.
  exit /b 1
)
%SystemRoot%\System32\netstat.exe -ano | %SystemRoot%\System32\findstr.exe /R /C:":8005 .*LISTENING" >nul 2>&1
if not errorlevel 1 (
  echo Port 8005 is already in use ^(Tomcat shutdown port^). Run stop.cmd first.
  exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
  echo Docker is not running. Start Docker Desktop, then run start.cmd again.
  exit /b 1
)

if not exist "%RUNTIME_DIR%\data\mysql" mkdir "%RUNTIME_DIR%\data\mysql"

docker image inspect mariadb:10.11 >nul 2>&1
if errorlevel 1 (
  set "TAR=%RUNTIME_DIR%\downloads\mariadb-10.11.tar"
  if not exist "!TAR!" (
    echo Missing MariaDB image mariadb:10.11 and missing !TAR!
    echo Copy mariadb-10.11.tar into .runtime\downloads\ with this project.
    exit /b 1
  )
  echo Loading bundled image !TAR! ...
  docker load -i "!TAR!"
  if errorlevel 1 (
    echo docker load failed.
    exit /b 1
  )
)

docker inspect sakai-mariadb >nul 2>&1
if errorlevel 1 (
  echo Creating MariaDB container sakai-mariadb ...
  docker run -d --name sakai-mariadb -p 127.0.0.1:3306:3306 -e MARIADB_ROOT_PASSWORD=sakairoot -e MARIADB_DATABASE=sakai -e MARIADB_USER=sakai -e MARIADB_PASSWORD=ironchef -v "%RUNTIME_DIR%\data\mysql:/var/lib/mysql" mariadb:10.11 --lower-case-table-names=1 --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
  if errorlevel 1 (
    docker inspect sakai-mariadb >nul 2>&1
    if not errorlevel 1 (
      echo Container name already exists. Starting sakai-mariadb ...
      docker start sakai-mariadb
      if errorlevel 1 (
        echo docker start failed. Try: docker logs sakai-mariadb
        exit /b 1
      )
    ) else (
      echo Failed to create MariaDB. Is port 3306 free? Is Docker Desktop running?
      echo Try: docker ps -a
      exit /b 1
    )
  )
) else (
  echo Starting existing container sakai-mariadb ...
  docker start sakai-mariadb >nul
  if errorlevel 1 (
    echo docker start failed. Try: docker logs sakai-mariadb
    exit /b 1
  )
)

echo Waiting for MariaDB ...
set /a COUNT=0
:wait_db
docker exec sakai-mariadb mariadb-admin ping -uroot -psakairoot --silent >nul 2>&1
if not errorlevel 1 goto db_ready
set /a COUNT+=1
if %COUNT% GEQ 60 (
  echo MariaDB did not become ready. Try: docker logs sakai-mariadb
  exit /b 1
)
%SystemRoot%\System32\timeout.exe /t 2 /nobreak >nul
goto wait_db

:db_ready
docker exec sakai-mariadb mariadb -uroot -psakairoot -e "CREATE DATABASE IF NOT EXISTS sakai DEFAULT CHARACTER SET utf8mb4; CREATE USER IF NOT EXISTS 'sakai'@'%%' IDENTIFIED BY 'ironchef'; CREATE USER IF NOT EXISTS 'sakai'@'localhost' IDENTIFIED BY 'ironchef'; GRANT ALL PRIVILEGES ON sakai.* TO 'sakai'@'%%'; GRANT ALL PRIVILEGES ON sakai.* TO 'sakai'@'localhost'; FLUSH PRIVILEGES;" >nul 2>&1
echo MariaDB is ready on 127.0.0.1:3306  user=sakai  password=ironchef  db=sakai

if not exist "%RUNTIME_DIR%\data\mongodb" mkdir "%RUNTIME_DIR%\data\mongodb"

docker image inspect mongo:7 >nul 2>&1
if errorlevel 1 (
  set "MONGO_TAR=%RUNTIME_DIR%\downloads\mongo-7.tar"
  if not exist "!MONGO_TAR!" (
    echo Missing MongoDB image mongo:7 and missing !MONGO_TAR!
    echo Copy mongo-7.tar into .runtime\downloads\ with this project ^(same as MariaDB^).
    exit /b 1
  )
  echo Loading bundled image !MONGO_TAR! ...
  docker load -i "!MONGO_TAR!"
  if errorlevel 1 (
    echo docker load for mongo:7 failed.
    exit /b 1
  )
)

docker inspect sakai-mongodb >nul 2>&1
if errorlevel 1 (
  echo Creating MongoDB container sakai-mongodb ...
  docker run -d --name sakai-mongodb -p 127.0.0.1:27017:27017 -v "%RUNTIME_DIR%\data\mongodb:/data/db" mongo:7
  if errorlevel 1 (
    docker inspect sakai-mongodb >nul 2>&1
    if not errorlevel 1 (
      echo Container name already exists. Starting sakai-mongodb ...
      docker start sakai-mongodb
      if errorlevel 1 (
        echo docker start sakai-mongodb failed. Try: docker logs sakai-mongodb
        exit /b 1
      )
    ) else (
      echo Failed to create MongoDB. Is port 27017 free?
      exit /b 1
    )
  )
) else (
  echo Starting existing container sakai-mongodb ...
  docker start sakai-mongodb >nul
  if errorlevel 1 (
    echo docker start sakai-mongodb failed. Try: docker logs sakai-mongodb
    exit /b 1
  )
)

echo Waiting for MongoDB ...
set /a MCOUNT=0
:wait_mongo
docker exec sakai-mongodb mongosh --quiet --eval "db.runCommand({ ping: 1 }).ok" >nul 2>&1
if not errorlevel 1 goto mongo_ready
set /a MCOUNT+=1
if %MCOUNT% GEQ 60 (
  echo MongoDB did not become ready. Try: docker logs sakai-mongodb
  exit /b 1
)
%SystemRoot%\System32\timeout.exe /t 2 /nobreak >nul
goto wait_mongo

:mongo_ready
echo MongoDB is ready on 127.0.0.1:27017  db=sakai  collection=login_history

if not exist "%RUNTIME_DIR%\data\neo4j" mkdir "%RUNTIME_DIR%\data\neo4j"

docker image inspect neo4j:4.0 >nul 2>&1
if errorlevel 1 (
  set "NEO_TAR=%RUNTIME_DIR%\downloads\neo4j-4.0.tar"
  if not exist "!NEO_TAR!" (
    echo Missing Neo4j image neo4j:4.0 and missing !NEO_TAR!
    echo Copy neo4j-4.0.tar into .runtime\downloads\ with this project ^(same as MariaDB^).
    exit /b 1
  )
  echo Loading bundled image !NEO_TAR! ...
  docker load -i "!NEO_TAR!"
  if errorlevel 1 (
    echo docker load for neo4j:4.0 failed.
    exit /b 1
  )
)

docker inspect sakai-neo4j >nul 2>&1
if errorlevel 1 (
  echo Creating Neo4j container sakai-neo4j ...
  docker run -d --name sakai-neo4j -p 127.0.0.1:7474:7474 -p 127.0.0.1:7687:7687 -e NEO4J_AUTH=neo4j/sakai -v "%RUNTIME_DIR%\data\neo4j:/data" neo4j:4.0
  if errorlevel 1 (
    docker inspect sakai-neo4j >nul 2>&1
    if not errorlevel 1 (
      echo Container name already exists. Starting sakai-neo4j ...
      docker start sakai-neo4j
      if errorlevel 1 (
        echo docker start sakai-neo4j failed. Try: docker logs sakai-neo4j
        exit /b 1
      )
    ) else (
      echo Failed to create Neo4j. Are ports 7474 and 7687 free?
      exit /b 1
    )
  )
) else (
  echo Starting existing container sakai-neo4j ...
  docker start sakai-neo4j >nul
  if errorlevel 1 (
    echo docker start sakai-neo4j failed. Try: docker logs sakai-neo4j
    exit /b 1
  )
)

echo Waiting for Neo4j ...
set /a NCOUNT=0
:wait_neo
docker exec sakai-neo4j cypher-shell -u neo4j -p sakai "RETURN 1;" >nul 2>&1
if not errorlevel 1 goto neo_ready
set /a NCOUNT+=1
if %NCOUNT% GEQ 60 (
  echo Neo4j did not become ready. Try: docker logs sakai-neo4j
  exit /b 1
)
%SystemRoot%\System32\timeout.exe /t 2 /nobreak >nul
goto wait_neo

:neo_ready
echo Neo4j 4.0 is ready  http://127.0.0.1:7474  bolt://127.0.0.1:7687  user=neo4j  password=sakai
echo ^(Neo4j is started only; Sakai does not use it yet.^)

echo Starting Tomcat at %CATALINA_HOME%
call "%CATALINA_HOME%\bin\startup.bat"
if errorlevel 1 (
  echo Tomcat startup.bat failed.
  exit /b 1
)
echo.
echo Logs: run logs.cmd   (or %CATALINA_HOME%\logs\catalina.out)
echo URL:  http://localhost:8080/portal
echo Login: admin / admin
echo Wait until catalina.out contains: Server startup in
echo Do not run start.cmd again until you have run stop.cmd
exit /b 0
