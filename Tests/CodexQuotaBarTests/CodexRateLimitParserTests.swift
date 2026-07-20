import Foundation
import XCTest
@testable import CodexQuotaBar

final class CodexRateLimitParserTests: XCTestCase {
    func testDecodesCodexAndSparkBuckets() throws {
        let message: [String: Any] = [
            "id": 2,
            "result": [
                "rateLimits": [
                    "limitId": "codex",
                    "primary": ["usedPercent": 4, "resetsAt": 1_780_662_851],
                    "secondary": ["usedPercent": 6, "resetsAt": 1_781_163_698],
                    "credits": ["balance": "0"]
                ],
                "rateLimitsByLimitId": [
                    "codex": [
                        "limitId": "codex",
                        "primary": ["usedPercent": 4],
                        "secondary": ["usedPercent": 6]
                    ],
                    "codex_bengalfox": [
                        "limitId": "codex_bengalfox",
                        "limitName": "GPT-5.3-Codex-Spark",
                        "primary": ["usedPercent": 0],
                        "secondary": ["usedPercent": 0]
                    ]
                ]
            ]
        ]

        let snapshot = try CodexRateLimitParser.decodeRateLimits(from: message)

        XCTAssertEqual(snapshot.codex?.limitId, "codex")
        XCTAssertEqual(snapshot.codex?.primary?.remainingPercent, 96)
        XCTAssertEqual(snapshot.codex?.secondary?.remainingPercent, 94)
        XCTAssertEqual(snapshot.codex?.credits?.balance, "0")
        XCTAssertEqual(snapshot.spark?.displayName, "GPT-5.3-Codex-Spark")
        XCTAssertEqual(snapshot.spark?.primary?.remainingPercent, 100)
        XCTAssertNil(snapshot.resetCreditsAvailableCount)
    }

    func testDecodesWeeklyOnlyWindowAndResetCredits() throws {
        let message: [String: Any] = [
            "id": 2,
            "result": [
                "rateLimits": [
                    "limitId": "codex",
                    "primary": [
                        "usedPercent": 35,
                        "windowDurationMins": 10080
                    ],
                    "secondary": NSNull()
                ],
                "rateLimitResetCredits": ["availableCount": 3]
            ]
        ]

        let snapshot = try CodexRateLimitParser.decodeRateLimits(from: message)

        XCTAssertEqual(snapshot.codex?.primary?.windowDurationMins, 10080)
        XCTAssertNil(snapshot.codex?.secondary)
        XCTAssertEqual(snapshot.resetCreditsAvailableCount, 3)
        XCTAssertEqual(QuotaFormatter.menuBarTitle(for: snapshot.codex), "Codex W65%")
    }

    func testDecodesZeroResetCredits() throws {
        let message: [String: Any] = [
            "id": 2,
            "result": [
                "rateLimits": [String: Any](),
                "rateLimitResetCredits": ["availableCount": 0]
            ]
        ]

        let snapshot = try CodexRateLimitParser.decodeRateLimits(from: message)

        XCTAssertEqual(snapshot.resetCreditsAvailableCount, 0)
    }

    func testMissingResetCreditsStayAbsent() throws {
        let message: [String: Any] = [
            "id": 2,
            "result": ["rateLimits": [String: Any]()]
        ]

        let snapshot = try CodexRateLimitParser.decodeRateLimits(from: message)

        XCTAssertNil(snapshot.resetCreditsAvailableCount)
    }

    func testParsesTargetJsonRpcLine() throws {
        let data = """
        {"id":1,"result":{}}
        {"id":2,"result":{"rateLimits":{}}}
        """.data(using: .utf8)!

        let message = try CodexRateLimitParser.parseTargetMessage(from: data)

        XCTAssertEqual(message?["id"] as? Int, 2)
    }
}
