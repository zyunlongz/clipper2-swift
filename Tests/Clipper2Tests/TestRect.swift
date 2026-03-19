import XCTest
@testable import Clipper2

final class TestRect: XCTestCase {

    private func assertRectEquals(_ expected: Rect64, _ actual: Rect64,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(expected.left, actual.left, file: file, line: line)
        XCTAssertEqual(expected.top, actual.top, file: file, line: line)
        XCTAssertEqual(expected.right, actual.right, file: file, line: line)
        XCTAssertEqual(expected.bottom, actual.bottom, file: file, line: line)
    }

    func testRectOpAdd() {
        do {
            let lhs = Rect64(isValid: false)
            let rhs = Rect64(-1, -1, 10, 10)
            var sum = lhs + rhs
            assertRectEquals(rhs, sum)
            sum = rhs + lhs
            assertRectEquals(rhs, sum)
        }
        do {
            let lhs = Rect64(isValid: false)
            let rhs = Rect64(1, 1, 10, 10)
            var sum = lhs + rhs
            assertRectEquals(rhs, sum)
            sum = rhs + lhs
            assertRectEquals(rhs, sum)
        }
        do {
            let lhs = Rect64(0, 0, 1, 1)
            let rhs = Rect64(-1, -1, 0, 0)
            let expected = Rect64(-1, -1, 1, 1)
            var sum = lhs + rhs
            assertRectEquals(expected, sum)
            sum = rhs + lhs
            assertRectEquals(expected, sum)
        }
        do {
            let lhs = Rect64(-10, -10, -1, -1)
            let rhs = Rect64(1, 1, 10, 10)
            let expected = Rect64(-10, -10, 10, 10)
            var sum = lhs + rhs
            assertRectEquals(expected, sum)
            sum = rhs + lhs
            assertRectEquals(expected, sum)
        }
    }
}
