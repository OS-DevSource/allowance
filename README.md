<div align="center">
  <img src="Assets/icon.png" width="120" alt="Allowance icon">
  <h1>Allowance</h1>
  <p>A quiet little window into your Codex capacity.</p>
</div>

Allowance is an independent macOS menu-bar companion that shows your remaining Codex account allowance and reset dates. A compact charcoal interface, soft teal light, and just the details you need.

**Unofficial. Not affiliated with, endorsed by, or supported by OpenAI.**

## A small app, on purpose

- Main account allowance at a glance, with a single capacity header; smoothly expand or collapse the additional windows.
- Remaining percentages and reset dates in your local time zone.
- A pinnable companion window that stays above ordinary windows when enabled.
- One shared refresh loop, every five minutes while the app runs, plus manual refresh and refresh after wake when stale.
- Clear setup, sign-in, network, and stale-data states.
- Native dark material, Liquid Glass on supported systems, keyboard controls, and Reduce Motion / Reduce Transparency support.

![Compact Allowance window](docs/compact.png)

<details>
<summary>See the expanded view</summary>

![Expanded Allowance window](docs/expanded.png)

</details>

Screenshots show a real account at capture time, not a promise of a particular plan or allowance. The app only displays windows returned by Codex.

## Build and run

This first release is **source-first**. There is no notarized download yet.

Requirements:

- A Mac. Deployment target: macOS 13 or later. Liquid Glass requires macOS 26 or later; earlier versions use native material.
- **Xcode 26+ or equivalent Command Line Tools with the macOS 26+ SDK**, including Swift 6.2 or newer. Runtime availability checks do not make newer SDK APIs available to an older compiler.
- The official [Codex CLI](https://developers.openai.com/codex/cli/), installed and signed in using `codex login`.

Clone and build:

```sh
git clone https://github.com/OS-DevSource/allowance.git
cd allowance
./build-app.sh
open Allowance.app
```

The app opens its companion window on the primary display and adds **Allowance** to the menu bar. Closing the companion keeps the menu-bar app running. Use **More options → Open companion window** to bring it back. The pin controls whether the companion floats above other ordinary windows; it does not force the app into every Space or above full-screen apps.

The build produces an app for the current Mac's architecture, with a local ad-hoc signature. It does not install anything into Applications, register a login item, or publish a release. Use `./build-app.sh --release` for an optimized local build.

## Connect your CLI

Allowance searches `~/.local/bin/codex`, `/opt/homebrew/bin/codex`, `/usr/local/bin/codex`, and absolute directories on its inherited `PATH`. Finder-launched apps often have a smaller `PATH` than Terminal.

If detection fails, open **More options → Settings → Choose Codex…** and select your trusted Codex executable. To locate it in Terminal:

```sh
command -v codex
codex --version
```

You can return to automatic detection in Settings. The selected path is saved locally. Allowance never runs your selection through a shell.

If sign-in expires, run `codex login` in Terminal and refresh. API-key-only accounts may not expose subscription allowance windows. Unavailable data is never displayed as a zero balance. If a refresh fails, the last successful reading stays visible with a warning and its original update time.

## Does refreshing spend my allowance?

The app sends initialization messages and the read-only `account/rateLimits/read` request to the local Codex app server. It never starts a model turn or requests a reset credit. It makes no separate OpenAI API call or paid-service integration.

The installed Codex CLI handles its existing authentication and network access. This is an **experimental interface**, verified locally with `codex-cli 0.144.1`; future protocol or authentication changes may require an update.

See [Privacy](PRIVACY.md) for what is stored and what is not.

## Development and verification

No third-party Swift package dependencies.

```sh
./check.sh                     # deterministic checks; no account/network required
ALLOWANCE_LIVE_TEST=1 ./check.sh # additionally read your real account
swift test                     # optional XCTest suite; requires full Xcode
```

The portable checks cover parsing, legacy fallback, CLI selection, initialization, errors, timeouts, duplicate-refresh prevention, and recovery after failure. They create disposable local fake servers; test data is never compiled into the application.

GitHub Actions builds with Xcode 26.3 and runs the portable checks plus XCTest. It never needs credentials or live account access. See [verification notes](docs/verification.md) for the exact local coverage and remaining compatibility gaps.

The app icon is an original seven-circle teal honeycomb on charcoal, matching the header motif. It is included as a multi-resolution `.icns` bundle resource and loaded explicitly for the running app. Reproduce it with:

```sh
swift scripts/make-icon.swift Assets
iconutil -c icns Assets/Allowance.iconset -o Assets/Allowance.icns
```

## Contributing

Keep the app small. See [CONTRIBUTING.md](CONTRIBUTING.md) before sending a change. Never attach authentication files or unredacted account logs to an issue.

## License

[MIT](LICENSE) © 2026 John Rodriguez. Source and original artwork were created independently; no Codex Fuel implementation, artwork, or assets are included.
