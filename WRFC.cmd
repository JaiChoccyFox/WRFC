@ECHO OFF
VERIFY ERROR >NUL 2>&1
SETLOCAL ENABLEEXTENSIONS
SETLOCAL DISABLEDELAYEDEXPANSION
IF ERRORLEVEL 1 (
	ECHO UNABLE TO ENABLE EXTENSIONS!
	TIMEOUT /T 5 /NOBREAK >NUL 2>&1
	GOTO EOF
)
GOTO INIT

:REG
REG %* >NUL 2>&1
EXIT /B %ERRORLEVEL%

:APPLY-TWEAKS
CLS
COLOR 0F
IF "%_IS_ONLINE%" EQU "1" (
	ECHO Modifying ONLINE image . . .
) ELSE (
	ECHO Modifying OFFLINE image . . .
)
TIMEOUT /T 1 /NOBREAK >NUL 2>&1
ECHO(
ECHO Uninstalling provisioned AppX packages determined for removal . . .
IF EXIST "%~dp0%~n0\APPX\*" (
	FOR %%F IN ("%~dp0%~n0\APPX\*.TXT") DO (
		FOR /F "usebackq tokens=*" %%N IN ("%%~fF") DO (
			FOR /D %%P IN ("%_ROOT_PATH%Program Files\WindowsApps\%%~N") DO (
				%_DISM_CMD% /Remove-ProvisionedAppxPackage /PackageName:"%%~nxP" >NUL 2>&1
			)
		)
	)
)
IF "%_IS_ONLINE%" NEQ "1" (
	%_DISM_CMD% /Optimize-ProvisionedAppxPackages >NUL 2>&1
)
ECHO Applying policies via Registry . . .
IF "%_IS_ONLINE%" NEQ "1" (
	ECHO Loading "%_ROOT_PATH%Users\Default\NTUSER.DAT" . . .
	REG LOAD "%_REG_HKCU%" "%_ROOT_PATH%Users\Default\NTUSER.DAT" >NUL 2>&1
	ECHO Loading "%_ROOT_PATH%Windows\System32\config\SOFTWARE" . . .
	REG LOAD "%_REG_HKLM_SOFTWARE%" "%_ROOT_PATH%Windows\System32\config\SOFTWARE" >NUL 2>&1
	ECHO Loading "%_ROOT_PATH%Windows\System32\config\SYSTEM" . . .
	REG LOAD "%_REG_HKLM_SYSTEM%" "%_ROOT_PATH%Windows\System32\config\SYSTEM" >NUL 2>&1
)
IF EXIST "%TEMP%\WRFC-ControlSets.txt" DEL /F /Q "%TEMP%\WRFC-ControlSets.txt" >NUL 2>&1
FOR /L %%X IN (0,1,9) DO (
	FOR /L %%Y IN (0,1,9) DO (
		FOR /L %%Z IN (0,1,9) DO (
			REG QUERY "%_REG_HKLM_SYSTEM%\ControlSet%%~X%%~Y%%~Z" >NUL 2>&1
			IF NOT ERRORLEVEL 1 ECHO %%~X%%~Y%%~Z;> "%TEMP%\WRFC-ControlSets.txt"
		)
	)
)
IF EXIST "%~dp0%~n0\REGISTRY\*" (
	FOR %%F IN ("%~dp0%~n0\REGISTRY\*.TXT") DO (
		FOR /F "usebackq delims=; tokens=1,2,3,4,5*" %%A IN ("%%~fF") DO (
			IF /I "%%~B" EQU "HKCU" SET "_REG_CURRENT_ROOT=%_REG_HKCU%"
			IF /I "%%~B" EQU "HKLM\SOFTWARE" SET "_REG_CURRENT_ROOT=%_REG_HKLM_SOFTWARE%"
			IF /I "%%~B" EQU "HKLM\SYSTEM" SET "_REG_CURRENT_ROOT=%_REG_HKLM_SYSTEM%"
			IF /I "%%~B" EQU "HKLM\SYSTEM\CURRENTCONTROLSET" (
				IF EXIST "%TEMP%\WRFC-ControlSets.txt" (
					FOR /F "usebackq delims=; eol=; tokens=1" %%X IN ("%TEMP%\WRFC-ControlSets.txt") DO (
						SET "_REG_CURRENT_ROOT=%_REG_HKLM_SYSTEM%\ControlSet%%~X"
						IF /I "%%~A" EQU "ADD" CALL :REG ADD "%%_REG_CURRENT_ROOT%%\%%~C" /T "%%~D" /V "%%~E" /D "%%~F" /F
						IF /I "%%~A" EQU "DELKEY" CALL :REG DELETE "%%_REG_CURRENT_ROOT%%\%%~C" /F
						IF /I "%%~A" EQU "DELVAL" CALL :REG DELETE "%%_REG_CURRENT_ROOT%%\%%~C" /V "%%~D" /F
					)
				)
			) ELSE (
				IF /I "%%~A" EQU "ADD" CALL :REG ADD "%%_REG_CURRENT_ROOT%%\%%~C" /T "%%~D" /V "%%~E" /D "%%~F" /F
				IF /I "%%~A" EQU "DELKEY" CALL :REG DELETE "%%_REG_CURRENT_ROOT%%\%%~C" /F
				IF /I "%%~A" EQU "DELVAL" CALL :REG DELETE "%%_REG_CURRENT_ROOT%%\%%~C" /V "%%~D" /F
			)
		)
	)
)
IF EXIST "%TEMP%\WRFC-ControlSets.txt" DEL /F /Q "%TEMP%\WRFC-ControlSets.txt" >NUL 2>&1
IF "%_IS_ONLINE%" NEQ "1" (
	ECHO Unloading "%_ROOT_PATH%Users\Default\NTUSER.DAT" . . .
	REG UNLOAD "%_REG_HKCU%" >NUL 2>&1
	ECHO Unloading "%_ROOT_PATH%Windows\System32\config\SOFTWARE" . . .
	REG UNLOAD "%_REG_HKLM_SOFTWARE%" >NUL 2>&1
	ECHO Unloading "%_ROOT_PATH%Windows\System32\config\SYSTEM" . . .
	REG UNLOAD "%_REG_HKLM_SYSTEM%" >NUL 2>&1
)
IF "%_IS_ONLINE%" EQU "1" GPUPDATE /FORCE >NUL 2>&1
ECHO(
ECHO(
ECHO DONE !
ECHO PRESS ANY KEY TO CONTINUE . . .
PAUSE >NUL 2>&1
GOTO EOF

:VALIDATE-IMAGE
CLS
COLOR 1F
ECHO(
ECHO     -=* Windows Restricted Functionality Configurator *=-
ECHO(
ECHO   {NOTICE}
ECHO   Before we continue, please provide a path to the Windows image;
ECHO   It is recommended that you apply this over an OFFLINE image of Windows!
ECHO(
ECHO(
SET "_USERIN="
SET "_ROOT_PATH="
SET /P "_USERIN=Path to Windows image (BLANK=Cancel): "
IF NOT DEFINED _USERIN GOTO EOF
SET "_ROOT_PATH=%_USERIN%\"
IF NOT EXIST "%_ROOT_PATH%Program Files\WindowsApps\*" (
	ECHO INVALID IMAGE!
	TIMEOUT /T 3 /NOBREAK >NUL 2>&1
	GOTO VALIDATE-IMAGE
)
IF NOT EXIST "%_ROOT_PATH%Users\Default\NTUSER.DAT" (
	ECHO INVALID IMAGE!
	TIMEOUT /T 3 /NOBREAK >NUL 2>&1
	GOTO VALIDATE-IMAGE
)
IF NOT EXIST "%_ROOT_PATH%Windows\System32\config\SOFTWARE" (
	ECHO INVALID IMAGE!
	TIMEOUT /T 3 /NOBREAK >NUL 2>&1
	GOTO VALIDATE-IMAGE
)
IF NOT EXIST "%_ROOT_PATH%Windows\System32\config\SYSTEM" (
	ECHO INVALID IMAGE!
	TIMEOUT /T 3 /NOBREAK >NUL 2>&1
	GOTO VALIDATE-IMAGE
)
DISM /Image:"%_ROOT_PATH%" /Format:Table /Get-Packages >NUL 2>&1
IF NOT ERRORLEVEL 87 IF ERRORLEVEL 1 (
	ECHO UNKNOWN ERROR!
	TIMEOUT /T 3 /NOBREAK >NUL 2>&1
	GOTO EOF
)
IF ERRORLEVEL 87 (
	ECHO Image is ONLINE!
	SET "_IS_ONLINE=1"
	SET "_DISM_CMD=DISM /Online"
	SET "_REG_HKCU=HKCU"
	SET "_REG_HKLM_SOFTWARE=HKLM\SOFTWARE"
	SET "_REG_HKLM_SYSTEM=HKLM\SYSTEM"
) ELSE (
	ECHO Image is OFFLINE!
	SET "_IS_ONLINE=0"
	SET "_DISM_CMD=DISM /Image:"%_ROOT_PATH%""
	SET "_REG_HKCU=HKLM\WRFC-USR"
	SET "_REG_HKLM_SOFTWARE=HKLM\WRFC-SOF"
	SET "_REG_HKLM_SYSTEM=HKLM\WRFC-SYS"
)
TIMEOUT /T 1 /NOBREAK >NUL 2>&1
GOTO APPLY-TWEAKS

:INIT
NET SESSION >NUL 2>&1
IF ERRORLEVEL 1 (
	ECHO PLEASE RUN THIS SCRIPT AS ADMINISTRATOR!
	TIMEOUT /T 5 /NOBREAK >NUL 2>&1
	GOTO EOF
)
IF NOT DEFINED _RESTART_CMD (
	SET "_RESTART_CMD=1"
	START "Windows Restricted Functionality Configurator" /D "%CD%" CMD /Q /E:ON /F:OFF /V:OFF /C "CALL "%~f0""
	GOTO EOF
)
SET "_CLEAR_CMD=1"
CLS
COLOR 1F
ECHO(
ECHO     -=* Windows Restricted Functionality Configurator *=-
ECHO(
ECHO   {WARNING}
ECHO   This script will disable various windows 10/11 functionality!
ECHO   However, you will gain improved privacy as a result.
ECHO(
ECHO   USE AT YOUR OWN RISK! I AM NOT LIABLE FOR ANYTHING.
ECHO(
ECHO(
SET "_USERIN="
SET /P "_USERIN=Do you accept the consequences? [y/N]: "
IF DEFINED _USERIN (
	IF /I "%_USERIN%" EQU "Y" (
		GOTO VALIDATE-IMAGE
	)
)
GOTO EOF


:EOF
IF DEFINED _CLEAR_CMD CLS
COLOR
EXIT /B %ERRORLEVEL%
