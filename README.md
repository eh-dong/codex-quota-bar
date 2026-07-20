# CodexQuotaBar

[中文说明](README.zh-CN.md)

CodexQuotaBar is a lightweight macOS menu bar app that shows your local Codex
rate-limit remaining percentages.

The menu bar title derives compact labels from the windows returned by Codex:

```text
Codex 96%/W82%
Codex W65%
```

- `96%/W82%`: the legacy primary 5-hour and secondary 1-week windows.
- `W65%`: a current response with only a weekly window and 65% remaining.
- Window durations use compact exact units such as `30m`, `5h`, `1d`, and `1w`;
  absent windows are omitted.

The dropdown menu uses the same duration labels for reset details. When Codex
reports reset credits, it also shows `Resets available: N` once. This count is
read-only: CodexQuotaBar does not consume credits or infer their expiration.

DeepSeek API balance can also be shown in the dropdown menu as an optional
integration.

## Requirements

- macOS 13 or newer
- Swift 5.10 toolchain
- Codex CLI installed and logged in

CodexQuotaBar reads Codex quota data by launching:

```sh
codex app-server --listen stdio://
```

It then sends a JSON-RPC `account/rateLimits/read` request and renders the
returned rate-limit buckets. This uses Codex's local app-server protocol, which
is currently experimental and may change in future Codex releases.

## Build

```sh
swift build
```

## Run From Source

```sh
swift run CodexQuotaBar
```

## Build The App Bundle

```sh
scripts/build-app.sh
open dist/CodexQuotaBar.app
```

The app bundle is written to `dist/CodexQuotaBar.app`.

## DeepSeek Balance

DeepSeek support is optional. CodexQuotaBar reads the API key from the first
available source:

1. `DEEPSEEK_API_KEY`
2. `~/.config/quota-bar/deepseek_api_key`
3. `~/.quota-bar/deepseek_api_key`

For GUI apps launched with `open`, the config file is usually more reliable than
a shell environment variable.

The key file should contain only the API key:

```sh
mkdir -p ~/.config/quota-bar
chmod 700 ~/.config/quota-bar
printf '%s' 'YOUR_DEEPSEEK_API_KEY' > ~/.config/quota-bar/deepseek_api_key
chmod 600 ~/.config/quota-bar/deepseek_api_key
```

## Security Notes

- CodexQuotaBar does not read or display your Codex auth token.
- CodexQuotaBar does not upload Codex data to a third-party service.
- DeepSeek balance requests are sent only to DeepSeek's official balance API
  when a DeepSeek API key is configured.
- Do not commit local API key files.

## Unsigned App

The first open-source version is intended for technical users. The generated app
bundle is unsigned and not notarized, so macOS Gatekeeper may warn when opening
it. You can build from source if you prefer not to run a prebuilt unsigned app.

## License

MIT
