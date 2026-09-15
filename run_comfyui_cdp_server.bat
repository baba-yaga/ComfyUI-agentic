@echo off
setlocal EnableExtensions

REM This file is launched by run_comfyui_cdp.bat. Do not use it for normal work.
set "ROOT=%~dp0"
set "COMFY_PORT=8189"
set "ROOT_URL=%ROOT:\=/%"
set "CODEX_DATABASE_URL=sqlite:///%ROOT_URL%ComfyUI/user/comfyui-codex-%COMFY_PORT%.db"

cd /d "%ROOT%"
"%ROOT%python_embeded\python.exe" -s "%ROOT%ComfyUI\main.py" --windows-standalone-build --port %COMFY_PORT% --database-url "%CODEX_DATABASE_URL%"

echo.
echo ComfyUI stopped. Review the messages above before closing this window.
pause
