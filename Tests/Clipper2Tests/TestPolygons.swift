import XCTest
import Foundation
@testable import Clipper2

final class TestPolygons: XCTestCase {

    func testPolygonsFile() throws {
        let testCases = try ClipperFileIO.loadTestCases("Polygons.txt")

        for test in testCases {
            let c64 = Clipper64()
            var solution: Paths64 = []
            var solutionOpen: Paths64 = []

            c64.addSubjects(test.subj)
            c64.addOpenSubjects(test.subjOpen)
            c64.addClips(test.clip)
            c64.execute(test.clipType, test.fillRule, &solution, &solutionOpen)

            let measuredCount = solution.count
            let measuredArea = Int64(Clipper.area(solution))
            let storedCount = test.count
            let storedArea = test.area
            let countDiff = storedCount > 0 ? abs(storedCount - measuredCount) : 0
            let areaDiff = storedArea > 0 ? abs(storedArea - measuredArea) : Int64(0)
            let areaDiffRatio = storedArea <= 0 ? 0.0 : Double(areaDiff) / Double(storedArea)
            let testNum = test.testNum

            // check polygon counts
            if storedCount > 0 {
                if [140, 150, 165, 166, 168, 172, 173, 176, 177, 179].contains(testNum) {
                    XCTAssertTrue(countDiff <= 7, "Test \(testNum): Diff=\(countDiff)")
                } else if testNum == 126 {
                    XCTAssertTrue(countDiff <= 3, "Test \(testNum)")
                } else if [16, 27].contains(testNum) {
                    XCTAssertTrue(countDiff <= 2, "Test \(testNum)")
                } else if testNum == 121 {
                    XCTAssertTrue(countDiff <= 3, "Test \(testNum)")
                } else if testNum >= 120 {
                    XCTAssertTrue(countDiff <= 6, "Test \(testNum)")
                } else if [23, 37, 43, 45, 87, 102, 111, 118, 119].contains(testNum) {
                    XCTAssertTrue(countDiff <= 1, "Test \(testNum)")
                } else {
                    XCTAssertTrue(countDiff == 0, "Test \(testNum): countDiff=\(countDiff)")
                }
            }

            // check polygon areas
            if storedArea > 0 {
                if [19, 22, 23, 24].contains(testNum) {
                    XCTAssertTrue(areaDiffRatio <= 0.5, "Test \(testNum): areaDiffRatio=\(areaDiffRatio)")
                } else if testNum == 193 {
                    XCTAssertTrue(areaDiffRatio <= 0.25, "Test \(testNum)")
                } else if testNum == 63 {
                    XCTAssertTrue(areaDiffRatio <= 0.1, "Test \(testNum)")
                } else if testNum == 16 {
                    XCTAssertTrue(areaDiffRatio <= 0.075, "Test \(testNum)")
                } else if [15, 26].contains(testNum) {
                    XCTAssertTrue(areaDiffRatio <= 0.05, "Test \(testNum)")
                } else if [52, 53, 54, 59, 60, 64, 117, 118, 119, 184].contains(testNum) {
                    XCTAssertTrue(areaDiffRatio <= 0.02, "Test \(testNum)")
                } else {
                    XCTAssertTrue(areaDiffRatio <= 0.01, "Test \(testNum): areaDiffRatio=\(areaDiffRatio)")
                }
            }
        }
    }

    func testCollinearOnMacOs() { // #777
        var subject: Paths64 = []
        subject.append(Clipper.makePath([Int64(0), -453054451, 0, -433253797, -455550000, 0]))
        subject.append(Clipper.makePath([Int64(0), -433253797, 0, 0, -455550000, 0]))
        let clipper = Clipper64()
        clipper.preserveCollinear = false
        clipper.addSubjects(subject)
        var solution: Paths64 = []
        clipper.execute(.union, .nonZero, &solution)
        XCTAssertEqual(1, solution.count)
        XCTAssertEqual(3, solution[0].count)
        XCTAssertEqual(Clipper.isPositive(subject[0]), Clipper.isPositive(solution[0]))
    }
}
