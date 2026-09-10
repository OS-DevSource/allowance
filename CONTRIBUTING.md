# Contributing

Keep Allowance focused on account allowance and a compact macOS experience. Preserve keyboard access, contrast, reduced-motion behavior, and the small dependency footprint. There are no third-party Swift package dependencies.

Start with the [README setup steps](README.md#set-up-allowance). Full Xcode 26+ is needed for XCTest; compatible Command Line Tools can build the app and run the standalone checks.

## Before sending a change

Run from the repository root:

```sh
./check.sh       # deterministic checks; no account or network needed
swift test       # XCTest; requires full Xcode
./build-app.sh   # debug app bundle
./scripts/package-release.sh # universal release ZIP and checksum
```

Then open `Allowance.app` and exercise the affected user flow. For window changes, include launch, close/reopen, compact/expanded layouts, and relevant settings. A passing build alone does not verify those interactions.

GitHub Actions runs the standalone checks, XCTest, app build, and strict signature verification with Xcode 26.3. Report any local check that could not run; do not describe it as passed.

Describe the user-visible problem, resulting behavior, validation, and any remaining limits in your pull request. Include screenshots or UI notes for visual changes.

## Optional live account check

```sh
ALLOWANCE_LIVE_TEST=1 ./check.sh
```

This additionally reads the account signed in through your local Codex CLI. Use it only when needed for integration verification. Default tests use disposable local fake servers; never enable live account tests in CI.

## Rebuild the icon

The original honeycomb icon is generated from the included drawing script:

```sh
swift scripts/make-icon.swift Assets
iconutil -c icns Assets/Allowance.iconset -o Assets/Allowance.icns
```

Only regenerate artwork when intentionally changing it.

## Repository hygiene and reports

Never commit `.build`, app bundles, credentials, local preferences, account logs, or authentication files. Keep unrelated formatting and generated files out of changes.

For bug reports, include macOS and CLI versions, the source commit or release, reproduction steps, and the visible error category. Avoid raw server output. Do not put credentials or exploit-sensitive details in public issues.
