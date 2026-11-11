import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


LINT = Path(__file__).resolve().parents[1] / "lint-no-comments.py"


class NoCommentsTests(unittest.TestCase):
    def test_lint_reports_comments_and_preserves_literals_and_directives(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q", directory], check=True)
            sources = {
                "Package.swift": ("// swift-tools-version: 6.0\n", "\n// extra\n", 3),
                "App.swift": (
                    'let url = "https://example.test"\nlet raw = #"/* literal */"#\n',
                    'let size = 2 /* outer /* inner */ */\n/// Documentation\n',
                    3,
                ),
                "tool.sh": (
                    '#!/bin/bash\nprintf "%s\\n" "${value#prefix}" "# literal"\n',
                    "true # inline\npython3 - <<'PY'\n# embedded\nPY\n",
                    3,
                ),
                "tool.py": ('#!/usr/bin/env python3\nvalue = "# literal"\n', 'value = "中文" # inline\n', 3),
                "project.yml": ('value: "# literal"\n', 'other: "value" # inline\n', 2),
                "PrivacyInfo.xcprivacy": ("<plist><string><![CDATA[<!-- literal -->]]></string>", "<!-- actual -->", 1),
                ".gitignore": ("\\#file\n  #literal pattern\n", "# actual\n", 3),
                ".editorconfig": ("root = true\n", "; actual\n", 2),
                "archive.env.example": ('OPTION="# literal"\n', "# actual\n", 2),
            }

            def run_lint():
                return subprocess.run([sys.executable, str(LINT)], cwd=root, capture_output=True, text=True)

            for path, (clean, _, _) in sources.items():
                closing = "</plist>\n" if path.endswith(".xcprivacy") else ""
                (root / path).write_text(clean + closing, encoding="utf-8")
            (root / "README.md").write_text("# Documentation\n", encoding="utf-8")
            vendor = root / ".agents/vendor"
            vendor.mkdir(parents=True)
            (vendor / "tool.swift").write_text("// Vendored source\n", encoding="utf-8")

            clean = run_lint()
            self.assertEqual(clean.returncode, 0, clean.stderr)

            for path, (original, comment, _) in sources.items():
                closing = "</plist>\n" if path.endswith(".xcprivacy") else ""
                (root / path).write_text(original + comment + closing, encoding="utf-8")

            failed = run_lint()
            self.assertEqual(failed.returncode, 1, failed.stderr)
            expected = {f"{path}:{line}: code comments are forbidden" for path, (_, _, line) in sources.items()}
            expected.update({"App.swift:4: code comments are forbidden", "tool.sh:5: code comments are forbidden"})
            self.assertEqual(set(failed.stderr.splitlines()), expected)


if __name__ == "__main__":
    unittest.main()
