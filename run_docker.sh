#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

echo "[1/4] Installing Docker... [Optional]"
# bash "${SCRIPT_DIR}/install_docker.sh"

# Start ssh-agent
echo "[2/4] Starting SSH agent..."
source "${SCRIPT_DIR}/start_ssh_agent.sh"

echo "[3/4] Building Docker image... takes about 4mins"
IMAGE_TAG="${IMAGE_TAG:-ml-dev:latest}"
read -p "Use build cache? (Y/n): " use_cache
if [[ "${use_cache,,}" != "n" ]]; then
    docker build -t "${IMAGE_TAG}" -f "${SCRIPT_DIR}/Dockerfile" "${SCRIPT_DIR}"
else
    docker build --no-cache -t "${IMAGE_TAG}" -f "${SCRIPT_DIR}/Dockerfile" "${SCRIPT_DIR}"
fi

echo "[4/4] Launching Docker dev container..."
bash "${SCRIPT_DIR}/launch_docker_image.sh"