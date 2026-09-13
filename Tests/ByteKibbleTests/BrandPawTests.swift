import XCTest
import SwiftUI
@testable import ByteKibble

final class BrandPawTests: XCTestCase {
    func testPawKeepsOriginalAspectRatioInWideAndTallFrames() {
        let shape = BrandPawShape()
        let square = shape.path(in: CGRect(x: 0, y: 0, width: 64, height: 64)).boundingRect
        for frame in [CGRect(x: 10, y: 20, width: 180, height: 64),
                      CGRect(x: 10, y: 20, width: 64, height: 180)] {
            let bounds = shape.path(in: frame).boundingRect
            XCTAssertEqual(bounds.width / bounds.height, square.width / square.height, accuracy: 0.0001)
            XCTAssertEqual(bounds.midX, frame.midX, accuracy: 0.0001)
            XCTAssertEqual(bounds.midY, frame.midY, accuracy: 0.0001)
        }
    }
}
