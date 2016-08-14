@echo off
setlocal
setlocal EnableDelayedExpansion
cd /d "%~dp0"
set cwd=%cd%

rem ---------------------------------------------------------
rem Get admin permissions so we can copy files to c:\
rem see http://stackoverflow.com/questions/7044985/how-can-i-auto-elevate-my-batch-file-so-that-it-requests-from-uac-administrator/12264592#12264592
rem ---------------------------------------------------------
:checkPrivileges
net file 1>NUL 2>NUL
if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges )
:getPrivileges
if '%1'=='ELEV' (shift /1 & goto gotPrivileges)
echo ********************************************************
echo Requesting Administrator permission for the installation
echo ********************************************************
setlocal DisableDelayedExpansion
set "batchPath=%~0"
setlocal EnableDelayedExpansion
echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\OEgetPrivileges.vbs"
echo args = "ELEV " >> "%temp%\OEgetPrivileges.vbs"
echo For Each strArg in WScript.Arguments >> "%temp%\OEgetPrivileges.vbs"
echo args = args ^& strArg ^& " "  >> "%temp%\OEgetPrivileges.vbs"
echo Next >> "%temp%\OEgetPrivileges.vbs"
echo UAC.ShellExecute "!batchPath!", args, "", "runas", 1 >> "%temp%\OEgetPrivileges.vbs"
"%SystemRoot%\System32\WScript.exe" "%temp%\OEgetPrivileges.vbs" %*
exit /B
:gotPrivileges

rem ---------------------------------------------------------
rem installing nginx in c:\nginx
rem ---------------------------------------------------------
if not exist c:\nginx\conf\nginx.conf (
  echo.
  echo Copying nginx HTTP server to c:\nginx
  xcopy /e /i /q "%cwd%\nginx" c:\nginx
  if errorlevel 1 goto error 
) else if not exist c:\nginx\html\toxikkredirect (
  echo.
  echo WARNING: Found an existing nginx installation in c:\nginx without a html/toxikkredirect folder.
  echo If this is not a TOXIKK Server Pack instance, you need to configure your nginx manually.
  echo See %cwd%\nginx\conf\nginx.conf for details how to configure the /toxikkredirect/ URL.
)
rem add rule to windows firewall for nginx.exe
netsh advfirewall firewall show rule "nginx" >NUL 2>NUL
if errorlevel 1 (
  echo.
  echo Adding nginx to Windows firewall...
  netsh advfirewall firewall add rule name="nginx" dir=in action=allow program="c:\nginx\nginx.exe" enable=yes >NUL
)  

rem ---------------------------------------------------------
rem installing winsw to run nginx as a windows service
rem ---------------------------------------------------------
sc query nginx >NUL 2>NUL
if errorlevel 1 (
  echo.
  echo Installing Windows service "nginx"
  cd /d c:\nginx
  nginxsvc.exe install
  if errorlevel 1 goto error
  net start nginx
  if errorlevel 1 goto error
)

rem ---------------------------------------------------------
rem install steamcmd in c:\steamcmd
rem ---------------------------------------------------------
if not exist c:\steamcmd\steamcmd.exe (
  echo.
  echo Installing steamcmd in c:\steamcmd. TOXIKK and its workshop items will be installed in c:\steamcmd\steamapps
  if not exist c:\steamcmd mkdir c:\steamcmd
  copy "%cwd%\steamcmd.exe" c:\steamcmd >NUL
  if errorlevel 1 goto error
)


rem ---------------------------------------------------------
rem install TOXIKK in c:\steamcmd\steamapps\common\TOXIKK
rem ---------------------------------------------------------
if not exist c:\steamcmd\steamapps\common\TOXIKK\Binaries\Win32\TOXIKK.exe (
  echo.
  echo Installing TOXIKK...
  call :getSteamLoginInfo
  if not "!steamUser!"=="" (
    cd /d c:\steamcmd
    steamcmd.exe +login "!steamUser!" +app_update 324810 validate +quit
  )
  if not exist c:\steamcmd\steamapps\common\TOXIKK\Binaries\Win32\TOXIKK.exe (
    echo ERROR - make sure TOXIKK is installed as c:\steamcmd\steamapps\common\TOXIKK\Binaries\Win32\TOXIKK.exe
	goto :error
  )
)

rem ---------------------------------------------------------
rem add rule to windows firewall for TOXIKK.exe
rem ---------------------------------------------------------
netsh advfirewall firewall show rule "TOXIKK Server" >NUL 2>NUL
if errorlevel 1 (
  echo.
  echo Adding TOXIKK to Windows firewall...
  netsh advfirewall firewall add rule name="TOXIKK Server" dir=in action=allow program="c:\steamcmd\steamapps\common\TOXIKK\Binaries\Win32\TOXIKK.exe" enable=yes >NUL
)

rem ---------------------------------------------------------
rem install Redist packages for TOXIKK 
rem ---------------------------------------------------------
set dllDir=%windir%\system32
if exist "%windir%\SysWOW64" set dllDir="%windir%\SysWOW64"
if not exist "%dllDir%\msvcr100.dll" (
  echo.
  echo Installing MS Visual C++ 2010 Redist package...
  c:\steamcmd\steamapps\common\TOXIKK\_CommonRedist\vcredist\2010\vcredist_x86.exe /q
  if errorlevel 1 goto error
)
if not exist "%dllDir%\xinput1_3.dll" (
  echo.
  echo Installing MS DirectX Redist package...
  c:\steamcmd\steamapps\common\TOXIKK\_CommonRedist\DirectX\Jun2010\dxsetup.exe /silent
  if errorlevel 1 goto error
)

rem ---------------------------------------------------------
rem install TOXIKK shader map cache for custom maps
rem ---------------------------------------------------------
if not exist c:\steamcmd\steamapps\common\TOXIKK\UDKGame\CookedPC\LocalShaderCache-PC-D3D-SM3.bak (
  echo.
  echo Installing shader map cache to support fast loading of supported custom maps
  ren c:\steamcmd\steamapps\common\TOXIKK\UDKGame\CookedPC\LocalShaderCache-PC-D3D-SM3.upk *.bak
  copy "%cwd%\TOXIKK\LocalShaderCache-PC-D3D-SM3.upk" c:\steamcmd\steamapps\common\TOXIKK\UDKGame\CookedPC\ >NUL
)

rem ---------------------------------------------------------
rem install ToxikkServerLauncher in c:\steamcmd\SteamApps\Common\TOXIKK\TOXIKKServers
rem ---------------------------------------------------------
echo.
echo Installing ToxikkServerLauncher...
copy /y "%cwd%\ToxikkServerLauncher\*" c:\steamcmd\steamapps\common\TOXIKK\TOXIKKServers\ >NUL
if errorlevel 1 goto error
if not exist c:\steamcmd\steamapps\common\TOXIKK\TOXIKKServers\MyServerConfig.ini call :createMyServerConfigIni
rem create desktop shortcuts
if not exist "%userprofile%\Desktop\TOXIKK Server.lnk" (
  powershell "$s=(New-Object -COM WScript.Shell).CreateShortcut('%userprofile%\Desktop\TOXIKK Server.lnk');$s.TargetPath='c:\steamcmd\steamapps\common\TOXIKK\TOXIKKServers\ToxikkServerLauncher.exe';$s.IconLocation='c:\steamcmd\steamapps\common\TOXIKK\Binaries\Win32\TOXIKK.exe';$s.Save()"
)
if not exist "%userprofile%\Desktop\TOXIKK Config.lnk" (
  powershell "$s=(New-Object -COM WScript.Shell).CreateShortcut('%userprofile%\Desktop\TOXIKK Config.lnk');$s.TargetPath='c:\steamcmd\steamapps\common\TOXIKK\TOXIKKServers\MyServerConfig.ini';$s.Save()"
)

rem ---------------------------------------------------------
rem open MyServerConfig.ini in Notepad++ or Notepad
rem ---------------------------------------------------------
set editor=%windir%\notepad.exe
if exist "%programfiles(x86)%\Notepad++\Notepad++.exe" set editor=%programfiles(x86)%\Notepad++\Notepad++.exe
if exist "%programfiles%\Notepad++\Notepad++.exe" set editor=%programfiles%\Notepad++\Notepad++.exe
echo.
echo --------------------------------
echo SUCCESS
echo Edit c:\steamcmd\steamapps\common\TOXIKK\TOXIKKServers\MyServerConfig.ini to configure workshop items, maps, server settings, ...
echo Use the "TOXIKK Server Launcher" shortcut on your desktop to start a server. Use "-h" for help about its command line options.
cd /d c:\steamcmd\steamapps\common\TOXIKK\TOXIKKServers
"%editor%" MyServerConfig.ini
pause
exit /b

:error
echo.
echo ERROR
echo Installation failed. Please see messages above.
cd /d "%cwd%"
pause
exit /b

rem ----------------------
rem prompt for steam login
rem ---------------------
:getSteamLoginInfo
if not "%steamUser%"=="" exit /b
set steamUser=
cd /d c:\steamcmd
if exist steam_user.txt (set /p steamUser=<steam_user.txt)
if "%steamUser%"=="" set /p steamUser="Steam username: "
exit /b


rem ----------------------
rem create MyServerConfig.ini file with some custom settings
rem ---------------------
:createMyServerConfigIni
rem create file
copy c:\steamcmd\steamapps\common\TOXIKK\TOXIKKServers\ServerConfig.ini c:\steamcmd\steamapps\common\TOXIKK\TOXIKKServers\MyServerConfig.ini >NUL
rem fill out steam user
call :getSteamLoginInfo
if not "%steamUser%"=="" (
  "%cwd%\fart.exe" -q c:\steamcmd\steamapps\common\TOXIKK\TOXIKKServers\MyServerConfig.ini "User=anonymous" "User=%steamUser%"
) 
rem detect external IP address of this machine, trying different services
set extIp=
for %%u in (http://api.ipify.org/ http://abpro.at/public_ip.php) do (
  if "!extIp!"=="" (
    "%cwd%\curl.exe" -s %%u >"%temp%\external_ip.txt"
    if not errorlevel 1 set /p extIp=<"%temp%\external_ip.txt"
  )
)
del "%temp%\external_ip.txt" 2>NUL
if "%extIp%"=="" (
  echo ERROR: unable to detect your external IP address. Please configure @HttpRedirectUrl@ manually in MyServerConfig.ini
) else (
  "%cwd%\fart.exe" -q c:\steamcmd\steamapps\common\TOXIKK\TOXIKKServers\MyServerConfig.ini "@HttpRedirectUrl@=" "@HttpRedirectUrl@=http://%extIp%/toxikkredirect/"
)

rem ask for server name
set /p name="Enter a name for your server: "
if not "%name%"=="" "%cwd%\fart.exe" -q c:\steamcmd\steamapps\common\TOXIKK\TOXIKKServers\MyServerConfig.ini "ServerName=My Toxikk Server" "ServerName=%name%"
exit /b
