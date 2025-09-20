#!/usr/bin/env python3
import subprocess, sys, os
from pathlib import Path

# Fast changed-files checker: run structure validator only on changed Swift files
repo = Path(__file__).resolve().parents[1]

try:
    out = subprocess.check_output(['git', 'diff', '--name-only', '--cached'], cwd=repo, text=True)
except Exception:
    out = ''

paths = [repo / p for p in out.splitlines() if p.endswith('.swift')]
if not paths:
    print('No staged Swift changes; skipping fast check')
    sys.exit(0)

errors = 0
for p in paths:
    print(f'Fast-validate: {p}')
    code = subprocess.call(['python3', str(repo / 'scripts' / 'validate_swift_structure.py'), str(p)])
    if code != 0:
        errors += 1

if errors:
    print(f'Fast changed-files check found {errors} issues')
    sys.exit(1)
print('Fast changed-files check OK')
