@echo off
setlocal

python "%~dp0wowaddon.py" zip --out "%~dp0..\_Releases"
exit /b %ERRORLEVEL%
