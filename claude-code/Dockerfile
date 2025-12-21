ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install dependencies
RUN apk add --no-cache \
    nodejs \
    npm \
    git \
    openssh-client \
    curl \
    jq \
    ttyd \
    bash \
    vim \
    nano \
    && npm install -g @anthropic-ai/claude-code

# Create working directory
WORKDIR /config

# Copy run script
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Expose ttyd port (ingress)
EXPOSE 7681

CMD ["/run.sh"]
