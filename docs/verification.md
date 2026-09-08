# v0.1 local verification

Verified on September 8, 2026 with Apple Silicon, macOS 27 SDK / Swift 6.4 Command Line Tools, and `codex-cli 0.144.1`.

## Passed

- Native SwiftPM build and ad-hoc app-bundle signature verification.
- 19 deterministic portable checks, plus one explicit live account read (20 total).
- Protocol handshake and notification handling against disposable local servers.
- Expired sign-in, offline server response, malformed JSON, unexpected schema, and a bounded timeout.
- CLI-path validation, explicit selection, and rejecting directories or missing executables.
- Shared-model startup, concurrent refresh prevention, fresh-panel reuse, preserving the last reading on failure, and successful recovery.
- Normal app-bundle launch without a preview flag; companion reopen handling was exercised.
- Compact and expanded window layouts, real account percentages and reset dates.
- Native-window frame sampling confirmed intermediate resize frames in both directions, between 206 and 410 points. Both directions use the same 0.32-second timing; the main layout stays anchored.
- Options menu, Settings, native executable chooser, successful selected-executable refresh, and restoration of automatic detection.
- Pin on/off verified against the macOS window-server levels (floating 3, normal 0) during development.
- The honeycomb icon was generated from the included vector-drawing script, visually inspected, and verified through macOS icon lookup after app registration.
- Redundant headings were removed; compact and expanded screenshots were refreshed.

## Limits of this verification

- Intel Macs and macOS 13–26 have not been tested on hardware. The deployment target and material fallback do not establish compatibility by themselves.
- XCTest is unavailable in this local Command Line Tools installation. The equivalent portable runner works; full-Xcode XCTest remains an additional check.
- Hosted results are published in the repository’s Actions tab; the workflow selects Xcode 26.3 explicitly.
- Network failures were simulated without disconnecting the user's Mac or expiring a real account session. No tokens or authentication files were modified.
- Direct automation of the menu-bar popover is limited by the local UI tool. The companion, options, and Settings flows were inspected as native windows.
- The app uses an experimental Codex CLI protocol; only the installed version above was live-tested.
- This workspace’s file-provider service can add Finder metadata after signing. Strict verification passed after removing that metadata from the generated bundle; a fresh local source build is the supported distribution path.
- The bundle is locally ad-hoc signed, not Developer ID signed or notarized. The initial distribution is source-first.

The README screenshots show real usage at capture time. No mock account data is included in the app target.
