import XCTest
import SwiftUI
@testable import ByteKibble

final class BrandPawTests: XCTestCase {
    func testCentralPadIsCircularInEveryFrame() {
        for frame in [CGRect(x: 0, y: 0, width: 64, height: 64),
                      CGRect(x: 10, y: 20, width: 180, height: 64),
                      CGRect(x: 10, y: 20, width: 64, height: 180)] {
            var pad = Path()
            var closed = false
            BrandPawShape().path(in: frame).forEach { element in
                guard !closed else { return }
                switch element {
                case .move(to: let p): pad.move(to: p)
                case .line(to: let p): pad.addLine(to: p)
                case .quadCurve(to: let p, control: let c): pad.addQuadCurve(to: p, control: c)
                case .curve(to: let p, control1: let a, control2: let b):
                    pad.addCurve(to: p, control1: a, control2: b)
                case .closeSubpath: pad.closeSubpath(); closed = true
                }
            }
            let bounds = pad.boundingRect
            XCTAssertTrue(closed)
            XCTAssertGreaterThan(bounds.width, 0)
            XCTAssertEqual(bounds.width, bounds.height, accuracy: 0.0001)
            XCTAssertTrue(pad.contains(CGPoint(x: bounds.midX, y: bounds.midY)))
            XCTAssertFalse(pad.contains(CGPoint(x: bounds.minX, y: bounds.minY)))
        }
    }

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
