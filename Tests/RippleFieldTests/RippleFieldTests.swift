import XCTest
@testable import RippleField

@MainActor final class RippleFieldTests: XCTestCase {
    func testEngineStartsIdle() {
        let engine = RippleEngine()
        XCTAssertTrue(engine.isIdle)
    }
}
