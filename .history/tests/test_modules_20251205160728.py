import os
import pathlib
import subprocess
import textwrap
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
ZPE_SCRIPT = ROOT / "src" / "zpe.zsh"


def run_zsh(script: str, extra_env: dict | None = None) -> str:
    env = os.environ.copy()
    env.update({
        "ZPE_ROOT": str(ROOT),
        "ZPE_SCRIPT": str(ZPE_SCRIPT),
    })
    if extra_env:
        env.update(extra_env)
    result = subprocess.run(
        ["zsh", "-c", script],
        capture_output=True,
        text=True,
        env=env,
    )
    if result.returncode != 0:
        raise RuntimeError(f"zsh failed: {result.stderr}")
    return result.stdout.strip()


class ModuleTests(unittest.TestCase):
    def test_art_module_uses_frame(self) -> None:
        script = textwrap.dedent(
            """
            emulate -L zsh
            source "$ZPE_SCRIPT"
            zpe_register_default_modules
            ZPE_ART_FRAMES=("<>")
            ZPE_FRAME_INDEX=0
            ZPE_ENABLE_ANIMATION=false
            print -- "$(zpe_module_art)"
            """
        )
        out = run_zsh(script)
        self.assertIn("<>", out)

    def test_venv_module_reads_virtual_env(self) -> None:
        script = textwrap.dedent(
            """
            emulate -L zsh
            source "$ZPE_SCRIPT"
            zpe_register_default_modules
            VIRTUAL_ENV="/tmp/.venv-example"
            print -- "$(zpe_module_venv)"
            """
        )
        out = run_zsh(script)
        self.assertIn("venv:.venv-example", out)

    def test_kubectl_module_respects_namespace(self) -> None:
        script = textwrap.dedent(
            """
            emulate -L zsh
            source "$ZPE_SCRIPT"
            zpe_register_default_modules
            function zpe__kubectl_current_context() { print demo-context; }
            function zpe__kubectl_namespace() { print dev; }
            ZPE_KUBE_CONF[show_namespace]="true"
            print -- "$(zpe_module_kubectl)"
            """
        )
        out = run_zsh(script)
        self.assertIn("k8s:demo-context/dev", out)

    def test_battery_module_uses_stubbed_status(self) -> None:
        script = textwrap.dedent(
            """
            emulate -L zsh
            source "$ZPE_SCRIPT"
            zpe_register_default_modules
            function zpe__battery_percent_and_status() { print -- "42|Charging"; }
            ZPE_BATTERY_CONF[show_status]=true
            print -- "$(zpe_module_battery)"
            """
        )
        out = run_zsh(script)
        self.assertIn("bat:42%+", out)

    def test_full_prompt_render_with_multiple_modules(self) -> None:
        """Render a full prompt with stubbed modules and verify segments."""
        script = textwrap.dedent(
            """
            emulate -L zsh
            source "$ZPE_SCRIPT"
            zpe_register_default_modules

            # Stub helpers so modules produce predictable output
            function zpe__git_is_repo() { return 0; }
            function zpe__git_branch() { print main; }
            function zpe__git_dirty_counts() { print 1 2 0; }
            function zpe__kubectl_current_context() { return 1; }  # disabled
            function zpe__battery_percent_and_status() { return 1; }  # disabled
            VIRTUAL_ENV=""

            # Configure modules
            ZPE_MODULE_ORDER=(art project git)
            ZPE_MODULES_DISABLED=()
            ZPE_SEPARATOR=" | "
            ZPE_ART_FRAMES=(">>")
            ZPE_FRAME_INDEX=0
            ZPE_ENABLE_ANIMATION=false
            ZPE_GIT_CONF[enabled]=true
            ZPE_GIT_CONF[show_branch]=true
            ZPE_GIT_CONF[show_status]=true
            ZPE_GIT_CONF[max_branch_len]=0
            ZPE_PROJECT_CONF[enabled]=true
            ZPE_PROJECT_CONF[max_path_len]=0
            ZPE_ART_CONF[enabled]=true

            zpe_render_prompt
            print -r -- "$PROMPT"
            """
        )
        out = run_zsh(script)
        # Expect segments: art (>>), project (proj:<dir>), git (git:main +1 ~2)
        self.assertIn(">>", out)
        self.assertIn("proj:", out)
        self.assertIn("git:main", out)
        self.assertIn("+1", out)
        self.assertIn("~2", out)
        # Separator variable should be in the rendered PROMPT (joined segments)
        self.assertIn("ZPE_SEPARATOR", out)


if __name__ == "__main__":
    unittest.main()
