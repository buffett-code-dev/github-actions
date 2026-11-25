#!/usr/bin/env bash
set -euo pipefail

agent_path="$(cd "$(dirname "$0")" && pwd)"
agent_venv="$RUNNER_TEMP/claude-agent-sdk-venv"
python3 -m venv "$agent_venv"
"$agent_venv/bin/python" -m pip install --disable-pip-version-check -r "$agent_path/requirements.txt"
exec "$agent_venv/bin/python" "$agent_path/review.py"
