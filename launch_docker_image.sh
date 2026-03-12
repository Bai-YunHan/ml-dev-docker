#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Launch a dev container that matches your Dockerfile:
#   FROM nvidia/cuda:12.6.3-cudnn-devel-ubuntu22.04
#   USER byc (UID/GID=1000), sudo NOPASSWD
# Notes:
# - GPU: requires NVIDIA Container Toolkit on the host.
# - X11/Pulse: for GUI/audio on Linux desktops.
# - Network: host networking is useful for ROS/etc; toggle as needed.
# -------------------------------------------------------------------

# ----- Host paths -----
HOST_PROJECT_DIR="${HOME}/workspace"
HOST_CCACHE_DIR="${HOME}/.ccache"
HOST_DATA="${HOME}/data"

# Ensure host dirs exist
mkdir -p "${HOST_CCACHE_DIR}" "${HOST_DATA}" "${HOST_PROJECT_DIR}"

# ----- Container paths/users -----
CONTAINER_USER="byc"
CONTAINER_HOME="/home/${CONTAINER_USER}"
CONTAINER_PROJECT_DIR="${CONTAINER_HOME}/workspace"
CONTAINER_DATA="${CONTAINER_HOME}/data"

# ----- Image & container name -----
BUILD_BASE_DOCKER_IMAGE="${BUILD_BASE_DOCKER_IMAGE:-ml-dev:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-ml-dev-container}"

# ----- Desktop integration (Linux) -----
DISPLAY_VAL="${DISPLAY:-}"                                # empty if headless/SSH
XAUTH_FILE="${HOME}/.Xauthority"; [ -f "${XAUTH_FILE}" ] || touch "${XAUTH_FILE}"
PULSE_DIR="/run/user/$(id -u)/pulse"

# Optional: allow local docker to access X (only on trusted machines)
# xhost +local:docker >/dev/null 2>&1 || true

# Build docker run as an array (safe quoting)
RUN_CMD=( docker run
  --restart unless-stopped # auto-start on daemon restart/reboot unless manually stopped
  --gpus all # allow use of GPUs
  --ipc=host # allow shared memory access
  --shm-size=2g # set shared memory size
  --network host # allow network access for ROS/MDNS/low-latency comms

  # Name/hostname
  --name "${CONTAINER_NAME}"
  --hostname "${CONTAINER_NAME}"

  # Env variables
  -e CONTAINER_PROJECT_DIR="${CONTAINER_PROJECT_DIR}"
  -e TZ="$(cat /etc/timezone 2>/dev/null || echo UTC)"
  -e DISPLAY="${DISPLAY_VAL}"
  -e XAUTHORITY="${CONTAINER_HOME}/.Xauthority"
  -e PULSE_SERVER="unix:${PULSE_DIR}/native"

  # Mount volumes
  -v "${HOST_PROJECT_DIR}:${CONTAINER_PROJECT_DIR}"
  -v "${HOST_DATA}:${CONTAINER_DATA}"
  -v "${HOST_CCACHE_DIR}:${CONTAINER_HOME}/.ccache"
  -v /tmp/.X11-unix:/tmp/.X11-unix
  -v "${XAUTH_FILE}:${CONTAINER_HOME}/.Xauthority:ro"
  -v "${PULSE_DIR}:${PULSE_DIR}"

  # Set working directory
  -w "${CONTAINER_PROJECT_DIR}"

  -d  # run detached so container persists independent of shells
  # Image & long-running PID 1 to keep container alive (sleep infinity)
  "${BUILD_BASE_DOCKER_IMAGE}" sleep infinity
)

echo "Launching Docker container: ${CONTAINER_NAME}"
# After reboot, Docker will auto-start it (unless you manually stopped it)
if docker ps -a --format '{{.Names}}' | grep -wq "${CONTAINER_NAME}"; then # check if container exists
  if ! docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null | grep -q true; then # check if container is running
    docker start "${CONTAINER_NAME}" >/dev/null # start container
  fi
else
  "${RUN_CMD[@]}" # run container
fi
