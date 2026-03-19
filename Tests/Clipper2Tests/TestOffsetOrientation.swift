import XCTest
import Foundation
@testable import Clipper2

final class TestOffsetOrientation: XCTestCase {

    func testOffsettingOrientation1() {
        let subject: Paths64 = [Clipper.makePath([Int32(0), 0, 0, 5, 5, 5, 5, 0])]

        let solution = Clipper.inflatePaths(subject, 1, .round, .polygon)

        XCTAssertEqual(1, solution.count)
        // when offsetting, output orientation should match input
        XCTAssertTrue(Clipper.isPositive(subject[0]) == Clipper.isPositive(solution[0]))
    }

    func testOffsettingOrientation2() {
        let s1 = Clipper.makePath([Int32(20), 220, 280, 220, 280, 280, 20, 280])
        let s2 = Clipper.makePath([Int32(0), 200, 0, 300, 300, 300, 300, 200])
        let subject: Paths64 = [s1, s2]

        let co = ClipperOffset()
        co.reverseSolution = true
        co.addPaths(subject, .round, .polygon)

        var solution: Paths64 = []
        co.execute(5, &solution)

        XCTAssertEqual(2, solution.count)
        // When offsetting, output orientation should match input EXCEPT when
        // ReverseSolution == true. However, input path ORDER may not match output
        // path order.
        XCTAssertTrue(Clipper.isPositive(subject[1]) != Clipper.isPositive(solution[0]))
    }
}
