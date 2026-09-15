# ComfyUI-agentic browser-control protocol

## Scope and safety

- This companion operates only the one local portable ComfyUI installation that contains these files (or their hard links). Do not alter any other installation unless the user explicitly names it.
- The dedicated browser is local-only: ComfyUI is `http://127.0.0.1:8189` and Chrome DevTools Protocol (CDP) is `http://127.0.0.1:9223`.
- Control only the Chrome process that uses `.codex-chrome-profile`. Never attach to the user's regular Chrome profile, unrelated tabs, or a non-local CDP endpoint.
- Do not close browser windows, stop ComfyUI, delete workflows, overwrite a named workflow, or remove models unless the user explicitly asks.
- Do not expose CDP to the network or change its `127.0.0.1` binding.

## Starting the environment

- The user normally starts `run_comfyui_cdp.bat`; it starts the companion server script when needed and opens the dedicated Chrome window. A local installation may retain a differently named hard link for compatibility.
- Do not instruct the user to run `run_comfyui_cdp_server.bat` directly unless diagnosing the server only.
- Chrome DevTools does not need to be enabled manually. The main BAT starts Chrome with the required local CDP flags.
- Before using browser control, check `http://127.0.0.1:8189/system_stats` and `http://127.0.0.1:9223/json/list`.

## Inspect before changing

- Use `tools/Invoke-CdpEvaluate.ps1` with a WebSocket URL returned by `/json/list`. Select only a `type: page` target whose URL starts with `http://127.0.0.1:8189`.
- If several ComfyUI pages exist, identify the target by its title and ask the user to choose when the title does not make the choice clear.
- Read the live graph, nodes, links, and widget values before proposing edits. Do not rely on workflow details from an earlier session.
- A widget may be driven by a linked node. Follow the link upstream and modify the real source rather than an overridden downstream widget.

## Changes and generation

- Adding, removing, or rewiring nodes; changing model files or parameters; editing prompts; loading input images; and queueing a generation all require an explicit user request.
- Preserve a reversible comparison path when practical: leave a disconnected previous node on the canvas rather than deleting it, and label it clearly.
- After a browser-side edit, verify the effective graph with `app.graphToPrompt()` before queueing. Check the actual serialized inputs, not only displayed widget values.
- Queue only the generation requested by the user. Keep a fixed seed when comparing settings unless the user asks for variation.
- After a run, inspect the local ComfyUI history and output. Report the output file, the effective important settings, and any limitation observed.

## Models, references, and persistence

- Store models only under `ComfyUI/models/` in this installation. Download or replace models only after the user approves the download.
- Reference images belong in `ComfyUI/input/`. Do not use files from other locations without the user's permission.
- An image-to-image test changes the KSampler latent input from `EmptySD3LatentImage` to `Load Image -> VAE Encode`. Make the denoise value explicit and preserve the former text-to-image branch for comparison.
- Do not assume browser state is a saved workflow. Tell the user when the canvas has unsaved changes; the output PNG embeds the executed graph.
