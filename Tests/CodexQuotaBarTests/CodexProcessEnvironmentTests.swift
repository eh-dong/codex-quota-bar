import XCTest
@testable import CodexQuotaBar

final class CodexProcessEnvironmentTests: XCTestCase {
    func testAddsHomebrewAndSystemPathsWhenPathIsMissing() {
        let environment = CodexProcessEnvironment.make(base: [:])
        let path = environment["PATH"] ?? ""

        XCTAssertTrue(path.split(separator: ":").contains("/opt/homebrew/bin"))
        XCTAssertTrue(path.split(separator: ":").contains("/usr/local/bin"))
        XCTAssertTrue(path.split(separator: ":").contains("/usr/bin"))
        XCTAssertTrue(path.split(separator: ":").contains("/bin"))
        XCTAssertTrue(path.split(separator: ":").contains("/usr/sbin"))
        XCTAssertTrue(path.split(separator: ":").contains("/sbin"))
    }

    func testPreservesExistingPathAndDoesNotDuplicateRequiredEntries() {
        let environment = CodexProcessEnvironment.make(base: [
            "PATH": "/custom/bin:/opt/homebrew/bin:/another/bin",
            "CODEX_HOME": "/tmp/codex"
        ])

        let entries = (environment["PATH"] ?? "").split(separator: ":").map(String.init)

        XCTAssertEqual(entries.filter { $0 == "/opt/homebrew/bin" }.count, 1)
        XCTAssertTrue(entries.contains("/custom/bin"))
        XCTAssertTrue(entries.contains("/another/bin"))
        XCTAssertEqual(environment["CODEX_HOME"], "/tmp/codex")
    }
}
