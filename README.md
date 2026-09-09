<div align="center">
  <img src="Assets/icon.png" width="120" alt="Allowance icon">
  <h1>Allowance</h1>
  <p>Your remaining Codex allowance, at a glance.</p>
</div>

Allowance is a macOS menu-bar companion that shows your remaining Codex account allowance and reset dates. Keep its window on top, remember its position, and expand additional usage details when you need them.

**Unofficial. Not affiliated with, endorsed by, or supported by OpenAI.**

![Compact Allowance window](docs/compact.png)

<details>
<summary>See the expanded view</summary>

![Expanded Allowance window](docs/expanded.png)

</details>

The app displays only the allowance windows Codex returns for your account. Screenshots are examples from a real account; your available windows and percentages may differ.

## Set up Allowance

**You currently need to build the app from source.** The [release downloads](https://github.com/OS-DevSource/allowance/releases) contain source code, not a ready-to-install or notarized app. The steps below build the latest code on `main`.

### 1. Check your build tools

You need Xcode 26 or newer, or equivalent Apple Command Line Tools, with **Swift 6.2+ and the macOS 26+ SDK**. Check the tools selected on your Mac in Terminal:

```sh
swift --version
xcrun --sdk macosx --show-sdk-version
```

If either command is missing or reports an older version, install a compatible version of [Xcode or Command Line Tools](https://developer.apple.com/xcode/resources/) before continuing. With full Xcode installed, open it once to complete setup and select its tools under **Xcode → Settings → Locations → Command Line Tools**.

The app targets macOS 13+, but that is not a guarantee of compatibility on every older Mac. See [tested environments and limitations](docs/verification.md). Liquid Glass requires macOS 26+; earlier systems use native material.

### 2. Install and sign in to Codex CLI

Follow the official [Codex CLI setup guide](https://developers.openai.com/codex/cli/), then run:

```sh
codex --version
codex login
```

Use the ChatGPT account whose allowance you want to see. Allowance uses the CLI's existing sign-in; there is no separate login inside Allowance. Installing the Codex desktop app alone does not establish that the CLI is available to Allowance.

### 3. Build and open the app

Run these commands in Terminal:

```sh
git clone https://github.com/OS-DevSource/allowance.git
cd allowance
./build-app.sh --release
open Allowance.app
```

The build creates `Allowance.app` inside the repository folder for your Mac's architecture. On launch, a companion window opens and **Allowance** appears in the menu bar. After the first successful refresh, you should see remaining allowance, reset dates, and an update time. If you see a setup error instead, use the troubleshooting section below.

You can keep the app in that folder or quit it and copy `Allowance.app` to Applications using Finder. The build does not install it automatically or enable launch at login. It uses a local ad-hoc signature, not Developer ID signing or notarization.

## Use Allowance

| Control | What it does |
| --- | --- |
| **All usage details** | Expands additional allowance windows, when your account reports them. |
| **Refresh** (circular arrow) | Reads the latest allowance. Automatic refresh runs every five minutes while the app is open. |
| **Keep on top** (pin) | Keeps the companion above ordinary windows. It does not put it above full-screen apps or on every Space. |
| **More options** (ellipsis) | Opens Settings or brings back the companion window. |
| **Quit Allowance** (power) | Stops the app and automatic refresh. Closing the window alone leaves the menu-bar app running. |

Reset dates use your Mac's local time zone. If a refresh fails, the last successful reading stays visible with a warning and its original update time. Missing data is not shown as a zero balance.

### Remember the window position

Open **More options → Settings**. **Remember window position** is on by default: move the companion where you want it, and it will reopen there. Expanding usage details preserves its top edge.

Turn the setting off to use the centered launch position. Turning it back on saves the current location. Positions are saved only on your Mac; if a saved display is unavailable, the app keeps the window's title bar reachable on an available display.

## Troubleshooting

| Problem | What to try |
| --- | --- |
| Build reports an unsupported SDK or Swift tools version | Recheck both commands in step 1. Installing Xcode is not enough if an older Command Line Tools installation is still selected. |
| **Codex CLI was not found** | Run `command -v codex` in Terminal. In **More options → Settings → Choose Codex…**, select that executable. In the file chooser, press **Command–Shift–G** to enter its containing folder, including a hidden folder such as `~/.local/bin`. |
| The selected executable is no longer available | Choose its new location in Settings, or select **Use automatic detection**. Select the executable file, not an app bundle or folder. |
| Codex needs you to sign in again | Run `codex login` in Terminal, complete sign-in, then click Refresh in Allowance. |
| Unable to reach Codex or a request times out | Check your connection and retry Refresh. Requests time out after 25 seconds. |
| Unexpected response or no allowance windows | Check `codex --version` and your sign-in. The app depends on an experimental CLI interface; API-key-only accounts may not expose subscription allowance windows. Include your CLI version when reporting a persistent problem. |
| The companion window is closed | Click **Allowance** in the menu bar, then **More options → Open companion window**. |

Automatic detection checks `~/.local/bin/codex`, `/opt/homebrew/bin/codex`, `/usr/local/bin/codex`, and absolute directories on the app's inherited `PATH`. Finder-launched apps can have a different `PATH` from Terminal, which is why choosing the executable explicitly can help.

For unresolved problems, [open an issue](https://github.com/OS-DevSource/allowance/issues) with your macOS version, CLI version, source commit or release, and visible error message. Do not include authentication files or private logs.

## Update a source build

Quit Allowance first. In your existing repository folder, run:

```sh
git pull --ff-only
./build-app.sh --release
open Allowance.app
```

If you copied the app to Applications, replace that copy with the newly built app after quitting it. Local preferences are retained. If Git reports local changes or cannot fast-forward, resolve that before rebuilding; do not discard changes you want to keep. Allowance has no automatic updater.

## Privacy and allowance use

Allowance requests account limits through the local Codex app server. Refreshing does not start a model turn or request a reset credit. Codex handles authentication and network access; Allowance adds no analytics or advertising services. See [Privacy](PRIVACY.md) for local storage and diagnostic guidance.

## Development

See [Contributing](CONTRIBUTING.md) for build checks and development commands, [verification notes](docs/verification.md) for test coverage, and the [changelog](CHANGELOG.md) for changes.

## License

[MIT](LICENSE) © 2026 John Rodriguez.
