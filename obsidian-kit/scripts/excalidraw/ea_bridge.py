"""Run ExcalidrawAutomate JavaScript inside the running Obsidian app.

The `obsidian eval` CLI executes code in the Obsidian window, where the
Excalidraw plugin exposes `window.ExcalidrawAutomate`. Obsidian must be open.
"""
import json
import subprocess

EVAL_TIMEOUT_SECONDS = 45
EVAL_ATTEMPTS = 2
RESULT_PREFIX = "=> "


class ObsidianBridgeError(RuntimeError):
    pass


def _run_obsidian_eval(wrapped_js: str) -> subprocess.CompletedProcess:
    # Obsidian sometimes stalls one eval right after a heavy render; one retry clears it.
    for attempt in range(1, EVAL_ATTEMPTS + 1):
        try:
            return subprocess.run(
                ["obsidian", "eval", f"code={wrapped_js}"],
                capture_output=True, text=True, timeout=EVAL_TIMEOUT_SECONDS,
            )
        except FileNotFoundError as missing_cli:
            raise ObsidianBridgeError("`obsidian` CLI not found on PATH") from missing_cli
        except subprocess.TimeoutExpired:
            if attempt == EVAL_ATTEMPTS:
                raise ObsidianBridgeError(f"`obsidian eval` timed out {EVAL_ATTEMPTS}x after {EVAL_TIMEOUT_SECONDS}s")


def run_ea_script(js_body: str, args: dict) -> object:
    """Run `js_body` with `ea` and `args` in scope. The body must `return` a JSON-able value."""
    wrapped_js = (
        "(async()=>{try{"
        "const ea=window.ExcalidrawAutomate.getAPI();"
        f"const args={json.dumps(args)};"
        f"const result=await (async()=>{{{js_body}}})();"
        "return JSON.stringify({ok:true,result});"
        "}catch(e){return JSON.stringify({ok:false,error:String(e&&e.stack||e)});}})()"
    )
    completed = _run_obsidian_eval(wrapped_js)

    result_lines = [line for line in completed.stdout.splitlines() if line.startswith(RESULT_PREFIX)]
    if not result_lines:
        raise ObsidianBridgeError(
            "no result from `obsidian eval` (is Obsidian open?)\n"
            f"stdout: {completed.stdout[-500:]}\nstderr: {completed.stderr[-500:]}"
        )
    payload = json.loads(result_lines[-1][len(RESULT_PREFIX):])
    if not payload["ok"]:
        raise ObsidianBridgeError(payload["error"])
    return payload["result"]
