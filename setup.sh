#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
if [[ ! -x .venv/bin/pip ]]; then
    if command -v uv >/dev/null; then uv venv --allow-existing --seed .venv
    else python3 -m venv .venv; fi
fi
.venv/bin/python -m pip install --disable-pip-version-check -r requirements.txt
exec .venv/bin/python scripts/setup.py "$@"
