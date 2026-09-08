# Contributing

Allowance focuses on account allowance, clear reset dates, and a compact macOS experience. Keep changes focused and preserve keyboard access, contrast, reduced-motion behavior, and the small dependency footprint.

1. Use Xcode 26+ or equivalent macOS 26+ Command Line Tools.
2. Run `./check.sh` and `./build-app.sh`.
3. Exercise the affected user flow in the app bundle. A build does not verify window behavior.
4. Describe the problem, final behavior, and checks in your pull request.

Tests must use local fixtures by default. Live account tests are opt-in and must never run in CI. Never commit `.build`, app bundles, credentials, local preferences, account logs, or authentication files.

Please file reproducible reports with macOS/CLI versions and visible error categories. Avoid raw server output. For suspected security issues, keep credentials and exploit-sensitive details out of public issues.
