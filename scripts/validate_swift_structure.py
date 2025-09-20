#!/usr/bin/env python3
import sys, os, re
from pathlib import Path

# Simple Swift structure validator
# - Balances (), {}, []
# - Detects duplicate type names in a single file (struct/class/enum with same name)
# - Detects common SwiftUI view scoping mistakes (private types at top level)

PAIR = {')':'(', '}':'{', ']':'['}
OPEN = set(PAIR.values())
CLOSE = set(PAIR.keys())

TYPE_RE = re.compile(r'\b(struct|class|enum)\s+([A-Za-z_][A-Za-z0-9_]*)\b')
TOP_PRIVATE_RE = re.compile(r'^\s*private\s+(struct|class|enum|func|var|let)\b')

errors = []

if len(sys.argv) < 2:
    print('Usage: validate_swift_structure.py <dir_or_file>')
    sys.exit(2)

def check_file(path: Path):
    if not path.name.endswith('.swift'):
        return
    text = path.read_text(encoding='utf-8', errors='ignore')

    # Skip obvious generated files
    if 'swiftlint:disable all' in text.lower():
        return

    # Balance check
    stack = []
    for i, ch in enumerate(text):
        if ch in OPEN:
            stack.append(ch)
        elif ch in CLOSE:
            if not stack or stack[-1] != PAIR[ch]:
                errors.append(f"{path}: Unbalanced or mismatched bracket around offset {i}")
                break
            stack.pop()
    if stack:
        errors.append(f"{path}: Unbalanced brackets, open={''.join(stack)}")

    # Duplicate type names (best-effort)
    names = {}
    for m in TYPE_RE.finditer(text):
        tkind, tname = m.group(1), m.group(2)
        names.setdefault(tname, []).append((tkind, m.start()))
    for name, occ in names.items():
        if len(occ) > 1:
            # Allow nested duplicates if clearly namespaced; best-effort: warn if 2+ top-levels
            # Heuristic: if file declares same name multiple times, flag
            errors.append(f"{path}: Duplicate type name detected: {name}")

    # Private declarations at top-level are often a sign struct scope closed too early
    # Heuristic: if many top-level privates, warn
    top_privates = 0
    for line in text.splitlines():
        if TOP_PRIVATE_RE.search(line):
            top_privates += 1
    if top_privates >= 3:
        errors.append(f"{path}: Many top-level private declarations (>=3). Possible premature closing brace in a View.")

def walk(target: Path):
    if target.is_file():
        check_file(target)
    else:
        for p in target.rglob('*.swift'):
            check_file(p)

for arg in sys.argv[1:]:
    walk(Path(arg))

if errors:
    for e in errors:
        print(f"STRUCTURE: {e}")
    pass

print('Structure check completed (warnings may be shown)')
