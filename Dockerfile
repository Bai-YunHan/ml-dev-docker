# All setup and runtime runs as root. This is safe under rootless Docker:
# the Docker daemon itself runs as the host user (not system root), so
# container root is unprivileged on the host — it maps to the host user's
# UID. Files created inside appear owned by the host user, and the container
# has no elevated privileges beyond what that user already has on the host.
FROM nvidia/cuda:12.6.3-cudnn-devel-ubuntu22.04

# Avoid interactive apt dialogs
ENV DEBIAN_FRONTEND=noninteractive

# === 1–9: ML Research System Dependencies ===
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # 1. Core Build & Utility Tools
        build-essential cmake git git-lfs curl wget unzip pkg-config software-properties-common \
        # 2. Image / Vision Dependencies
        libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 libjpeg-dev libpng-dev libtiff-dev \
        # 3. Multimedia / Video Tools
        ffmpeg \
        # 4. Compression, Archive & I/O Tools
        zip gzip tar bzip2 xz-utils \
        # 5. Networking & SSH Utilities
        net-tools iputils-ping openssh-client \
        # 6. Dev / Debugging Tools
        vim nano htop lsof less tmux \
        # 7. NLP / Crypto libs
        libffi-dev libssl-dev \
        # 8. Shell + dotfile management
        zsh stow \
    && rm -rf /var/lib/apt/lists/*

# Install Pixi (single binary)
RUN curl -fsSL https://pixi.sh/install.sh | sh && \
    mv /root/.pixi/bin/pixi /usr/local/bin/pixi

WORKDIR /root

# Create working dirs
RUN mkdir -p /root/workspace /root/data

# Initialize Git-LFS
RUN git lfs install --skip-smudge

# Install Tmux Plugin Manager
RUN git clone https://github.com/tmux-plugins/tpm /root/.tmux/plugins/tpm

# Install Oh My Zsh (non-interactively)
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" " --unattended"

# Install fzf: general-purpose, interactive command-line fuzzy finder
# Prerequisite for zsh's fzf-tab plugin
RUN git clone --depth 1 https://github.com/junegunn/fzf.git /root/.fzf && /root/.fzf/install

# Clone personal dotfiles and apply zsh/tmux configs via GNU Stow.
# Remove any existing ~/.zshrc created by the Oh My Zsh installer so stow can place its own.
RUN rm -f /root/.zshrc && \
    git clone https://github.com/Bai-YunHan/Dotfiles.git /root/dotfiles && \
    cd /root/dotfiles && \
    stow zsh && \
    stow tmux

# SSH agent socket path (mounted from host at runtime).
# Set via both ENV (for non-shell processes) and .zshenv (for interactive zsh,
# which may not inherit Docker ENV through oh-my-zsh startup chain).
ENV SSH_AUTH_SOCK="/ssh-agent"
RUN echo 'export SSH_AUTH_SOCK="/ssh-agent"' > /root/.zshenv

# Make subsequent RUN/CMD/ENTRYPOINT use zsh
SHELL ["/bin/zsh", "-c"]

# Default working directory
WORKDIR /root/workspace

# Start zsh by default when the container runs
CMD ["zsh"]
