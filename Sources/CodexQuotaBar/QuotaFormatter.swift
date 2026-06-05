import Foundation

enum QuotaFormatter {
    static let unknownTitle = "Codex ?%/W?%"

    static func menuBarTitle(for limit: RateLimitSnapshot?) -> String {
        guard let limit else { return unknownTitle }

        let primary = limit.primary?.remainingDisplay ?? "?"
        let secondary = limit.secondary?.remainingDisplay ?? "?"
        return "Codex \(primary)%/W\(secondary)%"
    }

    static func windowDetail(_ window: RateLimitWindow?, shortWindow: Bool) -> String {
        guard let window else { return "no data" }

        let resetText: String
        if let resetsAt = window.resetsAt {
            let formatter = shortWindow ? DateFormatters.time : DateFormatters.dayTime
            resetText = "\(formatter.string(from: resetsAt)) reset"
        } else {
            resetText = "reset time unknown"
        }

        return "\(window.remainingPercent)% remaining, \(resetText)"
    }
}

enum DateFormatters {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let dayTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d HH:mm"
        return formatter
    }()
}
