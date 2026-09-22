import CoreGraphics
import XCTest
@testable import OpenRouterCreditsCore

final class SVGPathTests: XCTestCase {
    /// Il path del marchio, identico a `st-glyph` di `openrouter-light.svg`.
    private let glyph = """
    M303.9475,17.19926c42.79734,0,77.48933,34.69327,77.48933,77.48933s-34.69199,77.48933-77.48933,77.48933l76.86166,76.86244c9.76367,9.76313,2.84903,26.45667-10.95697,26.45667h-220.88335c-71.32686,0-129.14889-57.82202-129.14889-129.14889S77.64197,17.19926,148.96884,17.19926h154.97866ZM148.96884,68.85881c-42.79607,0-77.48933,34.69327-77.48933,77.48933s34.69327,77.48933,77.48933,77.48933,77.48933-34.69327,77.48933-77.48933-34.69327-77.48933-77.48933-77.48933Z
    """

    func testGlyphBoundsMatchBrandViewBox() {
        let path = SVGPathParser.path(from: glyph)
        let bounds = path.boundingBoxOfPath
        XCTAssertEqual(bounds.minX, 19.81995, accuracy: 0.001)
        XCTAssertEqual(bounds.minY, 17.19926, accuracy: 0.001)
        XCTAssertEqual(bounds.maxX, 385.37987, accuracy: 0.001)
        XCTAssertEqual(bounds.maxY, 275.49703, accuracy: 0.001)
    }

    func testGlyphHasOuterAndInnerSubpath() {
        let path = SVGPathParser.path(from: glyph)
        var moveCount = 0
        path.applyWithBlock { element in
            if element.pointee.type == .moveToPoint { moveCount += 1 }
        }
        XCTAssertEqual(moveCount, 2, "il segno è un cerchio con il foro interno")
    }

    func testAbsoluteSquare() {
        let path = SVGPathParser.path(from: "M0,0 L10,0 L10,10 Z")
        let bounds = path.boundingBoxOfPath
        XCTAssertEqual(bounds, CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    func testRelativeAndImplicitLineCommands() {
        let path = SVGPathParser.path(from: "m10,10 l5,0 0,5")
        let bounds = path.boundingBoxOfPath
        XCTAssertEqual(bounds, CGRect(x: 10, y: 10, width: 5, height: 5))
    }

    func testHorizontalAndVerticalCommands() {
        let path = SVGPathParser.path(from: "M5,5 H15 V15 h-10 v-10")
        let bounds = path.boundingBoxOfPath
        XCTAssertEqual(bounds, CGRect(x: 5, y: 5, width: 10, height: 10))
    }

    func testSmoothCurveUsesReflection() {
        // Il secondo tratto riflette il punto di controllo precedente:
        // P1 = (-10,10), P2 = (-10,20). La curva tocca ±7.5 sull'asse x.
        let path = SVGPathParser.path(from: "M0,0 C10,0 10,10 0,10 S-10,20 0,20")
        let bounds = path.boundingBoxOfPath
        XCTAssertEqual(bounds.minX, -7.5, accuracy: 0.001)
        XCTAssertEqual(bounds.maxX, 7.5, accuracy: 0.001)
        XCTAssertEqual(bounds.minY, 0, accuracy: 0.001)
        XCTAssertEqual(bounds.maxY, 20, accuracy: 0.001)
    }

    func testExponentAndSignedNumbers() {
        let path = SVGPathParser.path(from: "M1e1,-1e1 L-2.5,-2.5")
        let bounds = path.boundingBoxOfPath
        XCTAssertEqual(bounds, CGRect(x: -2.5, y: -10, width: 12.5, height: 7.5))
    }
}