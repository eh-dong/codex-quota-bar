# CodexQuotaBar

[English README](README.md)

CodexQuotaBar 是一个轻量 macOS 菜单栏工具，用来显示本机 Codex 剩余额度。

菜单栏标题格式：

```text
Codex 96%/W82%
```

- `96%`：Codex 5 小时窗口剩余额度。
- `W82%`：Codex 1 周窗口剩余额度。

DeepSeek API 余额作为可选集成显示在下拉菜单里。

## 依赖

- macOS 13 或更新版本
- Swift 5.10 工具链
- 已安装并登录 Codex CLI

CodexQuotaBar 会按需启动：

```sh
codex app-server --listen stdio://
```

然后通过 JSON-RPC 调用 `account/rateLimits/read`，读取 Codex 本机额度数据。
这个 app-server 协议目前是实验接口，未来 Codex 版本可能会变化。

## 构建

```sh
swift build
```

## 从源码运行

```sh
swift run CodexQuotaBar
```

## 构建 App 包

```sh
scripts/build-app.sh
open dist/CodexQuotaBar.app
```

生成结果位于 `dist/CodexQuotaBar.app`。

## DeepSeek 余额

DeepSeek 是可选功能。CodexQuotaBar 会按顺序读取：

1. `DEEPSEEK_API_KEY`
2. `~/.config/quota-bar/deepseek_api_key`
3. `~/.quota-bar/deepseek_api_key`

用 `open` 启动 GUI App 时，配置文件通常比 shell 环境变量更可靠。

key 文件只放 API key 本身：

```sh
mkdir -p ~/.config/quota-bar
chmod 700 ~/.config/quota-bar
printf '%s' 'YOUR_DEEPSEEK_API_KEY' > ~/.config/quota-bar/deepseek_api_key
chmod 600 ~/.config/quota-bar/deepseek_api_key
```

## 安全说明

- CodexQuotaBar 不读取或展示 Codex auth token。
- CodexQuotaBar 不会把 Codex 数据上传到第三方服务。
- 只有配置了 DeepSeek API key 时，才会请求 DeepSeek 官方余额接口。
- 不要提交本地 API key 文件。

## 未签名 App

第一版定位为技术用户开源工具。构建出的 app bundle 未签名、未公证，macOS
Gatekeeper 可能提示风险。你也可以直接从源码构建运行。

## License

MIT
