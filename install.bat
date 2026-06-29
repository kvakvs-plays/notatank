@echo off
setlocal

python "%~dp0wowaddon.py" install --dst="F:\SSDGames\World of Warcraft\_anniversary_\Interface\AddOns"
exit /b %ERRORLEVEL%
