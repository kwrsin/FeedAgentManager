import XCTest
@testable import FeedAgentManager

final class FeedAgentManagerTests: XCTestCase {
//    func testStrageUserDefaults_token() {
//        StrageManager.shared().strage.setProperty(key: StrageManager.Fields.token, value: "abcdefg")
//
//
//        if let values = StrageManager.shared().strage.getProperty(key: StrageManager.Fields.token) as? String {
//            print("ans = \(value)")
//            XCTAssertEqual("abcdefg", value)
//
//        } else {
//            XCTAssert(true)
//
//        }
//
//    }
    func testStrageUserDefaults_reading_row() {
        let dic :[String: Any] = [
            "aaaa": 12,
            "bb": "1234"
        ]
        StrageManager.shared().strage.storeProperties(key: "mykey", dict: dic)
        
        
        if let values = StrageManager.shared().strage.loadProperties(key: "mykey")! as [String: Any]? {
            print("ans = \(values)")
            XCTAssertTrue(values.isEmpty == false)

        } else {
            XCTAssert(true)
            
        }
        
    }
//    func testExample() {
//        // This is an example of a functional test case.
//        // Use XCTAssert and related functions to verify your tests produce the correct
//        // results.
//        XCTAssertEqual(FeedManager().text, "Hello, World!")
//    }

//    static var allTests = [
//        ("testExample", testExample),
//    ]
    
}
