import Foundation

enum QuotaFormatter {
    static let unknownTitle = "Codex"

    enum WindowRole: Equatable {
        case primary
        case secondary
    }

    static func menuBarTitle(for limit: RateLimitSnapshot?) -> String {
        guard let limit else { return unknownTitle }

        let windows = [
            limit.primary.map { titlePart(for: $0, role: .primary) },
            limit.secondary.map { titlePart(for: $0, role: .secondary) }
        ].compactMap { $0 }

        guard !windows.isEmpty else { return unknownTitle }
        return "Codex \(windows.joined(separator: "/"))"
    }

    static func durationLabel(for durationMinutes: Int?) -> String? {
        guard let durationMinutes, durationMinutes > 0 else { return nil }

        let minutesPerHour = 60
        let minutesPerDay = 24 * minutesPerHour
        let minutesPerWeek = 7 * minutesPerDay

        if durationMinutes % minutesPerWeek == 0 {
            return "\(durationMinutes / minutesPerWeek)w"
        }
        if durationMinutes % minutesPerDay == 0 {
            return "\(durationMinutes / minutesPerDay)d"
        }
        if durationMinutes % minutesPerHour == 0 {
            return "\(durationMinutes / minutesPerHour)h"
        }
        return "\(durationMinutes)m"
    }

    static func windowLabel(for window: RateLimitWindow, role: WindowRole) -> String {
        durationLabel(for: window.windowDurationMins)
            ?? (role == .primary ? "5h" : "1w")
    }

    static func windowDetail(_ window: RateLimitWindow?, role: WindowRole) -> String {
        guard let window else { return "no data" }
        return detail(for: window, shortWindow: isShortWindow(window, role: role))
    }

    static func windowDetail(_ window: RateLimitWindow?, shortWindow: Bool) -> String {
        guard let window else { return "no data" }

        return detail(for: window, shortWindow: shortWindow)
    }

    private static func titlePart(for window: RateLimitWindow, role: WindowRole) -> String {
        let label = windowLabel(for: window, role: role)
        let prefix: String
        if label == "1w" {
            prefix = "W"
        } else if label == "5h" && role == .primary {
            prefix = ""
        } else {
            prefix = label
        }
        return "\(prefix)\(window.remainingDisplay)%"
    }

    private static func isShortWindow(_ window: RateLimitWindow, role: WindowRole) -> Bool {
        let durationMinutes = window.windowDurationMins
            ?? (role == .primary ? 5 * 60 : 7 * 24 * 60)
        return durationMinutes <= 24 * 60
    }

    private static func detail(for window: RateLimitWindow, shortWindow: Bool) -> String {

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
