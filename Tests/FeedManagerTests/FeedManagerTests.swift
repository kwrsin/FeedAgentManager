import XCTest
@testable import FeedManager

final class FeedManagerTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(FeedManager().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
