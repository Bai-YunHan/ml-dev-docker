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
        # Extra: sudo for non-root user convenience
        sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Pixi (single binary) for root, then move it into /usr/local/bin so all users can execute it
RUN curl -fsSL https://pixi.sh/install.sh | sh && \
    mv /root/.pixi/bin/pixi /usr/local/bin/pixi && \

# === Create non-root user 'byc' ===
ARG USERNAME=byc
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} -s /bin/bash \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# === Switch to non-root user environment ===
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Create working dirs and fix ownership
RUN mkdir -p /home/${USERNAME}/workspace /home/${USERNAME}/data

# Initialize Git-LFS
RUN git lfs install --skip-smudge

# Install Tmux Plugin Manager
RUN git clone https://github.com/tmux-plugins/tpm /home/${USERNAME}/.tmux/plugins/tpm

# Install Oh My Zsh (non-interactively)
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" " --unattended"

# Install fzf: general-purpose, interactive command-line fuzzy finder
# Prerequisite for zsh's fzf-tab plugin
RUN git clone --depth 1 https://github.com/junegunn/fzf.git /home/${USERNAME}/.fzf && /home/${USERNAME}/.fzf/install

# Clone personal dotfiles and apply zsh/tmux configs via GNU Stow.
# Remove any existing ~/.zshrc created by the Oh My Zsh installer so stow can place its own.
RUN rm -f /home/${USERNAME}/.zshrc && \
    git clone https://github.com/Bai-YunHan/Dotfiles.git /home/${USERNAME}/dotfiles && \
    cd /home/${USERNAME}/dotfiles && \
    stow zsh && \
    stow tmux

# # Optional quality-of-life shell setup for zsh
# RUN { \
#         echo 'export PATH=$PATH:~/.local/bin'; \
#         echo "alias ll='ls -alF'"; \
#         echo "alias la='ls -A'"; \
#         echo "alias l='ls -CF'"; \
#         echo "PROMPT='%F{green}%n@%m:%F{cyan}%~%f$ '"; \
#     } >> ~/.zshrc

# Make subsequent RUN/CMD/ENTRYPOINT use zsh
SHELL ["/bin/zsh", "-c"]

# Default working directory
WORKDIR /home/${USERNAME}/workspace

# Start zsh by default when the container runs
CMD ["zsh"]
