@echo off
setlocal EnableExtensions
cd /d "%~dp0"
call "%~dp0env.cmd"
if errorlevel 1 exit /b 1

set "SAKAI_DIR=%SAKAI_HOME%"
if not exist "%SAKAI_DIR%" mkdir "%SAKAI_DIR%"
set "DEMO_DIR=%RUNTIME_DIR%\p12-demo"
if not exist "%DEMO_DIR%" mkdir "%DEMO_DIR%"

set "KEYTOOL=%JAVA_HOME%\bin\keytool.exe"
set "CA_KEYSTORE=%DEMO_DIR%\demo-ca.jks"
set "TRUSTSTORE=%SAKAI_DIR%\p12-trust.jks"
set "USER_P12=%DEMO_DIR%\admin.p12"
set "PASS=changeit"

echo Creating demo CA and admin.p12 ^(CN=admin^) ...

if exist "%CA_KEYSTORE%" del /f /q "%CA_KEYSTORE%"
if exist "%TRUSTSTORE%" del /f /q "%TRUSTSTORE%"
if exist "%USER_P12%" del /f /q "%USER_P12%"
if exist "%DEMO_DIR%\demo-ca.cer" del /f /q "%DEMO_DIR%\demo-ca.cer"
if exist "%DEMO_DIR%\admin.cer" del /f /q "%DEMO_DIR%\admin.cer"
if exist "%DEMO_DIR%\admin-signed.cer" del /f /q "%DEMO_DIR%\admin-signed.cer"
if exist "%DEMO_DIR%\admin-chain.p12" del /f /q "%DEMO_DIR%\admin-chain.p12"

"%KEYTOOL%" -genkeypair -alias democa -keyalg RSA -keysize 2048 -validity 3650 -keystore "%CA_KEYSTORE%" -storepass %PASS% -keypass %PASS% -dname "CN=Sakai Demo CA,O=Sakai Local,C=US" -ext bc:c
if errorlevel 1 exit /b 1

"%KEYTOOL%" -exportcert -alias democa -keystore "%CA_KEYSTORE%" -storepass %PASS% -file "%DEMO_DIR%\demo-ca.cer"
if errorlevel 1 exit /b 1

"%KEYTOOL%" -importcert -noprompt -alias democa -file "%DEMO_DIR%\demo-ca.cer" -keystore "%TRUSTSTORE%" -storepass %PASS%
if errorlevel 1 exit /b 1

"%KEYTOOL%" -genkeypair -alias admin -keyalg RSA -keysize 2048 -validity 825 -keystore "%USER_P12%" -storetype PKCS12 -storepass %PASS% -keypass %PASS% -dname "CN=admin,O=Sakai Local,C=US"
if errorlevel 1 exit /b 1

"%KEYTOOL%" -certreq -alias admin -keystore "%USER_P12%" -storetype PKCS12 -storepass %PASS% -file "%DEMO_DIR%\admin.csr"
if errorlevel 1 exit /b 1

"%KEYTOOL%" -gencert -alias democa -keystore "%CA_KEYSTORE%" -storepass %PASS% -infile "%DEMO_DIR%\admin.csr" -outfile "%DEMO_DIR%\admin-signed.cer" -validity 825 -ext ku:c=digitalSignature,keyEncipherment
if errorlevel 1 exit /b 1

"%KEYTOOL%" -importcert -noprompt -alias democa -file "%DEMO_DIR%\demo-ca.cer" -keystore "%USER_P12%" -storetype PKCS12 -storepass %PASS%
if errorlevel 1 exit /b 1

"%KEYTOOL%" -importcert -alias admin -file "%DEMO_DIR%\admin-signed.cer" -keystore "%USER_P12%" -storetype PKCS12 -storepass %PASS%
if errorlevel 1 exit /b 1

echo.
echo Truststore: %TRUSTSTORE%
echo Sample P12: %USER_P12%
echo Passphrase: %PASS%
echo Certificate CN=admin ^(matches demo Sakai user eid^)
echo Restart Tomcat after creating these files if it is already running.
exit /b 0
