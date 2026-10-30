@echo off
rem Build of SAPI-Term (docs\vyvoj.md, "Preklad"): build\sapiterm.com, .sym, .hex and the RAM disk image
rem build\ramdisk.bin (the CP/M disk of the set V with SAPITERM.COM and the test files build\art\*.ANS, used by
rem machines\sapi1v_term*.sapi).
rem Needs Python 3 and pasmo 0.5.3 (PASMO). Paths in the environment or the defaults below.
setlocal
cd /d "%~dp0"
if "%PASMO%"=="" set PASMO=E:\SAPI_GIT\Tools\pasmo-0.5.3\pasmo.exe
if "%CPM_IMAGE%"=="" set CPM_IMAGE=E:\SAPI_GIT\SAPIemu-release\media\zrmd-1\SAPI_CPM_Martin_2019-10-07.bin
if not exist build mkdir build

python tools\fontgen.py || exit /b 1
python tools\tables.py || exit /b 1
python tools\texts.py || exit /b 1
python tools\mkart.py || exit /b 1

pushd src
"%PASMO%" --bin sapiterm.asm ..\build\sapiterm.com ..\build\sapiterm.sym || (popd & exit /b 1)
"%PASMO%" --hex sapiterm.asm ..\build\sapiterm.hex || (popd & exit /b 1)
popd
python tools\check_build.py || exit /b 1
python tools\cpmdisk.py "%CPM_IMAGE%" build\ramdisk.bin build\sapiterm.com=SAPITERM.COM build\art\ANSITEST.ANS=ANSITEST.ANS build\art\SUNSET.ANS=SUNSET.ANS build\art\MENU.ANS=MENU.ANS build\art\SCROLL.ANS=SCROLL.ANS || exit /b 1
echo build\ramdisk.bin: the RAM disk A: of the set V with SAPITERM.COM and the test files *.ANS
