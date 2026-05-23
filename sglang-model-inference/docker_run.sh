#!/usr/bin/env bash
set -euo pipefail

IMAGE="${SGLANG_IMAGE:-test13:latest}"
HOST_PORT="${SGLANG_HOST_PORT:-30000}"
MODEL_PATH="${SGLANG_MODEL_PATH:-/opt/models/qwen2.5-3b-instruct}"
MODEL="${SGLANG_MODEL:-$MODEL_PATH}"
TP="${SGLANG_TP:-1}"
SHM="${SGLANG_SHM_SIZE:-32g}"
MODE="${SGLANG_RUN_MODE:-safe}"
DOCKER_RUNTIME_ARGS="${DOCKER_RUNTIME_ARGS:-}"

COMMON_ARGS=(
  --rm
  --gpus all
  --ipc=host
  --shm-size "$SHM"
  --ulimit memlock=-1
  --ulimit stack=67108864
  -p "${HOST_PORT}:30000"
  -v /opt/models:/opt/models
  -v /var/tmp/hf_cache:/root/.cache/huggingface
  -e SGLANG_HOST=0.0.0.0
  -e SGLANG_PORT=30000
  -e SGLANG_MODEL="$MODEL"
  -e SGLANG_TP="$TP"
)

if [ "$MODE" = "fast" ]; then
  # Fast mode: rely on default optimized backends (good on newer/newer driver+GPU combos).
  LAUNCH_ARGS=(
    python3 -m sglang.launch_server
    --host 0.0.0.0
    --port 30000
    --model-path "$MODEL_PATH"
    --tp "$TP"
  )
else
  # Safe mode: compatible settings for T4/older SMs and known-kernel issues.
  LAUNCH_ARGS=(
    python3 -m sglang.launch_server
    --host 0.0.0.0
    --port 30000
    --model-path "$MODEL_PATH"
    --tp "$TP"
    --disable-piecewise-cuda-graph
    --disable-cuda-graph
    --attention-backend triton
    --sampling-backend pytorch
  )
fi

echo "[docker_run] mode=${MODE}"
echo "[docker_run] image=${IMAGE}"
echo "[docker_run] model=${MODEL_PATH}"

eval "docker run ${DOCKER_RUNTIME_ARGS} ${COMMON_ARGS[*]} $IMAGE ${LAUNCH_ARGS[*]}"
