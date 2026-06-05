import Foundation

struct RateLimitsSnapshot {
    let codex: RateLimitSnapshot?
    let spark: RateLimitSnapshot?
}

struct RateLimitSnapshot {
    let limitId: String?
    let limitName: String?
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?
    let credits: CreditsSnapshot?

    var displayName: String {
        limitName ?? limitId ?? "Codex"
    }
}

struct RateLimitWindow {
    let usedPercent: Int
    let resetsAt: Date?

    var remainingPercent: Int {
        max(0, min(100, 100 - usedPercent))
    }

    var remainingDisplay: String {
        String(remainingPercent)
    }
}

struct CreditsSnapshot {
    let balance: String?
}

struct DeepSeekBalance {
    let isAvailable: Bool
    let currency: String
    let totalBalance: String
    let grantedBalance: String?
    let toppedUpBalance: String?

    var totalDisplay: String {
        format(amount: totalBalance)
    }

    var grantedDisplay: String? {
        grantedBalance.map(format(amount:))
    }

    var toppedUpDisplay: String? {
        toppedUpBalance.map(format(amount:))
    }

    private func format(amount: String) -> String {
        switch currency {
        case "CNY":
            return "¥\(amount)"
        case "USD":
            return "$\(amount)"
        default:
            return "\(amount) \(currency)"
        }
    }
}

enum QuotaBarError: LocalizedError, Equatable {
    case timeout(String)
    case appServer(String)
    case invalidResponse
    case deepSeekNotConfigured

    var errorDescription: String? {
        switch self {
        case .timeout(let message):
            return message
        case .appServer(let message):
            return message
        case .invalidResponse:
            return "Unable to parse service response"
        case .deepSeekNotConfigured:
            return "Not configured"
        }
    }
}
