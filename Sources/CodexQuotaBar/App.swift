import AppKit
import Foundation

private let refreshInterval: TimeInterval = 5 * 60

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let codexClient = CodexRateLimitClient()
    private let deepSeekClient = DeepSeekBalanceClient()
    private var refreshTimer: Timer?
    private var isRefreshing = false
    private var latestSnapshot: RateLimitsSnapshot?
    private var latestCodexError: String?
    private var latestDeepSeekBalance: DeepSeekBalance?
    private var latestDeepSeekError: String?
    private var lastUpdatedAt: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenu()
        updateTitle()
        refresh()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
    }

    private func setupMenu() {
        statusItem.button?.title = QuotaFormatter.unknownTitle
        statusItem.menu = menu
        menu.delegate = self
        rebuildMenu()
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        rebuildMenu()

        Task.detached(priority: .utility) { [codexClient, deepSeekClient] in
            async let codexResult = captureResult { try await codexClient.fetchRateLimits() }
            async let deepSeekResult = captureResult { try await deepSeekClient.fetchBalance() }
            let results = await (codexResult, deepSeekResult)

            await MainActor.run {
                self.apply(codexResult: results.0, deepSeekResult: results.1)
            }
        }
    }

    private func apply(
        codexResult: Result<RateLimitsSnapshot, Error>,
        deepSeekResult: Result<DeepSeekBalance, Error>
    ) {
        switch codexResult {
        case .success(let snapshot):
            latestSnapshot = snapshot
            latestCodexError = nil
        case .failure(let error):
            latestCodexError = error.localizedDescription
        }

        switch deepSeekResult {
        case .success(let balance):
            latestDeepSeekBalance = balance
            latestDeepSeekError = nil
        case .failure(let error):
            latestDeepSeekError = error.localizedDescription
        }

        lastUpdatedAt = Date()
        isRefreshing = false
        updateTitle()
        rebuildMenu()
    }

    private func updateTitle() {
        statusItem.button?.title = QuotaFormatter.menuBarTitle(for: latestSnapshot?.codex)
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        if isRefreshing {
            menu.addItem(disabled: "Refreshing...")
        }

        if let snapshot = latestSnapshot {
            addCodexSection(title: "Codex", limit: snapshot.codex)

            if let spark = snapshot.spark {
                menu.addItem(.separator())
                addCodexSection(title: spark.displayName, limit: spark)
            }

            if let resetCreditsAvailableCount = snapshot.resetCreditsAvailableCount {
                menu.addItem(disabled: "Resets available: \(resetCreditsAvailableCount)")
            }
        } else {
            menu.addItem(disabled: QuotaFormatter.unknownTitle)
        }

        if let latestCodexError {
            menu.addItem(.separator())
            menu.addItem(disabled: "Codex error: \(latestCodexError)")
            menu.addItem(disabled: "Run codex login if needed")
        }

        menu.addItem(.separator())
        addDeepSeekSection()

        if let lastUpdatedAt {
            menu.addItem(.separator())
            menu.addItem(disabled: "Updated: \(DateFormatters.time.string(from: lastUpdatedAt))")
        }

        menu.addItem(.separator())
        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshFromMenu), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.isEnabled = !isRefreshing
        menu.addItem(refreshItem)

        let quitItem = NSMenuItem(title: "Quit CodexQuotaBar", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func addCodexSection(title: String, limit: RateLimitSnapshot?) {
        guard let limit else { return }

        menu.addItem(disabled: title)
        if let primary = limit.primary {
            let label = QuotaFormatter.windowLabel(for: primary, role: .primary)
            menu.addItem(disabled: "\(label) quota: \(QuotaFormatter.windowDetail(primary, role: .primary))")
        }
        if let secondary = limit.secondary {
            let label = QuotaFormatter.windowLabel(for: secondary, role: .secondary)
            menu.addItem(disabled: "\(label) quota: \(QuotaFormatter.windowDetail(secondary, role: .secondary))")
        }

        if let credits = limit.credits {
            menu.addItem(disabled: "Credits: \(credits.balance ?? "0")")
        }
    }

    private func addDeepSeekSection() {
        menu.addItem(disabled: "DeepSeek")

        if let latestDeepSeekBalance {
            menu.addItem(disabled: "Balance: \(latestDeepSeekBalance.totalDisplay)")
            if let granted = latestDeepSeekBalance.grantedDisplay {
                menu.addItem(disabled: "Granted: \(granted)")
            }
            if let toppedUp = latestDeepSeekBalance.toppedUpDisplay {
                menu.addItem(disabled: "Topped up: \(toppedUp)")
            }
            menu.addItem(disabled: latestDeepSeekBalance.isAvailable ? "Status: available" : "Status: unavailable")
        } else if let latestDeepSeekError {
            menu.addItem(disabled: "Not configured" == latestDeepSeekError ? "Not configured" : "Error: \(latestDeepSeekError)")
        } else {
            menu.addItem(disabled: "Not configured")
        }
    }

    @objc private func refreshFromMenu() {
        refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private func captureResult<T>(_ operation: @escaping () async throws -> T) async -> Result<T, Error> {
    do {
        return .success(try await operation())
    } catch {
        return .failure(error)
    }
}

@main
private enum CodexQuotaBarApp {
    private static let delegate = AppDelegate()

    static func main() {
        if CommandLine.arguments.contains("--print") {
            printOnce()
            return
        }

        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }

    private static func printOnce() {
        do {
            let snapshot = try CodexRateLimitClient().fetchRateLimitsSync()
            print(QuotaFormatter.menuBarTitle(for: snapshot.codex))
        } catch {
            print("\(QuotaFormatter.unknownTitle) - \(error.localizedDescription)")
        }
    }
}

private extension NSMenu {
    func addItem(disabled title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        addItem(item)
    }
}
