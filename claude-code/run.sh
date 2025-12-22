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

# Use /data for persistent storage (survives container restarts)
# This stores Claude Code auth tokens and settings
mkdir -p /data/.claude
rm -rf /root/.claude
ln -sf /data/.claude /root/.claude

bashio::log.info "Claude Code config stored persistently in /data/.claude"

# Configure Home Assistant MCP integration
ENABLE_HA_MCP=$(bashio::config 'enable_ha_mcp' 'true')
HA_MCP_URL=$(bashio::config 'ha_mcp_url' '')

if [ "$ENABLE_HA_MCP" = "true" ]; then
    bashio::log.info "Configuring Home Assistant MCP integration..."

    # Determine MCP URL - use custom URL or default to Supervisor proxy
    if [ -n "$HA_MCP_URL" ]; then
        MCP_ENDPOINT="$HA_MCP_URL"
        bashio::log.info "Using custom MCP URL: $MCP_ENDPOINT"
    else
        MCP_ENDPOINT="http://supervisor/core/api/mcp"
        bashio::log.info "Using Supervisor proxy for MCP: $MCP_ENDPOINT"
    fi

    # Create .mcp.json with Home Assistant MCP configuration
    # Uses the Supervisor token for authentication (automatically available in addons)
    cat > /config/.mcp.json << EOF
{
  "mcpServers": {
    "homeassistant": {
      "type": "http",
      "url": "${MCP_ENDPOINT}",
      "headers": {
        "Authorization": "Bearer ${SUPERVISOR_TOKEN}"
      }
    }
  }
}
EOF

    bashio::log.info "Home Assistant MCP configured - Claude can now control your smart home!"
else
    bashio::log.info "Home Assistant MCP integration disabled"
    # Remove any existing MCP config
    rm -f /config/.mcp.json
fi

# Create a CLAUDE.md with HA context
cat > /config/CLAUDE.md << 'EOF'
# Home Assistant Configuration

You are working directly in the Home Assistant /config directory with MCP access to control devices.

## MCP Integration
This Claude Code instance has MCP (Model Context Protocol) access to Home Assistant. You can:
- Control lights, switches, and other devices
- Check sensor states and device status
- Activate scenes and run automations
- Query the current state of the home

Use the MCP tools (mcp__homeassistant__*) to interact with Home Assistant directly.

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

# Write environment to a file that persists for the session
# This ensures tmux sessions have access to all required variables
cat > /data/.claude_env << EOF
export HOME=/root
export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
export CLAUDE_CODE_DISABLE_NONINTERACTIVE_HINT=1
export SUPERVISOR_TOKEN="${SUPERVISOR_TOKEN:-}"
export TERM=xterm-256color
EOF

# Source the env file in shell profiles so tmux sessions get it
cat > /root/.bashrc << 'BASHRC'
source /data/.claude_env 2>/dev/null || true
BASHRC

cat > /root/.zshrc << 'ZSHRC'
source /data/.claude_env 2>/dev/null || true
ZSHRC

# Configure tmux for better terminal handling
cat > /root/.tmux.conf << 'TMUXCONF'
set -g mouse on
set -g history-limit 50000
set -g default-terminal "xterm-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
set -s escape-time 0
set -g status off
# Keep the session alive even if the window command exits
set -g remain-on-exit on
TMUXCONF

# Create a wrapper script that ttyd will call
# This script attaches to existing session or creates new one
cat > /usr/local/bin/claude-terminal << 'WRAPPER'
#!/bin/bash
source /data/.claude_env 2>/dev/null || true

# Check if tmux session exists
if tmux has-session -t claude 2>/dev/null; then
    # Attach to existing session
    exec tmux attach-session -t claude
else
    # Create new session with claude
    exec tmux new-session -s claude -c /config "source /data/.claude_env && claude"
fi
WRAPPER
chmod +x /usr/local/bin/claude-terminal

# Kill any existing tmux sessions on fresh start
tmux kill-server 2>/dev/null || true

# Start ttyd with the wrapper script
# --writable allows input
# --reconnect 3 auto-reconnects after 3 seconds if disconnected
exec ttyd \
    --port 7681 \
    --writable \
    --reconnect 3 \
    /usr/local/bin/claude-terminal
