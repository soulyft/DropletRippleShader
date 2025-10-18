#if canImport(Metal)
import XCTest
import Metal
@testable import RippleField

@MainActor final class RippleFieldTests: XCTestCase {
    func testEngineStartsIdle() {
        XCTAssertNotNil(MTLCreateSystemDefaultDevice())
    }
}
#endif
