# Verification and compatibility

The deployment target is macOS 13+, but compatibility claims should be based on tested environments, not the target alone. The Codex app-server interface is experimental.

## Verified environments

| Environment | Evidence |
| --- | --- |
| Apple Silicon with macOS 27 SDK / Swift 6.4 Command Line Tools and `codex-cli 0.144.1` | Local build and runtime checks on September 8–9, 2026. |
| GitHub `macos-15` runner with Xcode 26.3 | Standalone checks, XCTest, app build, and signature verification passed for [window-position PR #1](https://github.com/OS-DevSource/allowance/pull/1). |
| Universal release build with macOS 27 SDK / Swift 6.4 Command Line Tools | The v0.1.2 package was compiled with arm64 and x86_64 slices, ad-hoc signed, archived, extracted, and revalidated locally. |
| DMG release build with macOS 27 tools | The v0.1.3 image was verified, mounted read-only, and checked for its app, Applications shortcut, icon, version, arm64 and x86_64 slices, and valid ad-hoc signature. |

See [GitHub Actions](https://github.com/OS-DevSource/allowance/actions) for results on a specific commit. Reproduce the checks using [Contributing](../CONTRIBUTING.md).

## Coverage

Automated checks cover allowance parsing and legacy fallback, executable selection, protocol initialization, malformed responses, sign-in and network errors, timeouts, refresh concurrency, and recovery while retaining the last successful reading. Window-position checks cover reachable coordinates, negative display coordinates, and title-bar bounds for unavailable displays and oversized windows.

Local app checks covered:

- Successful account refresh, Settings, executable selection, and return to automatic detection.
- Companion launch and reopening, pin on/off, and compact/expanded layouts.
- Window-position memory enabled and disabled, saved-position relaunches, and a stable top edge during disclosure changes.
- App-bundle build and local signature verification.

## Remaining limits

- Intel Macs and macOS 13–26 have not been tested locally on hardware. CI verifies its own environment, not every supported runtime.
- Physical monitor disconnection has not been tested. Display fallback has deterministic geometry coverage.
- Network and sign-in failures were simulated; no real credentials were expired or modified.
- Direct menu-bar popover automation was limited; most interaction checks used the companion window and Settings.
- Only the CLI version listed above was live-tested. Future protocol or authentication changes may require app updates.
- The local Command Line Tools installation lacks XCTest; full-Xcode XCTest passed in CI.
- Release bundles are ad-hoc signed, not Developer ID signed or notarized. macOS requires the documented one-time **Privacy & Security → Open Anyway** approval for a downloaded build. File-provider folders can add Finder metadata after signing; the build script clears bundle metadata before signing.

README screenshots show real usage at capture time. No mock account data is included in the app target.
