import pathlib
import sys
import tempfile
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS))

import config_loader as cl  # type: ignore # noqa: E402


class ConfigLoaderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.tmp_path = pathlib.Path(self.tmp.name)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def write_config(self, content: str, name: str = "config.toml") -> pathlib.Path:
        path = self.tmp_path / name
        path.write_text(content, encoding="utf-8")
        return path

    def test_merges_defaults_and_builds_payload(self) -> None:
        path = self.write_config(
            """
[prompt]
separator = "::"
[git]
show_status = false
            """
        )
        config = cl.load_config(path)
        self.assertEqual(config["prompt"]["separator"], "::")
        # Ensure a default carried through
        self.assertTrue(config["system"]["show_time"])

        payload = cl.build_shell_payload(config)
        self.assertIn('ZPE_SEPARATOR="::"', payload)
        self.assertIn('ZPE_GIT_CONF["show_status"]="False"', payload)

    def test_cache_hit_skips_reload(self) -> None:
        path = self.write_config("[prompt]\nseparator = '::'\n")
        cache_dir = self.tmp_path / "cache"

        payload1, used_cache1 = cl.load_config_cached(path, cache_dir)
        self.assertFalse(used_cache1)
        self.assertIn('ZPE_SEPARATOR="::"', payload1)

        with mock.patch.object(cl, "load_config", side_effect=AssertionError("should not load")):
            payload2, used_cache2 = cl.load_config_cached(path, cache_dir)

        self.assertTrue(used_cache2)
        self.assertEqual(payload1, payload2)

    def test_build_shell_payload_golden(self) -> None:
        """Golden test: verify expected shell assignments are emitted."""
        path = self.write_config(
            """
[prompt]
separator = " > "
enable_animation = false
frame_interval = 2

[modules]
order = ["art", "git"]
disabled = ["system"]

[git]
enabled = true
show_branch = true
show_status = false
max_branch_len = 15

[art]
enabled = true
frames = ["A", "B"]
            """
        )
        config = cl.load_config(path)
        payload = cl.build_shell_payload(config)

        # Check scalar assignments
        self.assertIn('ZPE_SEPARATOR=" > "', payload)
        self.assertIn('ZPE_ENABLE_ANIMATION=false', payload)
        self.assertIn('ZPE_FRAME_INTERVAL=2', payload)

        # Check arrays
        self.assertIn('typeset -ga ZPE_MODULE_ORDER=("art" "git")', payload)
        self.assertIn('typeset -ga ZPE_MODULES_DISABLED=("system")', payload)
        self.assertIn('typeset -ga ZPE_ART_FRAMES=("A" "B")', payload)

        # Check associative array entries
        self.assertIn('ZPE_GIT_CONF["show_branch"]="True"', payload)
        self.assertIn('ZPE_GIT_CONF["show_status"]="False"', payload)
        self.assertIn('ZPE_GIT_CONF["max_branch_len"]="15"', payload)


if __name__ == "__main__":
    unittest.main()
