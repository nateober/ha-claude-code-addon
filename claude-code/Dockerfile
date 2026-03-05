ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install system tools
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
    && npm install -g @anthropic-ai/claude-code@2.1.69

# Install Express for API server
RUN npm install -g express

# Copy API server
ARG API_VERSION=2.4.2
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
