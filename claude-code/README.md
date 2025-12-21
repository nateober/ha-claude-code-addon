# Claude Code Terminal for Home Assistant

Access Claude Code directly from your Home Assistant interface with full control over your configuration files.

## Features

- Web-based terminal running Claude Code CLI
- Full read/write access to `/config` directory
- Edit automations, scripts, scenes, and more with AI assistance
- Integrated in HA sidebar via ingress
- Works with HA Core commands (`ha core check`, `ha core restart`)

## Installation

1. Copy this add-on to your HA `/addons` directory
2. Go to Settings → Add-ons → Add-on Store
3. Click the menu (⋮) → Check for updates
4. Find "Claude Code Terminal" in Local add-ons
5. Click Install

## Configuration

| Option | Description |
|--------|-------------|
| `anthropic_api_key` | Your Anthropic API key (get from console.anthropic.com) |

## Usage

1. Open the add-on from the sidebar (Claude Code icon)
2. Claude Code will start in the `/config` directory
3. Ask Claude to help with automations, scripts, scenes, etc.

## Example Commands

- "Show me all automations that control the living room lights"
- "Create a new automation that turns off all lights at midnight"
- "Fix the syntax error in my configuration.yaml"
- "Add a new scene called 'Movie Night' that dims the living room to 20%"
