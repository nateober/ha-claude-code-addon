# Changelog

## [2.0.3] - 2024-12-21

### Fixed
- **Improved tmux session persistence** - Added wrapper script that properly reattaches to existing sessions
- Added `.tmux.conf` with `remain-on-exit on` to keep sessions alive
- Mouse support enabled in tmux
- Status bar hidden for cleaner interface

## [2.0.2] - 2024-12-21

### Fixed
- **Environment variables now persist in tmux sessions** - Auth tokens and API keys are properly passed to tmux
- Environment written to `/data/.claude_env` and sourced in shell profiles

## [2.0.1] - 2024-12-21

### Fixed
- **Window resize no longer resets the session** - Wrapped Claude in tmux to handle terminal resize events gracefully
- Added `--reconnect 3` to ttyd for automatic reconnection

## [2.0.0] - 2024-12-21

### Added
- **MCP Integration** - Claude Code can now control Home Assistant devices directly
  - Turn lights on/off, adjust brightness
  - Control thermostats and climate devices
  - Activate scenes
  - Query sensor states
  - Media player control
- New configuration options:
  - `enable_ha_mcp` - Enable/disable MCP integration (default: enabled)
  - `ha_mcp_url` - Custom MCP endpoint URL (optional)
- Updated CLAUDE.md with MCP usage instructions
- New branding with icon.png and logo.png

### Changed
- Renamed from "Claude Code Terminal" to "Claude Code for Home Assistant"
- Updated panel icon to `mdi:robot`
- Improved documentation with MCP examples

## [1.0.0] - 2024-12-21

- Initial release
- Web terminal with Claude Code CLI
- Full access to /config directory
- Ingress support for HA sidebar integration
