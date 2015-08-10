import UIKit
import XCTest
@testable import Spate

class Tests: XCTestCase {
    var cache = Cache<NSString>(name:"testCache")
    override func setUp() {
        super.setUp()
//        cache.clearAllObjects()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSanitizeKey() {
        let key = "keyWithAlphaNumberic888*@&@&&@chars"
        let diskCache = DiskCache(name: "hi")
        let santizedKey = diskCache.sanitizeKey(key)
        
        XCTAssertEqual(santizedKey, NSString(string: "keyWithAlphaNumberic888_chars"))
    }
    
    func testSubscript() {
        cache["SubscriptedString"] = "String"
        XCTAssertNotNil(cache["SubscriptedString"])
        XCTAssertEqual(cache["SubscriptedString"], "String")
        
        cache["SubscriptedString"] = nil
        XCTAssertNil(cache["SubscriptedString"])
    }
    
    func testObjectExpiration() {
        cache["never", .Never ] = "neverExpires"
        cache["3 seconds", .Seconds(3)] = "threeSeconds"
        cache["5 seconds", .Date(NSDate().dateByAddingTimeInterval(5))] = "fiveSeconds"
        
        XCTAssertNotNil(cache["never"])
        XCTAssertNotNil(cache["3 seconds"])
        XCTAssertNotNil(cache["5 seconds"])
        
        NSThread.sleepForTimeInterval(3)
        
        XCTAssertNotNil(cache["never"])
        XCTAssertNil(cache["3 seconds"])
        XCTAssertNotNil(cache["5 seconds"])
        
        NSThread.sleepForTimeInterval(3)
        
        XCTAssertNotNil(cache["never"])
        XCTAssertNil(cache["3 seconds"])
        XCTAssertNil(cache["5 seconds"])
    }
    
}

