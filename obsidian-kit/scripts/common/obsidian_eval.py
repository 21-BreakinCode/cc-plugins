"""Call the `obsidian` CLI. It exits 0 even on failure, so the output text decides."""
import json
import subprocess

CLI_TIMEOUT_SECONDS = 45
CLI_ERROR_PREFIX = "Error:"
EVAL_RESULT_PREFIX = "=> "


class ObsidianCliError(RuntimeError):
    pass


def parse_cli_output(stdout: str) -> str:
    output = stdout.strip()
    if output.startswith(CLI_ERROR_PREFIX):
        raise ObsidianCliError(output)
    return output


def run_cli(*args: str) -> str:
    try:
        completed = subprocess.run(["obsidian", *args], capture_output=True, text=True,
                                   timeout=CLI_TIMEOUT_SECONDS)
    except FileNotFoundError as missing_cli:
        raise ObsidianCliError("`obsidian` CLI not found on PATH") from missing_cli
    except subprocess.TimeoutExpired as timeout:
        raise ObsidianCliError(f"`obsidian {args[0]}` timed out after {CLI_TIMEOUT_SECONDS}s") from timeout
    if completed.returncode != 0:
        raise ObsidianCliError(completed.stderr.strip() or f"`obsidian {args[0]}` exited {completed.returncode}")
    return parse_cli_output(completed.stdout)


def run_app_script(js_body: str, args: dict) -> object:
    """Run `js_body` in the Obsidian window with `app` and `args` in scope. It must `return` JSON-able data."""
    wrapped_js = (
        "(async()=>{try{"
        f"const args={json.dumps(args)};"
        f"const result=await (async()=>{{{js_body}}})();"
        "return JSON.stringify({ok:true,result});"
        "}catch(e){return JSON.stringify({ok:false,error:String(e&&e.stack||e)});}})()"
    )
    output = run_cli("eval", f"code={wrapped_js}")
    result_lines = [line for line in output.splitlines() if line.startswith(EVAL_RESULT_PREFIX)]
    if not result_lines:
        raise ObsidianCliError(f"no result from `obsidian eval`: {output[-500:]}")
    payload = json.loads(result_lines[-1][len(EVAL_RESULT_PREFIX):])
    if not payload["ok"]:
        raise ObsidianCliError(payload["error"])
    return payload["result"]
