# Privacy

Allowance reads account allowance through the official Codex CLI already installed on your Mac. It does not directly read authentication files, collect credentials, or implement its own account login.

## Local storage

The app saves these preferences using macOS UserDefaults:

- Whether all usage details are expanded.
- Whether the companion window is pinned above ordinary windows.
- Your selected CLI executable path, if you choose one.

The latest usage snapshot and last-update time are held in memory. Allowance does not save usage history, forecasts, account identifiers, reset-credit information, or raw server responses to disk. Error messages shown by the app are categorized rather than copying arbitrary server output.

## Requests

Each refresh starts a short-lived `codex app-server --stdio` child, initializes the protocol, and requests `account/rateLimits/read`. The app discards unrelated response fields and terminates/reaps the child after completion or timeout. It never sends prompts, starts inference, consumes reset credits, or sends feedback.

Codex itself uses its existing configuration, authentication, networking, and any logging or telemetry behavior configured for that CLI. Those are separate from Allowance. Allowance does not add analytics, crash-upload services, or advertising SDKs.

The setup documentation link opens your browser only when clicked. No repository telemetry or update checks are performed.

## Sharing diagnostics

Use the CLI version, macOS version, app version, and the visible error category when reporting a problem. Do not share your `auth.json`, tokens, full Codex configuration, or private logs. Screenshots can reveal your plan usage and reset schedule; inspect them before sharing.
