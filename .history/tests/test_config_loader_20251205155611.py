import pathlib
import sys
import tempfile
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS))

import config_loader as cl  # noqa: E402


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


if __name__ == "__main__":
    unittest.main()
