import argparse
import shutil
import sys
from pathlib import Path


def package_copies(root):
    source = root / "Fixtures/sanitized"
    names = {path.name for path in source.glob("*.json")}
    for copy in sorted((root / "Packages").glob("*/Tests/**/Fixtures/*.json")):
        if ".build" not in copy.parts and copy.name in names:
            yield source / copy.name, copy


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = args.root.resolve()
    stale = []
    for source, copy in package_copies(root):
        if source.read_bytes() == copy.read_bytes():
            continue
        if args.write:
            shutil.copyfile(source, copy)
            print(f"updated {copy.relative_to(root)}")
        else:
            stale.append(copy.relative_to(root))
    for path in stale:
        print(f"{path}: differs from Fixtures/sanitized/{path.name}", file=sys.stderr)
    if stale:
        print("运行 python3 scripts/sync-fixtures.py --write 同步样本", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
