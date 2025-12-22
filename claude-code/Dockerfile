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

# Copy run script
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Create working directory
WORKDIR /config

# Expose ttyd port (ingress)
EXPOSE 7681

CMD ["/run.sh"]
