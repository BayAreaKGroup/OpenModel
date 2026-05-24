#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SGLANG_RUN_MODE=fast \
SGLANG_MODEL_PATH=/opt/models/qwen2.5-3b-instruct \
SGLANG_TP=1 \
  "$SCRIPT_DIR"/docker_run.sh
