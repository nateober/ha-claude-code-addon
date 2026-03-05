FROM node:20-slim

# Install system tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    openssh-client \
    curl \
    jq \
    tmux \
    zsh \
    bash \
    vim \
    nano \
    less \
    ncurses-bin \
    procps \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install ttyd from GitHub releases (not in Debian repos)
# Map dpkg arch names to ttyd release names (arm64->aarch64, amd64->x86_64)
RUN DPKG_ARCH=$(dpkg --print-architecture) && \
    case "$DPKG_ARCH" in \
      arm64) TTYD_ARCH=aarch64 ;; \
      amd64) TTYD_ARCH=x86_64 ;; \
      *) TTYD_ARCH=$DPKG_ARCH ;; \
    esac && \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.${TTYD_ARCH}" -o /usr/local/bin/ttyd && \
    chmod +x /usr/local/bin/ttyd

# Install Claude Code via native installer
WORKDIR /tmp
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/root/.local/bin:${PATH}"
WORKDIR /

# Install Express for API server
RUN npm install -g express

# Copy API server
ARG API_VERSION=2.5.1
COPY api-server.js /api-server.js

# Install oh-my-zsh for better shell experience
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Copy run script
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Create working directory
WORKDIR /config

# Expose ttyd port (ingress) and API port
EXPOSE 7681
EXPOSE 8080

CMD ["/run.sh"]
