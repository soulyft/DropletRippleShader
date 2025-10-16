import XCTest
@testable import RippleField

final class RippleFieldTests: XCTestCase {
    func testEngineStartsIdle() {
        let engine = RippleEngine()
        XCTAssertTrue(engine.isIdle)
    }
}
