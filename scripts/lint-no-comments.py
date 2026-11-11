import io
import json
import os
import re
import subprocess
import sys
import tokenize
from pathlib import Path
from xml.parsers import expat

import tree_sitter_bash
import tree_sitter_yaml
from tree_sitter import Language, Parser


SHELL = Parser(Language(tree_sitter_bash.language()))
YAML = Parser(Language(tree_sitter_yaml.language()))
EXCLUDED_DIRECTORIES = (".agents/vendor/", ".agents/skills/swiftui-pro/")
SOURCE_SUFFIXES = {".swift", ".sh", ".py", ".yaml", ".yml", ".xcprivacy", ".plist", ".entitlements"}
CONFIG_NAMES = {".gitignore", ".editorconfig"}
SWIFT_TOOLS_VERSION = re.compile(rb"// swift-tools-version: [0-9]+\.[0-9]+(?:\.[0-9]+)?")
SHEBANG = re.compile(rb"#![ \t]*/[^\s]+(?:[ \t]+[^\r\n]+)?")


def swift_comments(paths):
    if not paths:
        return {}
    swift = Path(subprocess.check_output(["xcrun", "--find", "swift"], text=True).strip())
    host = swift.parent.parent / "lib/swift/host"
    scanner = Path(__file__).with_name("lint-swift-comments.swift").resolve()
    return json.loads(subprocess.check_output([
        str(swift), "-I", str(host), "-L", str(host), "-Xlinker", "-rpath", "-Xlinker", str(host),
        str(scanner), *paths,
    ]))


def syntax_comments(parser, source):
    root = parser.parse(source).root_node
    if root.has_error:
        raise ValueError("could not parse source")
    pending = [root]
    while pending:
        node = pending.pop()
        if node.type == "comment":
            yield node.start_byte, node.end_byte
        if node.type == "heredoc_redirect":
            marker = next(child.text for child in node.named_children if child.type == "heredoc_end")
            body = next((child for child in node.named_children if child.type == "heredoc_body"), None)
            if body is not None and marker == b"PY":
                for start, end in python_comments(body.text):
                    yield body.start_byte + start, body.start_byte + end
        pending.extend(reversed(node.named_children))


def python_comments(source):
    offset = 0
    line_offsets = [offset]
    for line in io.BytesIO(source):
        offset += len(line)
        line_offsets.append(offset)
    for token in tokenize.tokenize(io.BytesIO(source).readline):
        if token.type == tokenize.COMMENT:
            line, column = token.start
            start = line_offsets[line - 1] + len(token.line[:column].encode())
            yield start, start + len(token.string.encode())


def xml_comments(source):
    parser = expat.ParserCreate()
    comments = []

    def record(_):
        start = parser.CurrentByteIndex
        comments.append((start, source.index(b"-->", start) + 3))

    parser.CommentHandler = record
    parser.Parse(source, True)
    return comments


def comment_ranges(path, source, swift_ranges):
    suffix = Path(path).suffix
    if suffix == ".swift":
        return swift_ranges.get(path, ())
    if suffix == ".sh" or path.endswith(".env.example"):
        return syntax_comments(SHELL, source)
    if suffix == ".py":
        return python_comments(source)
    if suffix in {".yml", ".yaml"}:
        return syntax_comments(YAML, source)
    if suffix in {".xcprivacy", ".plist", ".entitlements"}:
        return xml_comments(source)
    if Path(path).name in CONFIG_NAMES:
        prefix = rb"[ \t]*[#;]" if Path(path).name == ".editorconfig" else rb"#"
        return (match.span() for match in re.finditer(rb"(?m)^" + prefix + rb"[^\r\n]*", source))
    return ()


def is_required_directive(path, source, start, end):
    if start != 0:
        return False
    if Path(path).name == "Package.swift" and SWIFT_TOOLS_VERSION.fullmatch(source[start:end]):
        return True
    return Path(path).suffix in {".sh", ".py"} and SHEBANG.fullmatch(source[start:end]) is not None


def violations(paths):
    swift_ranges = swift_comments([path for path in paths if path.endswith(".swift")])
    for path in paths:
        source = Path(path).read_bytes()
        try:
            for start, end in comment_ranges(path, source, swift_ranges):
                if not is_required_directive(path, source, start, end):
                    line = source.count(b"\n", 0, start) + 1
                    yield f"{path}:{line}: code comments are forbidden"
        except (ValueError, SyntaxError, tokenize.TokenError, expat.ExpatError) as error:
            yield f"{path}: {error}"


def main():
    files = subprocess.check_output(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"])
    paths = sorted({
        path for path in os.fsdecode(files).split("\0")
        if path and not path.startswith(EXCLUDED_DIRECTORIES) and Path(path).is_file()
        and (Path(path).suffix in SOURCE_SUFFIXES or Path(path).name in CONFIG_NAMES or path.endswith(".env.example"))
    })
    failed = False
    for message in violations(paths):
        print(message, file=sys.stderr)
        failed = True
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
