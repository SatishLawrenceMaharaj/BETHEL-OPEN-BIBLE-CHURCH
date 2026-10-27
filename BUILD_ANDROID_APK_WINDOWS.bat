@echo off
setlocal
cd /d "%~dp0"
echo.
echo  ==============================================
echo   BETHEL OPEN BIBLE CHURCH - FLUTTER APK
 echo  ==============================================
echo.
where flutter >nul 2>nul
if errorlevel 1 (
 echo [ERROR] Flutter SDK is not installed or not on PATH.
 echo Install Flutter and Android Studio using https://docs.flutter.dev/get-started/install
 echo Then reopen Command Prompt and run this file again.
 pause
 exit /b 1
)
echo [1/5] Checking Flutter/Android setup...
call flutter doctor
if errorlevel 1 (
 echo Please resolve flutter doctor errors for Android and try again.
 pause
 exit /b 1
)
echo [2/5] Generating Android platform files...
call flutter create --platforms=android --org org.bethelopenbible --project-name bethel_open_bible_church .
if errorlevel 1 goto FAIL
echo [3/5] Installing Flutter packages...
call flutter pub get
if errorlevel 1 goto FAIL
call dart run tool/configure_android.dart
if errorlevel 1 goto FAIL
call dart run flutter_launcher_icons
if errorlevel 1 goto FAIL
echo [4/5] Compiling release APK...
call flutter build apk --release
if errorlevel 1 goto FAIL
echo [5/5] Completed.
echo.
echo APK created at:
echo   %CD%\build\app\outputs\flutter-apk\app-release.apk
echo.
echo NOTE: This initial APK uses the default test signing configuration.
echo Keep the signing key consistent before distributing updates.
start "" "%CD%\build\app\outputs\flutter-apk"
pause
exit /b 0
:FAIL
echo.
echo [ERROR] Build failed. Read the error above. Do NOT install an older experimental APK.
pause
exit /b 1
