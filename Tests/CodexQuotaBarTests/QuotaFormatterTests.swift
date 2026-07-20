import XCTest
@testable import CodexQuotaBar

final class QuotaFormatterTests: XCTestCase {
    func testMenuBarTitleUsesRemainingPercentages() {
        let limit = RateLimitSnapshot(
            limitId: "codex",
            limitName: nil,
            primary: RateLimitWindow(usedPercent: 4, resetsAt: nil),
            secondary: RateLimitWindow(usedPercent: 18, resetsAt: nil),
            credits: nil
        )

        XCTAssertEqual(QuotaFormatter.menuBarTitle(for: limit), "Codex 96%/W82%")
    }

    func testRemainingPercentIsClamped() {
        XCTAssertEqual(RateLimitWindow(usedPercent: -10, resetsAt: nil).remainingPercent, 100)
        XCTAssertEqual(RateLimitWindow(usedPercent: 150, resetsAt: nil).remainingPercent, 0)
    }

    func testWeeklyOnlyWindowUsesDurationInTitle() {
        let limit = RateLimitSnapshot(
            limitId: "codex",
            limitName: nil,
            primary: RateLimitWindow(usedPercent: 35, resetsAt: nil, windowDurationMins: 10080),
            secondary: nil,
            credits: nil
        )

        XCTAssertEqual(QuotaFormatter.menuBarTitle(for: limit), "Codex W65%")
    }

    func testMissingWindowsAreNotUnknownTitleParts() {
        let limit = RateLimitSnapshot(
            limitId: "codex",
            limitName: nil,
            primary: nil,
            secondary: RateLimitWindow(usedPercent: 18, resetsAt: nil),
            credits: nil
        )

        XCTAssertEqual(QuotaFormatter.menuBarTitle(for: limit), "Codex W82%")
        XCTAssertEqual(QuotaFormatter.menuBarTitle(for: nil), "Codex")
    }

    func testDurationLabelsUseCompactExactUnits() {
        XCTAssertEqual(QuotaFormatter.durationLabel(for: 30), "30m")
        XCTAssertEqual(QuotaFormatter.durationLabel(for: 60), "1h")
        XCTAssertEqual(QuotaFormatter.durationLabel(for: 300), "5h")
        XCTAssertEqual(QuotaFormatter.durationLabel(for: 1440), "1d")
        XCTAssertEqual(QuotaFormatter.durationLabel(for: 10080), "1w")
        XCTAssertEqual(QuotaFormatter.durationLabel(for: 20160), "2w")
        XCTAssertNil(QuotaFormatter.durationLabel(for: nil))
        XCTAssertNil(QuotaFormatter.durationLabel(for: 0))
    }
}
