# Verification and compatibility

Allowance targets macOS 13 or later. The table separates tested configurations from the minimum target. The Codex app-server interface is experimental.

## Verified environments

| Environment | Evidence |
| --- | --- |
| Apple Silicon with macOS 27 SDK, Swift 6.4 Command Line Tools, and `codex-cli 0.144.1` | Local build, deterministic suite, and app-flow checks on September 8–10, 2026. |
| GitHub `macos-15` runner with Xcode 26.3 | Standalone checks, XCTest, app build, and strict signature verification passed for the [v0.1.3 merged build](https://github.com/OS-DevSource/allowance/actions/runs/34523990126). |
| Public v0.1.3 universal DMG and ZIP | Both downloads matched their SHA-256 checksums. The mounted DMG contained version 0.1.3 build 5, arm64 and x86_64 slices, the Applications shortcut, the release icon and layout, and a valid ad-hoc signature. |

Reproduce the checks using [Contributing](../CONTRIBUTING.md).

## Coverage

Automated checks cover allowance parsing and legacy fallback, executable selection, protocol initialization, malformed responses, sign-in and network errors, timeouts, refresh concurrency, and recovery while retaining the last successful reading. Window-position checks cover reachable coordinates, negative display coordinates, and title-bar bounds for unavailable displays and oversized windows.

Local app checks covered:

- Successful account refresh, Settings, executable selection, and return to automatic detection.
- Companion launch and reopening, pin on/off, compact and expanded layouts, a stable top edge during disclosure changes, and window-position memory with saved-position relaunches.

## Remaining limits

- Hardware testing does not cover Intel Macs or macOS 13–26. CI verifies its own environment, not every supported runtime.
- Physical monitor disconnection has not been tested. Display fallback has deterministic geometry coverage.
- Network and sign-in failures were simulated; no real credentials were expired or modified.
- Direct menu-bar popover automation was limited; most interaction checks used the companion window and Settings.
- Only the CLI version listed above was live-tested. Future protocol or authentication changes may require app updates.
- Release bundles are ad-hoc signed, not Developer ID signed or notarized. macOS requires the documented one-time **Privacy & Security → Open Anyway** approval for a downloaded build.
