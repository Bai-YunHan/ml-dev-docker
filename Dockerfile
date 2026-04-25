# All setup and runtime runs as root. This is safe under rootless Docker:
# the Docker daemon itself runs as the host user (not system root), so
# container root is unprivileged on the host — it maps to the host user's
# UID. Files created inside appear owned by the host user, and the container
# has no elevated privileges beyond what that user already has on the host.
FROM nvidia/cuda:12.6.3-cudnn-devel-ubuntu22.04

# Avoid interactive apt dialogs
ENV DEBIAN_FRONTEND=noninteractive
# Pixi shell overrides library/terminfo paths, making system terminfo
# invisible to its bundled ncurses. Copying entries into ~/.terminfo
# works because ncurses unconditionally checks ~/.terminfo first.
ENV TERM=xterm

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

# Copy system terminfo into ~/.terminfo and create hex-named symlinks.
# System terminfo uses letter dirs (x/xterm), but pixi's conda-forge ncurses
# expects hex-named dirs (78/xterm). Symlinks let both conventions resolve.
RUN cp -r /usr/lib/terminfo /root/.terminfo && \
    for dir in /root/.terminfo/*/; do \
        letter=$(basename "$dir"); \
        hex=$(printf '%02x' "'$letter"); \
        [ "$letter" != "$hex" ] && [ ! -e "/root/.terminfo/$hex" ] && \
            ln -s "$letter" "/root/.terminfo/$hex"; \
    done

# Create working dirs
RUN mkdir -p /root/workspace /root/data

# Initialize Git-LFS
RUN git lfs install --skip-smudge

# Install Tmux Plugin Manager and pre-install all plugins referenced in .tmux.conf
# (TPM's install_plugins.sh needs a live tmux server, so we clone them directly here)
RUN git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm && \
    git clone --depth 1 https://github.com/christoomey/vim-tmux-navigator.git ~/.tmux/plugins/vim-tmux-navigator && \
    git clone --depth 1 https://github.com/tmux-plugins/tmux-sensible.git     ~/.tmux/plugins/tmux-sensible && \
    git clone --depth 1 https://github.com/tmux-plugins/tmux-resurrect.git    ~/.tmux/plugins/tmux-resurrect && \
    git clone --depth 1 https://github.com/tmux-plugins/tmux-continuum.git    ~/.tmux/plugins/tmux-continuum && \
    git clone --depth 1 https://github.com/dracula/tmux.git                   ~/.tmux/plugins/tmux

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

# Set zsh as root's default login shell so tmux spawns zsh in new panes/windows
RUN chsh -s /bin/zsh

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
