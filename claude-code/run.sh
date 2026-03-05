#!/bin/bash
# shellcheck shell=bash
set -e

# Helper: read addon config from /data/options.json using jq
config_value() {
    local key="$1"
    local default="$2"
    local val
    val=$(jq -r ".${key} // empty" /data/options.json 2>/dev/null)
    echo "${val:-$default}"
}

config_has_value() {
    local key="$1"
    local val
    val=$(jq -r ".${key} // empty" /data/options.json 2>/dev/null)
    [ -n "$val" ]
}

# Get configuration
if config_has_value 'anthropic_api_key'; then
    export ANTHROPIC_API_KEY=$(config_value 'anthropic_api_key')
    echo "[INFO] Anthropic API key configured"
else
    echo "[WARN] No Anthropic API key set - configure in add-on settings"
fi

# Set up environment
export HOME=/root
export CLAUDE_CODE_DISABLE_NONINTERACTIVE_HINT=1

# Use /data for persistent storage (survives container restarts)
# This stores Claude Code auth tokens and settings
mkdir -p /data/.claude
rm -rf /root/.claude
ln -sf /data/.claude /root/.claude

echo "[INFO] Claude Code config stored persistently in /data/.claude"

# Restore .claude.json from backup if missing
if [ ! -f /root/.claude.json ] && [ -d /root/.claude/backups ]; then
    BACKUP=$(ls -t /root/.claude/backups/.claude.json.backup.* 2>/dev/null | head -1)
    if [ -n "$BACKUP" ]; then
        cp "$BACKUP" /root/.claude.json
        echo "[INFO] Restored .claude.json from backup: $BACKUP"
    fi
fi

# Configure Home Assistant MCP integration
ENABLE_HA_MCP=$(config_value 'enable_ha_mcp' 'true')
HA_MCP_URL=$(config_value 'ha_mcp_url' '')

if [ "$ENABLE_HA_MCP" = "true" ]; then
    echo "[INFO] Configuring Home Assistant MCP integration..."

    # Determine MCP URL - use custom URL or default to Supervisor proxy
    if [ -n "$HA_MCP_URL" ]; then
        MCP_ENDPOINT="$HA_MCP_URL"
        echo "[INFO] Using custom MCP URL: $MCP_ENDPOINT"
    else
        MCP_ENDPOINT="http://supervisor/core/api/mcp"
        echo "[INFO] Using Supervisor proxy for MCP: $MCP_ENDPOINT"
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

    echo "[INFO] Home Assistant MCP configured - Claude can now control your smart home!"
else
    echo "[INFO] Home Assistant MCP integration disabled"
    # Remove any existing MCP config
    rm -f /config/.mcp.json
fi

# Create a CLAUDE.md with HA context (only if one doesn't already exist)
if [ ! -f /config/CLAUDE.md ]; then
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
else
    echo "[INFO] Existing CLAUDE.md found, preserving it"
fi

# Start API server if enabled
ENABLE_API=$(config_value 'enable_api' 'true')
API_PORT=$(config_value 'api_port' '8080')
DEFAULT_MODEL=$(config_value 'default_model' 'sonnet')

if [ "$ENABLE_API" = "true" ]; then
    echo "[INFO] Starting Claude Code API server on port ${API_PORT}..."
    API_PORT="${API_PORT}" \
    DEFAULT_MODEL="${DEFAULT_MODEL}" \
    SUPERVISOR_TOKEN="${SUPERVISOR_TOKEN:-}" \
    ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
    HOME=/root \
    NODE_PATH="$(npm root -g)" \
    node /api-server.js &
    echo "[INFO] API server started — POST to /api/prompt to send prompts"
else
    echo "[INFO] Claude Code API server disabled"
fi

echo "[INFO] Starting Claude Code terminal on port 7681..."

# Write environment to a file that persists for the session
cat > /data/.claude_env << EOF
export HOME=/root
export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
export CLAUDE_CODE_DISABLE_NONINTERACTIVE_HINT=1
export SUPERVISOR_TOKEN="${SUPERVISOR_TOKEN:-}"
export TERM=xterm-256color
EOF

# Source the env file in shell profiles
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
set -g remain-on-exit on
TMUXCONF

# Create wrapper script that ttyd will call
mkdir -p /usr/local/bin
cat > /usr/local/bin/claude-terminal << 'WRAPPER'
#!/bin/bash
source /data/.claude_env 2>/dev/null || true
cd /config

# Restart loop — claude restarts after Ctrl-C
while true; do
    claude
    echo 'Claude exited. Restarting in 2s... (Ctrl-C again to get a shell)'
    sleep 2
done
WRAPPER
chmod +x /usr/local/bin/claude-terminal

# Kill any existing tmux sessions on fresh start
tmux kill-server 2>/dev/null || true

# Start ttyd with the wrapper script
exec ttyd \
    --port 7681 \
    --writable \
    /usr/local/bin/claude-terminal
