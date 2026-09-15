# ComfyUI-agentic control rules

- This repository is a companion for one local portable ComfyUI installation. Operate only that installation and its dedicated Chrome profile.
- Start `run_comfyui_cdp.bat` for normal use. It starts ComfyUI on `127.0.0.1:8189` and Chrome CDP on `127.0.0.1:9223`.
- Do not attach to ordinary Chrome, unrelated browser tabs, a remote CDP endpoint, or another ComfyUI installation.
- Inspect `/system_stats`, `/json/list`, and the live workflow before changing anything. When several ComfyUI tabs are present, identify the intended one by title or ask the user to choose.
- Do not add, remove, or rewire nodes; change prompts, models, parameters, or inputs; or queue work unless the user explicitly requests it.
- Follow widget links upstream: a visible downstream widget may be overridden by another node.
- After a change, verify the actual queue payload with `app.graphToPrompt()` before generation. Keep a fixed seed for requested comparisons.
- Do not stop servers, close tabs, delete models, overwrite named workflows, or expose CDP beyond `127.0.0.1` without explicit permission.
- Store models in `ComfyUI/models/`, reference images in `ComfyUI/input/`, and report the generated output path after a run.
