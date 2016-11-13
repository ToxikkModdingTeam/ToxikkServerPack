@echo off
setlocal
cd /d "%~dp0"
copy f:\games\steam\steamapps\common\TOXIKK\UDKGame\CookedPC\LocalShaderCache-PC-D3D-SM3.upk TOXIKK\
if errorlevel 1 goto error
if exist ToxikkServerPack.zip del ToxikkServerPack.zip
if errorlevel 1 goto error
del ToxikkServerLauncher\MyServerConfig.ini >NUL
"c:\program files\7-zip\7z.exe" a ToxikkServerPack.zip nginx TOXIKK ToxikkServerLauncher readme.txt setup.cmd steamcmd.exe
if errorlevel 1 goto error
goto:eof

:error
echo An error occured
pause