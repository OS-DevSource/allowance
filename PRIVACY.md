# Privacy

Allowance reads account allowance and token activity through the official Codex CLI already installed on your Mac. It does not directly read authentication files, collect credentials, or implement its own account login.

## Local storage

The app saves these preferences using macOS UserDefaults:

- Whether all usage details are expanded.
- Whether token activity is expanded.
- Whether the companion window is pinned above ordinary windows.
- Whether window-position memory is enabled and the last saved companion position. Turning memory off stops updates and restoration; it does not erase the saved coordinates.
- Your selected CLI executable path, if you choose one.

The latest allowance and token-activity snapshots and their last-update times are held in memory. Allowance does not save usage history, forecasts, account identifiers, reset-credit information, or raw server responses to disk. Error messages shown by the app are categorized rather than copying arbitrary server output.

## Requests

Each refresh uses independent short-lived `codex app-server --stdio` children to initialize the protocol and request `account/rateLimits/read` and `account/usage/read`. The app discards unrelated response fields and terminates/reaps each child after completion or timeout. It never sends prompts, starts inference, consumes reset credits, or sends feedback.

Token activity uses service-reported daily totals and lifetime tokens, not a conversion of allowance percentages. The Sunday–Saturday week and today highlight follow the user's local time zone. Totals remain attached to the service's UTC date labels; the API does not provide timestamps to regroup them into local-day totals. Missing daily totals remain unavailable. Allowance does not read local session transcripts or infer model-level token totals.

Codex itself uses its existing configuration, authentication, networking, and any logging or telemetry behavior configured for that CLI. Those are separate from Allowance. Allowance does not add analytics, crash-upload services, or advertising SDKs.

The setup link opens your browser when you click it. Allowance does not check for updates.

## Sharing diagnostics

Use the CLI version, macOS version, app version, and the visible error category when reporting a problem. Do not share your `auth.json`, tokens, full Codex configuration, or private logs. Screenshots can reveal your plan usage and reset schedule; inspect them before sharing.
