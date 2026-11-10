import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest


class CaptureFixturesTests(unittest.TestCase):
    def test_login_credentials_round_trip_as_json(self):
        script = Path(__file__).resolve().parents[1] / "capture-fixtures.sh"
        username = 'synthetic"student'
        password = '虚构"password' + r'\n' + '\nsecond line'
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "scripts").mkdir()
            (root / ".secrets").mkdir()
            (root / "bin").mkdir()
            copy = root / "scripts" / script.name
            shutil.copyfile(script, copy)
            (root / ".secrets" / "account.env").write_text(
                f"JW_USER={shlex.quote(username)}\nJW_PASS={shlex.quote(password)}\n",
                encoding="utf-8",
            )

            curl = root / "bin" / "curl"
            curl.write_text(
                """#!/usr/bin/env python3
import sys

args = sys.argv[1:]
assert args[-1].endswith("/jw/login")
flag = "--data-binary" if "--data-binary" in args else "-d"
body = args[args.index(flag) + 1]
sys.stdout.buffer.write(sys.stdin.buffer.read() if body == "@-" else body.encode())
sys.exit(42)
""",
                encoding="utf-8",
            )
            curl.chmod(0o755)
            env = {**os.environ, "PATH": str(root / "bin") + os.pathsep + os.environ["PATH"]}
            run = subprocess.run(["bash", str(copy)], env=env, capture_output=True, timeout=10)

        self.assertEqual(run.returncode, 42, run.stderr.decode())
        self.assertEqual(json.loads(run.stdout), {"username": username, "password": password})


if __name__ == "__main__":
    unittest.main()
