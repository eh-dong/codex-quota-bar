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
}
