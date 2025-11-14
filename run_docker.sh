#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# echo "[1/3] Installing Docker..."
bash "${SCRIPT_DIR}/install_docker.sh"

# echo "[2/3] Building Docker image... takes about 4mins"
IMAGE_TAG="${IMAGE_TAG:-ml-dev:latest}"
sudo docker build -t "${IMAGE_TAG}" -f "${SCRIPT_DIR}/Dockerfile" "${SCRIPT_DIR}"

echo "[3/3] Launching Docker dev container..."
sudo bash "${SCRIPT_DIR}/launch_docker_image.sh"