# AIOS — AI-First Operating System

A minimal Linux distribution where the only interface is an AI chat and a web browser. Built on Debian Trixie with a Rust-native UI stack.

## Architecture

```
┌─────────────────────────────────────────────┐
│                   sway (Wayland)            │
│  ┌───────────┐  ┌──────────┐  ┌──────────┐ │
│  │ aios-chat │  │ aios-dock│  │ Chromium │  │
│  │  (Iced)   │  │  (Iced)  │  │ Browser  │  │
│  └─────┬─────┘  └────┬─────┘  └──────────┘ │
│        │              │                      │
│        └──────┬───────┘                      │
│               │ Unix IPC                     │
│        ┌──────┴──────┐                       │
│        │ aios-agent  │ ← LLM Providers      │
│        │  (daemon)   │   (Claude/OpenAI/     │
│        │             │    Ollama)             │
│        └──────┬──────┘                       │
│               │                              │
│        ┌──────┴──────┐                       │
│        │  aios-mcp   │ ← 19 Tools           │
│        │  (tools)    │   (files, shell,      │
│        │             │    browser, etc.)      │
│        └──────┬──────┘                       │
│               │                              │
│        ┌──────┴──────┐                       │
│        │aios-confirm │ ← Approval Dialog     │
│        │  (Iced)     │   for destructive     │
│        │             │   actions              │
│        └─────────────┘                       │
└─────────────────────────────────────────────┘
```

**Star topology**: all processes communicate exclusively through `aios-agent` via Unix domain sockets with length-prefixed JSON protocol.

## Components

| Crate | Description |
|-------|-------------|
| `aios-common` | Shared types, IPC protocol, configuration |
| `aios-agent` | Central daemon — agentic loop, LLM providers, rate limiter, audit log |
| `aios-chat` | Chat UI (Iced 0.14) — markdown rendering, tool cards, OOBE wizard |
| `aios-dock` | Task bar (Iced) — Chat and Browser launch buttons |
| `aios-confirm` | Confirmation dialog for destructive tool actions |
| `aios-mcp` | MCP tool registry — 19 tools (files, shell, processes, browser) |
| `aios-memory` | *(scaffold)* Persistent memory for conversations |
| `aios-voice` | *(scaffold)* Voice input/output |

## Security Model

- **Trust levels**: `None` (auto-execute), `Confirm` (user approval), `DoubleConfirm` (explicit + reason)
- **Separate confirmation process**: `aios-confirm` runs as an independent process — the agent cannot approve its own actions
- **Rate limiting**: Sliding-window limiter for destructive operations (configurable per-minute cap)
- **Audit logging**: All tool executions logged with timestamps, parameters, and results

## Quick Start

### Prerequisites

- Docker (for cross-compilation and ISO build)
- Rust 1.85+ (for local development)
- QEMU (optional, for testing)

### Build the ISO

```bash
# Full pipeline: compile → stage binaries → build ISO
make all

# Or step by step:
make build-linux        # Cross-compile for Linux x86_64
make install-binaries   # Copy binaries to ISO tree
make build-iso          # Build Debian Live ISO
```

### Test in QEMU

```bash
make run-qemu
# Login: aios / aios
```

### Local Development

```bash
cargo build --workspace
cargo test --workspace
cargo clippy --workspace
```

## ISO Contents

- **Base**: Debian 13 (Trixie), kernel 6.16+
- **Window Manager**: sway (Wayland)
- **Login**: greetd (auto-login as `aios`)
- **Browser**: Chromium (managed policy, Wayland-native)
- **Audio**: PipeWire + WirePlumber
- **Networking**: NetworkManager + wpa_supplicant

## LLM Providers

Configured during first boot (OOBE wizard) or in `~/.config/aios/agent.toml`:

| Provider | Model | Requires |
|----------|-------|----------|
| Claude (Anthropic) | claude-sonnet-4-20250514 | API key |
| OpenAI | gpt-4o | API key |
| Ollama | llama3 | Local server at localhost:11434 |

## Project Structure

```
aios/
├── crates/
│   ├── aios-common/     # Shared types & IPC
│   ├── aios-agent/      # Central daemon
│   ├── aios-chat/       # Chat UI
│   ├── aios-dock/       # Task bar
│   ├── aios-confirm/    # Confirmation dialog
│   ├── aios-mcp/        # Tool framework
│   ├── aios-memory/     # (scaffold)
│   └── aios-voice/      # (scaffold)
├── iso/
│   ├── config/          # live-build configuration
│   ├── Dockerfile       # ISO builder container
│   ├── Dockerfile.build # Rust cross-compile container
│   └── build-iso.sh     # Build orchestrator
├── Cargo.toml           # Workspace root
├── Makefile             # Build pipeline
└── output/              # Built ISO (gitignored)
```

## License

MIT
