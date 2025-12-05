"""
Parse a user config (TOML or YAML) and emit Zsh-friendly assignments.
The output is meant to be eval'd by the shell.
"""
from __future__ import annotations
"""
Parse a user config (TOML or YAML) and emit Zsh-friendly assignments.
The output is meant to be eval'd by the shell.
Includes a small cache keyed by config mtime and defaults fingerprint to
avoid re-parsing on repeated runs.
"""
from typing import Any, Dict, Iterable, List

import hashlib
try:
import os
    import tomllib  # type: ignore[attr-defined]
except ModuleNotFoundError:  # pragma: no cover
    try:
        import tomli as tomllib  # type: ignore
    except ModuleNotFoundError:  # pragma: no cover
        tomllib = None  # type: ignore

try:
    import yaml  # type: ignore
except ModuleNotFoundError:  # pragma: no cover
    yaml = None


DEFAULTS: Dict[str, Any] = {
    "prompt": {
        "separator": " | ",
        "enable_animation": True,
        "frame_interval": 1,
    },
    "modules": {
        "order": ["art", "project", "git", "system", "kubectl", "venv", "battery"],
    },
    "git": {
        "show_branch": True,
        "show_status": True,
    },
    "system": {
        "show_time": True,
        "show_load": True,
    },
    "colors": {
        "primary": "cyan",
        "muted": "white",
        "accent": "magenta",
    },
    "art": {
        "frames": ["(>", "=>", ">="]
    },
    "kubectl": {
        "show_namespace": True,
    },
    "venv": {
        "show_prefix": True,
    },
    "battery": {
        "show_status": True,
    },
}

CACHE_SCHEMA = 1


class ConfigError(RuntimeError):
    pass


def defaults_fingerprint() -> str:
    serialized = json.dumps(DEFAULTS, sort_keys=True).encode()
    return hashlib.sha256(serialized).hexdigest()


def load_config(path: pathlib.Path) -> Dict[str, Any]:
    if tomllib is None:
        raise ConfigError("tomllib/tomli missing; install tomli or use Python 3.11+")
    if not path.exists():
        raise ConfigError(f"config file not found: {path}")
    text = path.read_text(encoding="utf-8")
    suffix = path.suffix.lower()
    if suffix in {".toml", ".tml", ""}:
        data = tomllib.loads(text)
    elif suffix in {".yaml", ".yml"}:
        if yaml is None:
            raise ConfigError("pyyaml is required for YAML configs")
        data = yaml.safe_load(text) or {}
    else:
        # Try TOML first, then YAML as fallback
        try:
            data = tomllib.loads(text)
        except Exception as first_err:  # pragma: no cover
            if yaml is None:
                raise ConfigError(f"Could not parse {path}: {first_err}")
            data = yaml.safe_load(text) or {}
    return merge(DEFAULTS, data or {})


def merge(base: Dict[str, Any], override: Dict[str, Any]) -> Dict[str, Any]:
    result: Dict[str, Any] = json.loads(json.dumps(base))
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = value
    return result


def sh_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("\"", "\\\"")


def emit_array(name: str, values: Iterable[str]) -> str:
    items = " ".join(f'"{sh_escape(v)}"' for v in values)
    return f"typeset -ga {name}=({items})\n"


def emit_assoc(name: str, mapping: Dict[str, Any]) -> str:
    lines = [f"typeset -gA {name}\n"]
    for key, value in mapping.items():
        lines.append(f'{name}["{sh_escape(str(key))}"]="{sh_escape(str(value))}"\n')
    return "".join(lines)


def build_shell_payload(config: Dict[str, Any]) -> str:
    prompt_cfg = config.get("prompt", {})
    modules_cfg = config.get("modules", {})
    git_cfg = config.get("git", {})
    system_cfg = config.get("system", {})
    color_cfg = config.get("colors", {})
    art_cfg = config.get("art", {})
    kube_cfg = config.get("kubectl", {})
    venv_cfg = config.get("venv", {})
    battery_cfg = config.get("battery", {})

    payload: List[str] = []
    payload.append(f'ZPE_SEPARATOR="{sh_escape(str(prompt_cfg.get("separator", " | ")))}"\n')
    payload.append(f'ZPE_ENABLE_ANIMATION={str(prompt_cfg.get("enable_animation", True)).lower()}\n')
    payload.append(f'ZPE_FRAME_INTERVAL={int(prompt_cfg.get("frame_interval", 1))}\n')

    payload.append(emit_array("ZPE_MODULE_ORDER", modules_cfg.get("order", [])))
    payload.append(emit_array("ZPE_ART_FRAMES", art_cfg.get("frames", [])))

    payload.append(emit_assoc("ZPE_GIT_CONF", git_cfg))
    payload.append(emit_assoc("ZPE_SYSTEM_CONF", system_cfg))
    payload.append(emit_assoc("ZPE_COLOR_CONF", color_cfg))
    payload.append(emit_assoc("ZPE_KUBE_CONF", kube_cfg))
    payload.append(emit_assoc("ZPE_VENV_CONF", venv_cfg))
    payload.append(emit_assoc("ZPE_BATTERY_CONF", battery_cfg))

    return "".join(payload)


def cache_dir_from_env() -> Optional[pathlib.Path]:
    env_value = os.environ.get("ZPE_CACHE_DIR")
    if not env_value:
        return None
    return pathlib.Path(env_value).expanduser().resolve()


def cache_file_for(config_path: pathlib.Path, cache_dir: pathlib.Path) -> pathlib.Path:
    digest = hashlib.sha256(str(config_path).encode()).hexdigest()[:16]
    return cache_dir / f"{digest}.json"


def read_cache(cache_file: pathlib.Path, mtime_ns: int, fingerprint: str) -> Optional[str]:
    if not cache_file.exists():
        return None
    try:
        cached = json.loads(cache_file.read_text(encoding="utf-8"))
    except Exception:
        return None
    if cached.get("schema") != CACHE_SCHEMA:
        return None
    if cached.get("config_mtime_ns") != mtime_ns:
        return None
    if cached.get("defaults_hash") != fingerprint:
        return None
    payload = cached.get("payload")
    if not isinstance(payload, str):
        return None
    return payload


def write_cache(cache_file: pathlib.Path, mtime_ns: int, fingerprint: str, payload: str) -> None:
    cache_file.parent.mkdir(parents=True, exist_ok=True)
    blob = {
        "schema": CACHE_SCHEMA,
        "config_mtime_ns": mtime_ns,
        "defaults_hash": fingerprint,
        "payload": payload,
    }
    cache_file.write_text(json.dumps(blob), encoding="utf-8")


def load_config_cached(
    path: pathlib.Path,
    cache_dir: Optional[pathlib.Path] = None,
) -> Tuple[str, bool]:
    """
    Return (payload, used_cache).
    If cache_dir is None, caching is skipped.
    """

    mtime_ns = path.stat().st_mtime_ns
    fingerprint = defaults_fingerprint()

    if cache_dir is not None:
        cache_file = cache_file_for(path, cache_dir)
        cached_payload = read_cache(cache_file, mtime_ns, fingerprint)
        if cached_payload is not None:
            return cached_payload, True

    config = load_config(path)
    payload = build_shell_payload(config)

    if cache_dir is not None:
        write_cache(cache_file, mtime_ns, fingerprint, payload)

    return payload, False


def main() -> int:
    if len(sys.argv) < 2:
        raise SystemExit("Usage: config_loader.py <path-to-config>")
    path = pathlib.Path(sys.argv[1]).expanduser().resolve()
    cache_dir = cache_dir_from_env()
    try:
        payload, _ = load_config_cached(path, cache_dir)
    except ConfigError as err:
        print(err, file=sys.stderr)
        return 1
    except Exception as err:  # pragma: no cover - defensive
        print(f"unexpected error: {err}", file=sys.stderr)
        return 1

    sys.stdout.write(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
