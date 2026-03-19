import XCTest
import Foundation
@testable import Clipper2

final class TestRectClip: XCTestCase {

    func testRectClip() {
        var sub: Paths64 = []
        var clp: Paths64 = []

        var rect = Rect64(100, 100, 700, 500)
        clp.append(rect.asPath())

        // Test case 1: Subject is identical to clip rect
        sub.append(Clipper.makePath([Int64(100), 100, 700, 100, 700, 500, 100, 500]))
        var sol = Clipper.rectClip(rect, sub)
        XCTAssertEqual(abs(Clipper.area(sub)), abs(Clipper.area(sol)), "Test 1 failed")

        // Test case 2: Subject partially outside but covers same area within clip rect
        sub.removeAll()
        sub.append(Clipper.makePath([Int64(110), 110, 700, 100, 700, 500, 100, 500]))
        sol = Clipper.rectClip(rect, sub)
        XCTAssertEqual(abs(Clipper.area(sub)), abs(Clipper.area(sol)), "Test 2 failed")

        // Test case 3: Subject partially outside, clipped area should equal clip rect area
        sub.removeAll()
        sub.append(Clipper.makePath([Int64(90), 90, 700, 100, 700, 500, 100, 500]))
        sol = Clipper.rectClip(rect, sub)
        XCTAssertEqual(abs(Clipper.area(clp)), abs(Clipper.area(sol)), "Test 3 failed")

        // Test case 4: Subject fully inside clip rect
        sub.removeAll()
        sub.append(Clipper.makePath([Int64(110), 110, 690, 110, 690, 490, 110, 490]))
        sol = Clipper.rectClip(rect, sub)
        XCTAssertEqual(abs(Clipper.area(sub)), abs(Clipper.area(sol)), "Test 4 failed")

        // Test case 5: Subject touches edge, should result in empty solution
        sub.removeAll()
        clp.removeAll()
        rect = Rect64(390, 290, 410, 310)
        sub.append(Clipper.makePath([Int64(410), 290, 500, 290, 500, 310, 410, 310]))
        sol = Clipper.rectClip(rect, sub)
        XCTAssertTrue(sol.isEmpty, "Test 5 failed - should be empty")

        // Test case 6: Triangle outside rect
        sub.removeAll()
        sub.append(Clipper.makePath([Int64(430), 290, 470, 330, 390, 330]))
        sol = Clipper.rectClip(rect, sub)
        XCTAssertTrue(sol.isEmpty, "Test 6 failed - should be empty")

        // Test case 7: Triangle outside rect
        sub.removeAll()
        sub.append(Clipper.makePath([Int64(450), 290, 480, 330, 450, 330]))
        sol = Clipper.rectClip(rect, sub)
        XCTAssertTrue(sol.isEmpty, "Test 7 failed - should be empty")

        // Test case 8: Complex polygon clipped, check bounds of result
        sub.removeAll()
        sub.append(Clipper.makePath([Int64(208), 66, 366, 112, 402, 303, 234, 332, 233, 262, 243, 140, 215, 126, 40, 172]))
        rect = Rect64(237, 164, 322, 248)
        sol = Clipper.rectClip(rect, sub)
        XCTAssertFalse(sol.isEmpty, "Test 8 failed - should not be empty")
        let solBounds = Clipper.getBounds(sol)
        XCTAssertEqual(rect.width, solBounds.width, "Test 8 failed - Width mismatch")
        XCTAssertEqual(rect.height, solBounds.height, "Test 8 failed - Height mismatch")
    }

    func testRectClip2() {
        let rect = Rect64(54690, 0, 65628, 6000)
        var subject: Paths64 = []
        subject.append(Clipper.makePath([Int64(700000), 6000, 0, 6000, 0, 5925, 700000, 5925]))

        let solution = Clipper.rectClip(rect, subject)

        XCTAssertFalse(solution.isEmpty, "TestRectClip2 Solution should not be empty")
        XCTAssertEqual(1, solution.count, "TestRectClip2 Should have 1 path")
        XCTAssertEqual(4, solution[0].count, "TestRectClip2 Path should have 4 points")
    }

    func testRectClip3() {
        let r = Rect64(-1800000000, -137573171, -1741475021, 3355443)
        var subject: Paths64 = []

        subject.append(Clipper.makePath([Int64(-1800000000), 10005000, -1800000000, -5000, -1789994999, -5000, -1789994999, 10005000]))

        let solution = Clipper.rectClip(r, subject)

        XCTAssertFalse(solution.isEmpty, "TestRectClip3 Solution should not be empty")
        XCTAssertEqual(1, solution.count, "TestRectClip3 Should have 1 path")
        XCTAssertFalse(solution[0].isEmpty, "TestRectClip3 Path should not be empty")
        let expectedPath = Clipper.makePath([Int64(-1789994999), 3355443, -1800000000, 3355443, -1800000000, -5000, -1789994999, -5000])
        XCTAssertEqual(abs(Clipper.area(expectedPath)), abs(Clipper.area(solution[0])), "TestRectClip3 Area check")
    }
}
