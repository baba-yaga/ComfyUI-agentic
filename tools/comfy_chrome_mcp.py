import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path


COMFY_URL = os.environ.get("COMFYUI_AGENTIC_COMFY_URL", "http://127.0.0.1:8189")
CDP_URL = os.environ.get("COMFYUI_AGENTIC_CDP_URL", "http://127.0.0.1:9223")
HELPER = Path(__file__).with_name("Invoke-CdpEvaluate.ps1")
INSTRUCTIONS = (
    "This server controls only the dedicated local Chrome profile opened by "
    "run_comfyui_cdp.bat. Inspect the workflow before changing it. Do not edit "
    "nodes, queue a generation, or run arbitrary JavaScript unless the user "
    "explicitly requested that action."
)


def http_json(path):
    request = urllib.request.Request(f"{CDP_URL}{path}")
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.load(response)


def comfy_ready():
    request = urllib.request.Request(f"{COMFY_URL}/system_stats")
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.load(response)


def get_tab(tab_id=None):
    pages = [
        target
        for target in http_json("/json/list")
        if target.get("type") == "page"
        and target.get("url", "").startswith(COMFY_URL)
    ]
    if tab_id:
        pages = [target for target in pages if target.get("id") == tab_id]
    if not pages:
        raise RuntimeError("No dedicated ComfyUI Chrome tab is available.")
    if not tab_id and len(pages) > 1:
        raise RuntimeError("Multiple ComfyUI tabs are open. Provide a tab_id from comfy_chrome_status.")
    return pages[0]


def evaluate(script, tab_id=None):
    tab = get_tab(tab_id)
    result = subprocess.run(
        [
            "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
            str(HELPER), "-WebSocketDebuggerUrl", tab["webSocketDebuggerUrl"],
            "-Expression", script,
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=60,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    payload = json.loads(result.stdout)
    remote_result = payload.get("result", {}).get("result", {})
    if "exceptionDetails" in remote_result:
        raise RuntimeError(remote_result["exceptionDetails"].get("text", "JavaScript failed."))
    return remote_result.get("value", remote_result)


def tool_result(value, is_error=False):
    return {"content": [{"type": "text", "text": json.dumps(value, ensure_ascii=False)}], "isError": is_error}


def workflow_inspect(arguments):
    return evaluate(
        """(() => {
            const app = window.comfyAPI?.app?.app ?? window.app;
            const graph = app?.rootGraph ?? app?.graph;
            if (!graph) throw new Error('ComfyUI graph is not ready.');
            return graph._nodes.map(node => ({
                id: node.id, type: node.type, title: node.title,
                widgets: (node.widgets || []).map(widget => ({name: widget.name, value: widget.value})),
                inputs: (node.inputs || []).map(input => ({name: input.name, link: input.link}))
            }));
        })()""",
        arguments.get("tab_id"),
    )


def set_text(arguments):
    node_id = arguments["node_id"]
    widget_name = arguments.get("widget_name", "text")
    text = arguments["text"]
    script = f"""(async () => {{
        const app = window.comfyAPI?.app?.app ?? window.app;
        const graph = app?.rootGraph ?? app?.graph;
        const node = graph?.getNodeById({json.dumps(node_id)});
        const widget = node?.widgets?.find(item => item.name === {json.dumps(widget_name)});
        const element = widget?.element;
        if (!element) throw new Error('The requested text widget has no visible input element.');
        element.focus();
        element.value = {json.dumps(text, ensure_ascii=False)};
        element.dispatchEvent(new InputEvent('input', {{bubbles: true, inputType: 'insertText'}}));
        element.dispatchEvent(new Event('change', {{bubbles: true}}));
        element.blur();
        const prompt = await app.graphToPrompt();
        return {{nodeId: node.id, widget: widget.name, screenValue: element.value,
                 serializedInputs: prompt.output?.[String(node.id)]?.inputs}};
    }})()"""
    return evaluate(script, arguments.get("tab_id"))


def queue_workflow(arguments):
    return evaluate(
        """(async () => {
            const app = window.comfyAPI?.app?.app ?? window.app;
            if (!app?.graphToPrompt) throw new Error('ComfyUI graph is not ready.');
            return {queued: await app.queuePrompt(0), title: document.title};
        })()""",
        arguments.get("tab_id"),
    )


TOOLS = [
    {"name": "comfy_chrome_status", "description": "Read local ComfyUI and dedicated Chrome status.", "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False}, "annotations": {"readOnlyHint": True}},
    {"name": "comfy_workflow_inspect", "description": "Read workflow nodes, widgets, and links before editing.", "inputSchema": {"type": "object", "properties": {"tab_id": {"type": "string"}}, "additionalProperties": False}, "annotations": {"readOnlyHint": True}},
    {"name": "comfy_set_text", "description": "Set a visible text widget and report the serialized inputs.", "inputSchema": {"type": "object", "properties": {"node_id": {"type": ["integer", "string"]}, "widget_name": {"type": "string"}, "text": {"type": "string"}, "tab_id": {"type": "string"}}, "required": ["node_id", "text"], "additionalProperties": False}},
    {"name": "comfy_queue_workflow", "description": "Queue the current workflow only after an explicit user request.", "inputSchema": {"type": "object", "properties": {"tab_id": {"type": "string"}}, "additionalProperties": False}},
    {"name": "comfy_run_javascript", "description": "Run specifically requested JavaScript only in the dedicated local ComfyUI tab.", "inputSchema": {"type": "object", "properties": {"javascript": {"type": "string"}, "tab_id": {"type": "string"}}, "required": ["javascript"], "additionalProperties": False}},
]


def call_tool(name, arguments):
    if name == "comfy_chrome_status":
        stats = comfy_ready()
        device = (stats.get("devices") or [{}])[0]
        return {"comfy": {"url": COMFY_URL, "version": stats.get("system", {}).get("comfyui_version"), "device": device.get("name")}, "tabs": [{"id": tab.get("id"), "title": tab.get("title"), "url": tab.get("url")} for tab in http_json("/json/list") if tab.get("type") == "page" and tab.get("url", "").startswith(COMFY_URL)]}
    if name == "comfy_workflow_inspect":
        return workflow_inspect(arguments)
    if name == "comfy_set_text":
        return set_text(arguments)
    if name == "comfy_queue_workflow":
        return queue_workflow(arguments)
    if name == "comfy_run_javascript":
        return evaluate(arguments["javascript"], arguments.get("tab_id"))
    raise RuntimeError(f"Unknown tool: {name}")


def respond(message_id, result):
    print(json.dumps({"jsonrpc": "2.0", "id": message_id, "result": result}, ensure_ascii=False), flush=True)


for line in sys.stdin:
    message_id = None
    try:
        request = json.loads(line)
        message_id = request.get("id")
        method = request.get("method")
        params = request.get("params", {})
        if method == "initialize":
            respond(message_id, {"protocolVersion": "2025-03-26", "capabilities": {"tools": {}}, "serverInfo": {"name": "comfy-chrome", "version": "1.0.0"}, "instructions": INSTRUCTIONS})
        elif method == "tools/list":
            respond(message_id, {"tools": TOOLS})
        elif method == "tools/call":
            try:
                respond(message_id, tool_result(call_tool(params["name"], params.get("arguments", {}))))
            except Exception as error:
                respond(message_id, tool_result({"error": str(error)}, True))
        elif method == "ping":
            respond(message_id, {})
        elif message_id is not None:
            respond(message_id, {"error": {"code": -32000, "message": f"Unsupported method: {method}"}})
    except Exception as error:
        if message_id is not None:
            respond(message_id, {"error": {"code": -32000, "message": str(error)}})
