#!/usr/bin/env python3
"""Reads every Swift file under iOS/ with a Swift parser and lists the places where the code does not
parse: a missing brace or bracket, a stray token, half a statement. It is a SYNTAX check only. It does
not compile, so it cannot find a wrong type, a missing import or a name that does not exist; only
Xcode finds those. Its use is to catch the plain typing slips a patch can carry before it is pasted.

Needs two small packages once:  pip install tree-sitter tree-sitter-swift
Run it from anywhere:           python3 scripts/check-swift-syntax.py
Exit code 0 means every file parsed, 1 means at least one did not, 2 means the packages are missing.
"""
import pathlib
import sys

try:
    import tree_sitter_swift
    from tree_sitter import Language, Parser
except ImportError:
    print("Needs the packages tree-sitter and tree-sitter-swift: pip install tree-sitter tree-sitter-swift")
    sys.exit(2)

root = pathlib.Path(__file__).resolve().parent.parent
parser = Parser(Language(tree_sitter_swift.language()))


def problems(node, found):
    if node.type == "ERROR" or node.is_missing:
        found.append(node)
        return
    for child in node.children:
        if child.has_error:
            problems(child, found)


files = sorted((root / "iOS").rglob("*.swift"))
bad = 0
for path in files:
    source = path.read_bytes()
    tree = parser.parse(source)
    if not tree.root_node.has_error:
        continue
    bad += 1
    lines = source.splitlines()
    found = []
    problems(tree.root_node, found)
    for node in found[:3]:
        line = min(node.start_point[0] + 1, max(len(lines), 1))
        text = lines[line - 1].decode("utf8", "replace").strip()[:110] if lines else ""
        kind = "missing token" if node.is_missing else "does not parse"
        print(f"{path.relative_to(root)}:{line}: {kind}: {text}")

print(f"{len(files)} Swift files read, {bad} with syntax problems. This is a syntax check only, not a compile.")
sys.exit(1 if bad else 0)
