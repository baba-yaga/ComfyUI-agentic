#!/bin/bash
set -euo pipefail

AGENTIC_ROOT="$(cd "$(dirname "$0")" && pwd)"
COMFY_ROOT="$(cd "$AGENTIC_ROOT/../ComfyUI" && pwd)"
PYTHON="$COMFY_ROOT/.venv/bin/python"
COMFY_URL="http://127.0.0.1:8189"
CDP_URL="http://127.0.0.1:9223"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CHROME_PROFILE="$AGENTIC_ROOT/.codex-chrome-profile"
COMFY_LOG="$COMFY_ROOT/user/comfyui-agentic-8189.log"
COMFY_PID_FILE="$COMFY_ROOT/user/comfyui-agentic-8189.pid"

if [[ ! -x "$PYTHON" || ! -f "$COMFY_ROOT/main.py" ]]; then
    echo "ERROR: ComfyUI or its .venv was not found at $COMFY_ROOT" >&2
    exit 1
fi

comfy_ready() {
    COMFY_URL="$COMFY_URL" "$PYTHON" -c '
import json, os, urllib.request
with urllib.request.urlopen(os.environ["COMFY_URL"] + "/system_stats", timeout=2) as response:
    data = json.load(response)
if "system" not in data or "devices" not in data:
    raise SystemExit(1)
' >/dev/null 2>&1
}

cdp_has_comfy_tab() {
    CDP_URL="$CDP_URL" COMFY_URL="$COMFY_URL" "$PYTHON" -c '
import json, os, urllib.request
with urllib.request.urlopen(os.environ["CDP_URL"] + "/json/list", timeout=2) as response:
    pages = json.load(response)
base = os.environ["COMFY_URL"]
raise SystemExit(0 if any(
    page.get("type") == "page" and page.get("url", "").startswith(base)
    for page in pages
) else 1)
' >/dev/null 2>&1
}

is_comfy_process() {
    local pid="$1"
    local command
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    command="$(ps -p "$pid" -o command= 2>/dev/null)" || return 1
    [[ "$command" == *"$COMFY_ROOT/main.py --listen 127.0.0.1 --port 8189"* ]]
}

stop_comfy() {
    local pid=""
    local listener_pid
    local listeners

    if [[ -f "$COMFY_PID_FILE" ]]; then
        IFS= read -r pid <"$COMFY_PID_FILE" || true
        if ! is_comfy_process "$pid"; then
            pid=""
        fi
    fi

    if [[ -z "$pid" ]]; then
        listeners="$(lsof -nP -t -iTCP:8189 -sTCP:LISTEN 2>/dev/null || true)"
        while IFS= read -r listener_pid; do
            [[ -n "$listener_pid" ]] || continue
            if is_comfy_process "$listener_pid"; then
                if [[ -n "$pid" ]]; then
                    echo "ERROR: Multiple ComfyUI processes are listening on port 8189." >&2
                    return 1
                fi
                pid="$listener_pid"
            fi
        done <<<"$listeners"
    fi

    if [[ -z "$pid" ]]; then
        if [[ -n "$(lsof -nP -t -iTCP:8189 -sTCP:LISTEN 2>/dev/null || true)" ]]; then
            echo "ERROR: Port 8189 is in use by a process that is not this ComfyUI installation." >&2
            return 1
        fi
        rm -f "$COMFY_PID_FILE"
        echo "ComfyUI is not running."
        return 0
    fi

    kill -TERM "$pid"
    for _ in {1..30}; do
        if ! is_comfy_process "$pid"; then
            rm -f "$COMFY_PID_FILE"
            echo "ComfyUI stopped (PID $pid). The dedicated Chrome window remains open."
            return 0
        fi
        sleep 1
    done

    echo "ERROR: ComfyUI (PID $pid) did not stop after SIGTERM; no force kill was sent." >&2
    return 1
}

action="${1:-start}"
if [[ "$#" -gt 1 || ( "$action" != "start" && "$action" != "stop" ) ]]; then
    echo "Usage: $0 [start|stop]" >&2
    exit 2
fi

if [[ "$action" == "stop" ]]; then
    stop_comfy
    exit $?
fi

if [[ ! -x "$CHROME" ]]; then
    echo "ERROR: Google Chrome was not found at $CHROME" >&2
    exit 1
fi

if ! comfy_ready; then
    mkdir -p "$(dirname "$COMFY_LOG")"
    echo "Starting ComfyUI at $COMFY_URL ..."
    nohup "$PYTHON" "$COMFY_ROOT/main.py" --listen 127.0.0.1 --port 8189 \
        >"$COMFY_LOG" 2>&1 </dev/null &
    comfy_pid="$!"
    printf '%s\n' "$comfy_pid" >"$COMFY_PID_FILE"

    ready=0
    for _ in {1..120}; do
        if comfy_ready; then
            ready=1
            break
        fi
        sleep 1
    done
    if [[ "$ready" != 1 ]]; then
        echo "ERROR: ComfyUI did not become ready. See $COMFY_LOG" >&2
        tail -n 40 "$COMFY_LOG" >&2
        exit 1
    fi
else
    echo "Reusing ComfyUI at $COMFY_URL."
fi

if curl --silent --show-error --fail --max-time 2 "$CDP_URL/json/version" >/dev/null 2>&1; then
    if ! cdp_has_comfy_tab; then
        echo "ERROR: Port 9223 is already serving a different Chrome session; refusing to attach." >&2
        exit 1
    fi
    echo "Reusing the dedicated Chrome window for $COMFY_URL."
else
    echo "Opening an isolated Chrome profile with local CDP on port 9223 ..."
    mkdir -p "$CHROME_PROFILE"
    nohup "$CHROME" \
        --user-data-dir="$CHROME_PROFILE" \
        --remote-debugging-address=127.0.0.1 \
        --remote-debugging-port=9223 \
        --remote-allow-origins="$CDP_URL" \
        --no-first-run \
        --no-default-browser-check \
        --new-window \
        "$COMFY_URL" >/dev/null 2>&1 </dev/null &

    ready=0
    for _ in {1..30}; do
        if cdp_has_comfy_tab; then
            ready=1
            break
        fi
        sleep 1
    done
    if [[ "$ready" != 1 ]]; then
        echo "ERROR: Dedicated Chrome did not expose a ComfyUI tab on $CDP_URL." >&2
        exit 1
    fi
fi

echo
echo "Ready: $COMFY_URL"
echo "Dedicated Chrome DevTools: $CDP_URL"
echo "MCP tools are configured for this ComfyUI workspace."
