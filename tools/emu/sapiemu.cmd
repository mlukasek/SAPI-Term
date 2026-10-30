@echo off
rem Start the released SAPIemu with MCP for the scripts in tools\emu (docs\vyvoj.md, "Emulator").
rem   sapiemu.cmd          sapiemu-cli without a window, MCP on 8595, machine machines\sapi1v_term.sapi
rem   sapiemu.cmd consul   the same with machines\sapi1v_term_consul.sapi
rem   sapiemu.cmd gui      the GUI for manual tests, MCP on 8596 (SAPIEMU_MCP=http://127.0.0.1:8596/mcp)
rem SAPIEMU_DIR: the released SAPIemu, default E:\SAPI_GIT\SAPIemu-release (not the SAPIemu repo, which is
rem developed in parallel). Stop it with MCP "power off" first, then close the window.
setlocal
if "%SAPIEMU_DIR%"=="" set SAPIEMU_DIR=E:\SAPI_GIT\SAPIemu-release
set MACHINE=%~dp0..\..\machines\sapi1v_term.sapi
if /i "%1"=="consul" set MACHINE=%~dp0..\..\machines\sapi1v_term_consul.sapi
cd /d "%SAPIEMU_DIR%"
if /i "%1"=="gui" (
  start "sapiemu MCP 8596" sapiemu.exe --machine "%MACHINE%" --mcp-port 8596
) else (
  start "sapiemu-cli MCP 8595" sapiemu-cli.exe --machine "%MACHINE%" --mcp --mcp-port 8595
)
