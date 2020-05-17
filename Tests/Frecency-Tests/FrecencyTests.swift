import XCTest
@testable import Frecency

final class FrecencyTests: XCTestCase {
    func testExample() {
        XCTAssertEqual(Frecency().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
