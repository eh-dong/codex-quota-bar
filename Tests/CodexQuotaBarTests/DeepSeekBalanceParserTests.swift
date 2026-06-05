import Foundation
import XCTest
@testable import CodexQuotaBar

final class DeepSeekBalanceParserTests: XCTestCase {
    func testDecodesBalanceResponse() throws {
        let data = """
        {
          "is_available": true,
          "balance_infos": [
            {
              "currency": "CNY",
              "total_balance": "110.00",
              "granted_balance": "10.00",
              "topped_up_balance": "100.00"
            }
          ]
        }
        """.data(using: .utf8)!

        let balance = try DeepSeekBalanceParser.decode(data)

        XCTAssertTrue(balance.isAvailable)
        XCTAssertEqual(balance.totalDisplay, "¥110.00")
        XCTAssertEqual(balance.grantedDisplay, "¥10.00")
        XCTAssertEqual(balance.toppedUpDisplay, "¥100.00")
    }

    func testFormatsUnknownCurrency() {
        let balance = DeepSeekBalance(
            isAvailable: true,
            currency: "EUR",
            totalBalance: "3.50",
            grantedBalance: nil,
            toppedUpBalance: nil
        )

        XCTAssertEqual(balance.totalDisplay, "3.50 EUR")
    }
}
