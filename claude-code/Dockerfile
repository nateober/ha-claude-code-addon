ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install comprehensive toolset
RUN apk add --no-cache \
    nodejs \
    npm \
    git \
    openssh-client \
    curl \
    jq \
    yq \
    ttyd \
    tmux \
    zsh \
    zsh-vcs \
    bash \
    vim \
    nano \
    less \
    ncurses \
    shadow \
    && npm install -g @anthropic-ai/claude-code

# Install oh-my-zsh for better shell experience
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Copy helper scripts
COPY rootfs /

# Set permissions
RUN chmod +x /usr/local/bin/* 2>/dev/null || true \
    && chmod +x /etc/s6-overlay/s6-rc.d/*/run 2>/dev/null || true

# Create working directory
WORKDIR /config

# Expose ttyd port (ingress)
EXPOSE 7681

CMD ["/run.sh"]
