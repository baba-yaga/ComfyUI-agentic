@echo off
setlocal EnableExtensions

REM ComfyUI + isolated Chrome window for local Codex/CDP work.
REM Keep this file in the root of a portable ComfyUI installation.
set "ROOT=%~dp0"
set "COMFY_PORT=8189"
set "CDP_PORT=9223"
set "COMFY_URL=http://127.0.0.1:%COMFY_PORT%"
set "CHROME_PROFILE=%ROOT%.codex-chrome-profile"
set "ROOT_URL=%ROOT:\=/%"
set "CODEX_DATABASE_URL=sqlite:///%ROOT_URL%ComfyUI/user/comfyui-codex-%COMFY_PORT%.db"

if not exist "%ROOT%python_embeded\python.exe" (
    echo ERROR: Portable Python was not found: "%ROOT%python_embeded\python.exe"
    exit /b 1
)

if not exist "%ROOT%ComfyUI\main.py" (
    echo ERROR: ComfyUI was not found: "%ROOT%ComfyUI\main.py"
    exit /b 1
)

powershell.exe -NoProfile -Command "try { $null = Invoke-RestMethod -Uri '%COMFY_URL%/system_stats' -TimeoutSec 2; exit 0 } catch { exit 1 }" >nul 2>nul
set "COMFY_READY=%ERRORLEVEL%"

if "%COMFY_READY%"=="0" echo ComfyUI-agentic is already running at %COMFY_URL%.
if not "%COMFY_READY%"=="0" echo Starting ComfyUI-agentic on %COMFY_URL% ...
if not "%COMFY_READY%"=="0" start "ComfyUI-agentic - port %COMFY_PORT%" /D "%ROOT%" "%ComSpec%" /k call "%ROOT%run_comfyui_cdp_server.bat"
if not "%COMFY_READY%"=="0" powershell.exe -NoProfile -Command "$deadline = (Get-Date).AddSeconds(120); do { try { $null = Invoke-RestMethod -Uri '%COMFY_URL%/system_stats' -TimeoutSec 2; exit 0 } catch { Start-Sleep -Seconds 1 } } while ((Get-Date) -lt $deadline); exit 1"
if not "%COMFY_READY%"=="0" if errorlevel 1 echo ERROR: ComfyUI did not become ready within 120 seconds. Check the ComfyUI-agentic console window for details.
if not "%COMFY_READY%"=="0" if errorlevel 1 exit /b 1

powershell.exe -NoProfile -Command "try { $tabs = @(Invoke-RestMethod -Uri 'http://127.0.0.1:%CDP_PORT%/json/list' -TimeoutSec 2); if (@($tabs | Where-Object { $_.type -eq 'page' -and $_.url -like '%COMFY_URL%*' }).Count -gt 0) { exit 0 }; exit 1 } catch { exit 1 }" >nul 2>nul
set "COMFY_TAB_READY=%ERRORLEVEL%"

if "%COMFY_TAB_READY%"=="0" echo Reusing the existing isolated Chrome window for %COMFY_URL%.
if not "%COMFY_TAB_READY%"=="0" set "CHROME="
if not "%COMFY_TAB_READY%"=="0" if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not "%COMFY_TAB_READY%"=="0" if not defined CHROME if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not "%COMFY_TAB_READY%"=="0" if not defined CHROME for /f "delims=" %%I in ('where chrome.exe 2^>nul') do if not defined CHROME set "CHROME=%%I"
if not "%COMFY_TAB_READY%"=="0" if not defined CHROME (
    echo ERROR: Google Chrome was not found in the standard installation paths.
    exit /b 1
)

if not "%COMFY_TAB_READY%"=="0" if not exist "%CHROME_PROFILE%" mkdir "%CHROME_PROFILE%"
if not "%COMFY_TAB_READY%"=="0" echo Opening isolated Chrome profile with local DevTools access on port %CDP_PORT% ...
if not "%COMFY_TAB_READY%"=="0" start "ComfyUI-agentic Browser" "%CHROME%" --new-window --no-first-run --no-default-browser-check --remote-debugging-address=127.0.0.1 --remote-debugging-port=%CDP_PORT% --remote-allow-origins=http://127.0.0.1:%CDP_PORT% --user-data-dir="%CHROME_PROFILE%" "%COMFY_URL%"

echo.
echo Ready: %COMFY_URL%
echo Local Chrome DevTools endpoint: http://127.0.0.1:%CDP_PORT%
echo This endpoint is bound to 127.0.0.1 only. Keep the dedicated Chrome window open while Codex works with it.
exit /b 0
