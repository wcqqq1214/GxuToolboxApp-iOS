import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "sync-fixtures.py"


class SyncFixturesTests(unittest.TestCase):
    def make_tree(self, root):
        source = root / "Fixtures/sanitized"
        source.mkdir(parents=True)
        (source / "score.json").write_text('{"v":1}\n', encoding="utf-8")
        copy = root / "Packages/FeatureExam/Tests/ExamKitTests/Fixtures/score.json"
        copy.parent.mkdir(parents=True)
        own = copy.parent / "local-only.json"
        own.write_text('{"own":true}\n', encoding="utf-8")
        cached = root / "Packages/FeatureExam/.build/x/Tests/T/Fixtures/score.json"
        cached.parent.mkdir(parents=True)
        cached.write_text("stale\n", encoding="utf-8")
        return source / "score.json", copy, own, cached

    def run_script(self, root, *flags):
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--root", str(root), *flags],
            capture_output=True, text=True,
        )

    def test_check_reports_drift_and_write_restores_copies(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, copy, own, cached = self.make_tree(root)
            copy.write_text('{"v":0}\n', encoding="utf-8")

            failed = self.run_script(root)
            self.assertEqual(failed.returncode, 1)
            self.assertIn("ExamKitTests/Fixtures/score.json", failed.stderr)

            self.assertEqual(self.run_script(root, "--write").returncode, 0)
            self.assertEqual(copy.read_bytes(), source.read_bytes())
            self.assertEqual(own.read_text(encoding="utf-8"), '{"own":true}\n')
            self.assertEqual(cached.read_text(encoding="utf-8"), "stale\n")
            self.assertEqual(self.run_script(root).returncode, 0)


if __name__ == "__main__":
    unittest.main()
