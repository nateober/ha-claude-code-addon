#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -e

# Get configuration
if bashio::config.has_value 'anthropic_api_key'; then
    export ANTHROPIC_API_KEY=$(bashio::config 'anthropic_api_key')
    bashio::log.info "Anthropic API key configured"
else
    bashio::log.warning "No Anthropic API key set - configure in add-on settings"
fi

# Set up environment
export HOME=/root
export CLAUDE_CODE_DISABLE_NONINTERACTIVE_HINT=1

# Create .claude directory for settings
mkdir -p /root/.claude

# Create a CLAUDE.md with HA context
cat > /config/CLAUDE.md << 'EOF'
# Home Assistant Configuration

You are working directly in the Home Assistant /config directory.

## Key Files
- `configuration.yaml` - Main configuration
- `automations.yaml` - Automation definitions
- `scripts.yaml` - Script definitions
- `scenes.yaml` - Scene definitions
- `secrets.yaml` - Sensitive credentials (be careful)

## After Making Changes
Run `ha core check` to validate configuration before restarting.
Run `ha core restart` to apply changes.

## Available Commands
- `ha core check` - Validate configuration
- `ha core restart` - Restart Home Assistant
- `ha core logs` - View HA logs
- `ha addons` - List add-ons
EOF

bashio::log.info "Starting Claude Code terminal on port 7681..."

# Start ttyd with Claude Code
# --writable allows input, --base-path for ingress
exec ttyd \
    --port 7681 \
    --writable \
    --base-path "$(bashio::addon.ingress_entry)" \
    claude
