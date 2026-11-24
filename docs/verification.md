# Verification and compatibility

Allowance targets macOS 13 or later. The table separates tested configurations from the minimum target. The Codex app-server interface is experimental.

## Verified environments

| Environment | Evidence |
| --- | --- |
| Apple Silicon iMac with macOS 27.3 (26C5047e), macOS 27.2 SDK, Swift 6.4.2 Command Line Tools and `codex-cli 0.170.0` | Public v0.1.4 package verification and PR #14 checks on November 24, 2026. See the results below. |
| Apple Silicon with macOS 27 SDK, Swift 6.4 Command Line Tools, and `codex-cli 0.144.1` | Local build, deterministic suite, and app-flow checks on September 8–10, 2026. |
| GitHub `macos-15` runner with Xcode 26.3 | Standalone checks, XCTest, app build, and strict signature verification passed for the [v0.1.3 merged build](https://github.com/OS-DevSource/allowance/actions/runs/34523990126). |
| Public v0.1.3 universal DMG and ZIP | Both downloads matched their SHA-256 checksums. The mounted DMG contained version 0.1.3 build 5, arm64 and x86_64 slices, the Applications shortcut, the release icon and layout, and a valid ad-hoc signature. |

Reproduce the checks using [Contributing](../CONTRIBUTING.md).

## v0.1.4 release evidence (November 24, 2026)

- The public release tag `v0.1.4` resolves to `e345c56cc28a34e6a1cae5e630b580ad7d23c302`. PR #14 contains the UTC chart correction. The published v0.1.4 app predates that correction.
- [v0.1.4 PR CI](https://github.com/OS-DevSource/allowance/actions/runs/45233576673) and [merged-commit CI](https://github.com/OS-DevSource/allowance/actions/runs/45234761484) succeeded. These checks build a native debug app, not the published universal packages.
- Source metadata declares version 0.1.4, build 6, bundle ID `local.john.allowance`, minimum macOS 13.0.
- GitHub's [release metadata](https://api.github.com/repos/OS-DevSource/allowance/releases/tags/v0.1.4) records the following uploaded assets and SHA-256 digests:

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| Allowance-macOS-universal.dmg | 1662522 | `14c2bad61a1ef0ba2683260bd2df44394007cb0bc9b0daf5c0c79abe861f2424` |
| Allowance-macOS-universal.zip | 1094405 | `93c2e354bd4843392679877535082ff456fd16db0cb13cafc52d307eb498cf0d` |

`bash scripts/verify-public-release.sh` passed on the iMac. Both downloaded files matched the SHA-256 digests above and their downloaded checksum sidecars. The DMG passed its integrity check and mounted read-only with the Applications shortcut. The ZIP passed its integrity check and extracted successfully. Both apps had matching bundle contents and metadata, arm64 and x86_64 slices and valid strict code signatures.

In a temporary directory on the same iMac, the v0.1.4 ZIP launched from a fresh copy and loaded account data through the installed CLI. The v0.1.3 ZIP also launched, then the v0.1.4 DMG copy replaced it at the same path and loaded the account and daily chart. This exercised the bundle replacement and relaunch while preserving the installed copy in `/Applications`. The command-line downloads did not exercise the quarantined Finder first-launch flow. An explicit Gatekeeper assessment rejected the ad-hoc-signed app. Gatekeeper remained enabled.

## PR #14 UTC chart verification (November 24, 2026)

- `./check.sh` passed all 51 deterministic checks. Results were identical with `TZ=America/Chicago` and `TZ=Asia/Tokyo`. The suite exercises the production calendar at 00:00 UTC, at Central midnight, across a local daylight-saving transition and at the Sunday rollover. It also verifies UTC weekday and detail text, exact token counts and the distinction between explicit zero and unavailable data.
- The live checks passed with the installed `codex-cli 0.170.0`. Both allowance and daily token history were returned through the app's CLI client. The companion window showed the seven UTC dates in Sunday–Saturday order and highlighted the current UTC weekday even though its total was unavailable. The displayed accessibility dates and totals matched the CLI response.
- `./scripts/package-release.sh` built the local universal release and generated the DMG, ZIP and checksum sidecars. Both checksums matched. The extracted ZIP passed strict signature verification for both architectures and launched on the iMac. Swift printed a deprecation warning for x86_64 with the installed SDK. Both Mach-O slices declare macOS 13.0 as their minimum. The same app also loaded the UTC chart under Rosetta on the iMac. The running process reported `X86-64 (translated)`.
- Local `swift test` could not import `XCTest`. This iMac has Swift Command Line Tools, and the repository's XCTest suite requires full Xcode. The [PR run for `b76c4f7`](https://github.com/OS-DevSource/allowance/actions/runs/45402555900) passed on Xcode 26.3. XCTest reported 16 cases, with 14 passes, two opt-in live cases skipped and zero failures. The follow-up [PR run for `c0f9672`](https://github.com/OS-DevSource/allowance/actions/runs/45402981642) also passed.
- A standalone SwiftUI harness rendered the production chart with fixture times of 23:59:59 and 00:00:00 UTC. The highlight moved from Tuesday to Wednesday, Tuesday retained its 45 tokens and Wednesday showed a reported zero. Pressing Tab in the harness changed the detail row to match the focused UTC day. A simulated inspection also rendered the zero total as `Wed, Nov 25 UTC · 0 tokens`.

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
- Live CLI results apply to the versions in the verified environments table. Future protocol or authentication changes may require app updates.
- The production formatter and rendered detail row passed. Direct pointer hover still needs a pointer-move check in the packaged app. A live midnight transition was not observed. The SwiftUI schedule and the chart were checked with deterministic midnight inputs.
- Release bundles are ad-hoc signed, not Developer ID signed or notarized. macOS requires the documented one-time **Privacy & Security → Open Anyway** approval for a downloaded build.
