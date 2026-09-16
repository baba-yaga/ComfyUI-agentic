# ComfyUI-agentic

Local, agent-assisted control of a portable ComfyUI installation through a dedicated Google Chrome window. It is a small companion layer: this repository does **not** contain ComfyUI itself, checkpoints, custom nodes, user workflows, generated images, or a Chrome profile.

The launcher starts ComfyUI and a separate Chrome profile with Chrome DevTools Protocol (CDP) bound to `127.0.0.1` only. A Codex agent can then inspect the live workflow and make explicitly requested changes in the actual browser UI.

## Prerequisites

- Windows 10 or 11.
- A working **portable** ComfyUI installation with `python_embeded/python.exe` and `ComfyUI/main.py`.
- Google Chrome. Chrome Developer Mode does not need to be enabled manually.
- Codex in VS Code or another Codex environment with terminal access.
- Permission to use local ports `8189` (ComfyUI) and `9223` (CDP). Change both consistently if either is already in use.

## Standard installation layout

Copy this repository's files into the root of a duplicate or experimental portable ComfyUI installation:

```text
ComfyUI_windows_portable/
|-- python_embeded/
|-- ComfyUI/
|   |-- main.py
|   |-- input/
|   |-- models/
|   `-- output/
|-- run_comfyui_cdp.bat
|-- run_comfyui_cdp_server.bat
|-- AGENTS.md
|-- assets/
|   `-- comfyui-agentic-icon.ico
`-- tools/
    |-- Invoke-CdpEvaluate.ps1
    `-- comfy_chrome_mcp.py
```

Do not copy the BAT files to the Desktop. Create a desktop shortcut to `run_comfyui_cdp.bat` instead: the launcher resolves paths from the directory where it is stored. Feel free to use the icon `assets\comfyui-agentic-icon.ico` for the shortcut.

## Developing the companion alongside ComfyUI

Keep this repository outside the portable installation and use NTFS hard links for its five runtime files. This makes the repository the single source of truth while the portable installation uses the exact same files. Hard links work only when both folders are on the same NTFS volume; they do not require Chrome Developer Mode or administrator rights.

For example, a local experimental installation can retain its existing launcher names as hard links, and also needs a `run_comfyui_cdp_server.bat` hard link because the shared main launcher calls that name:

```text
ComfyUI-agentic/                         # Git repository
experimental/                            # portable ComfyUI installation
|-- run_comfyui_experimental_cdp.bat     # hard link to ../ComfyUI-agentic/run_comfyui_cdp.bat
|-- run_comfyui_experimental_cdp_server.bat
|-- run_comfyui_cdp_server.bat           # hard link to the shared server launcher
|-- AGENTS.md
`-- tools/
    |-- Invoke-CdpEvaluate.ps1
    `-- comfy_chrome_mcp.py
```

Edit the file from either path, then commit and push from `ComfyUI-agentic`. Do not replace a hard link with a copied file: check it first with `fsutil hardlink list path\\to\\file`.

Git can replace a file during `pull`, which breaks a hard link even though both copies still look correct. After pulling changes made on another machine, restore the links with the included script. Preview first with `-WhatIf`:

```powershell
.\tools\Repair-PortableLinks.ps1 -ComfyRoot D:\AI\ComfyUI\0.35.0\experimental -LegacyExperimentalNames -WhatIf
.\tools\Repair-PortableLinks.ps1 -ComfyRoot D:\AI\ComfyUI\0.35.0\experimental -LegacyExperimentalNames
```

## Start

1. Open the portable ComfyUI root above as the workspace root in VS Code/Codex.
2. Run `run_comfyui_cdp.bat`.
3. Wait for the dedicated Chrome window at `http://127.0.0.1:8189`.
4. Start a new Codex chat in that same workspace. `AGENTS.md` gives Codex the operating rules for this window.

For ordinary use, do not run `run_comfyui_cdp_server.bat` directly. It is the server process launched by the main BAT.

## Optional Desktop shortcut icon

`assets/comfyui-agentic-icon.ico` is a transparent, multi-size Windows icon for a shortcut to the main BAT. Create the shortcut, open **Properties**, choose **Change Icon**, and select this file. Keep the ICO at that location: a Windows shortcut stores an absolute icon path.

## Safety model

- CDP is bound to `127.0.0.1`, so it is not reachable from another device on the network.
- The launcher uses a separate Chrome profile named `.codex-chrome-profile`; it must not be used to control personal Chrome tabs.
- On a cold start, the launcher removes only the saved tabs and windows of that separate profile. This avoids Chrome recovering an earlier agentic session; it does not affect ordinary Chrome, passwords, bookmarks, history, ComfyUI workflows, or generated images.
- A Codex agent should inspect before editing and should change nodes, prompts, models, inputs, or queue a generation only after an explicit user request.
- Keep a separate experimental ComfyUI copy for agentic experiments. Save useful workflows under a clear name before moving them to a production installation.

## Optional MCP server

`tools/comfy_chrome_mcp.py` is a stdio MCP server exposing read-only status and workflow inspection plus explicitly requested text edits, queueing, and targeted JavaScript. It uses only Python's standard library and the included PowerShell CDP helper.

Configure it in your Codex client with the portable Python executable and the absolute path to `tools/comfy_chrome_mcp.py`. The default endpoints are `127.0.0.1:8189` and `127.0.0.1:9223`; set `COMFYUI_AGENTIC_COMFY_URL` and `COMFYUI_AGENTIC_CDP_URL` only when using different ports.
