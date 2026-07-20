# CodexQuotaBar

[English README](README.md)

CodexQuotaBar 是一个轻量 macOS 菜单栏工具，用来显示本机 Codex 剩余额度。

菜单栏标题会根据 Codex 返回的窗口动态使用紧凑标签：

```text
Codex 96%/W82%
Codex W65%
```

- `96%/W82%`：旧版返回中的 5 小时主窗口和 1 周次窗口。
- `W65%`：当前仅返回 1 周窗口、剩余 65% 时的标题。
- 窗口时长会使用 `30m`、`5h`、`1d`、`1w` 等紧凑的整单位；不存在的窗口会被省略。

下拉菜单中的重置详情也使用相同的动态时长标签。如果 Codex 返回重置额度，
菜单会在 Codex/Spark 区域之后显示一次 `Resets available: N`。该数量只读；
CodexQuotaBar 不会消耗重置额度，也不会推断其过期时间。

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
