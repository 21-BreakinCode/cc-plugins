"""Find the vault, load .obsidian-kit.json, and check that Obsidian is running."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.obsidian_eval import ObsidianCliError, run_cli  # noqa: E402

CONFIG_NAME = ".obsidian-kit.json"
REQUIRED_KEYS = ("taxonomyPath", "noteFormatFolders", "excludedPaths", "typeFolders")
OBSIDIAN_CLOSED_MESSAGE = "Open Obsidian, then run again."


class VaultConfigError(RuntimeError):
    pass


def find_vault_root(start: Path) -> Path:
    for folder in (start, *start.parents):
        if (folder / ".obsidian").is_dir():
            return folder
    raise VaultConfigError(f"no .obsidian/ folder at or above {start}")


def load_config(vault_root: Path) -> dict:
    config_path = vault_root / CONFIG_NAME
    if not config_path.is_file():
        raise VaultConfigError(f"create {config_path} first (see the spec's Vault config section)")
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as decode_error:
        raise VaultConfigError(f"{config_path} is not valid JSON: {decode_error}") from decode_error
    missing_keys = [key for key in REQUIRED_KEYS if key not in config]
    if missing_keys:
        raise VaultConfigError(f"{config_path} is missing keys: {', '.join(missing_keys)}")
    return config


def is_under(path: str, folders: list[str]) -> bool:
    return any(path == folder.rstrip("/") or path.startswith(folder.rstrip("/") + "/") for folder in folders)


def is_excluded(path: str, config: dict) -> bool:
    return is_under(path, config["excludedPaths"])


def is_in_scope(path: str, config: dict) -> bool:
    return is_under(path, config["noteFormatFolders"]) and not is_excluded(path, config)


def require_obsidian_running() -> None:
    try:
        run_cli("version")
    except ObsidianCliError:
        print(OBSIDIAN_CLOSED_MESSAGE, file=sys.stderr)
        sys.exit(1)
