# ComfyUI-agentic on macOS

This companion runs the ComfyUI checkout in `../ComfyUI` and opens a separate
Chrome profile for agent control. It does not use or attach to your regular
Chrome profile.

## Setup

From the ComfyUI project root, install the MCP bridge dependency:

```bash
./.venv/bin/python -m pip install -r ../ComfyUI-agentic/tools/requirements-mcp.txt
```

The ComfyUI workspace MCP server is configured in `.vscode/mcp.json`. After
installing the dependency, restart or reload that MCP server in VS Code so the
`comfy_chrome_*` tools become available to the agent.

## Start

Install the macOS application in `~/Applications`. Its native `.icns` icon is
generated from `assets/comfyui-agentic-icon.ico`:

```bash
../ComfyUI-agentic/install_macos_app.sh
```

Open **ComfyUI Agentic.app** from Applications or Spotlight, then choose
**Start ComfyUI**. The app uses the companion icon and offers **Stop ComfyUI**
as well. The app stays open; click its Dock icon to show the controls again.
Quitting the app stops ComfyUI and leaves Chrome open.
Start and stop can also be run from the ComfyUI project root:

```bash
../ComfyUI-agentic/run_comfyui_cdp.sh start
../ComfyUI-agentic/run_comfyui_cdp.sh stop
```

Start binds ComfyUI to `127.0.0.1:8189`, waits for it to be ready, and opens
Google Chrome with a dedicated profile and CDP bound to `127.0.0.1:9223`. The
server log is written to `user/comfyui-agentic-8189.log`. Stop sends SIGTERM
only to the ComfyUI process from this checkout; it leaves the dedicated Chrome
window open. The launcher refuses to attach if port 9223 belongs to a different
Chrome session.

Keep the dedicated Chrome window open while the agent uses the MCP tools.
Inspecting a workflow is read-only. Editing text, queueing a workflow, or
running JavaScript requires an explicit user request.
