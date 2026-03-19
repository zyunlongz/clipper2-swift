import XCTest
import Foundation
@testable import Clipper2

final class TestLines: XCTestCase {

    func testLinesFile() throws {
        let testCases = try ClipperFileIO.loadTestCases("Lines.txt")

        for test in testCases {
            let c64 = Clipper64()
            var solution: Paths64 = []
            var solutionOpen: Paths64 = []

            c64.addSubjects(test.subj)
            c64.addOpenSubjects(test.subjOpen)
            c64.addClips(test.clip)
            c64.execute(test.clipType, test.fillRule, &solution, &solutionOpen)

            if test.area > 0 {
                let area2 = Clipper.area(solution)
                XCTAssertEqual(Double(test.area), area2, accuracy: Double(test.area) * 0.005,
                               "Test \(test.testNum) (\(test.caption)): area mismatch")
            }

            if test.count > 0 && abs(solution.count - test.count) > 0 {
                XCTAssertTrue(abs(solution.count - test.count) < 2,
                              "Test \(test.testNum) (\(test.caption)): Vertex count incorrect. Difference=\(solution.count - test.count)")
            }
        }
    }
}
