import XCTest
import Foundation
@testable import Clipper2

final class TestPolytree: XCTestCase {

    // MARK: - Helper functions

    private static func checkPolytreeFullyContainsChildren(_ polytree: PolyTree64) -> Bool {
        for p in polytree {
            let child = p as! PolyPath64
            if child.count > 0 && !polyPathFullyContainsChildren(child) {
                return false
            }
        }
        return true
    }

    private static func polyPathFullyContainsChildren(_ pp: PolyPath64) -> Bool {
        for c in pp {
            let child = c as! PolyPath64
            if let polygon = child.getPolygon() {
                for pt in polygon {
                    if let parentPoly = pp.getPolygon(),
                       Clipper.pointInPolygon(pt, parentPoly) == .isOutside {
                        return false
                    }
                }
            }
            if child.count > 0 && !polyPathFullyContainsChildren(child) {
                return false
            }
        }
        return true
    }

    private func polytreeContainsPoint(_ pp: PolyTree64, _ pt: Point64) -> Bool {
        var counter = 0
        for i in 0..<pp.count {
            let child = pp.get(i)
            counter = TestPolytree.polyPathContainsPoint(child, pt, counter)
        }
        XCTAssertTrue(counter >= 0, "Polytree has too many holes")
        return counter != 0
    }

    private static func polyPathContainsPoint(_ pp: PolyPath64, _ pt: Point64, _ counter: Int) -> Int {
        var counter = counter
        if let polygon = pp.getPolygon(),
           Clipper.pointInPolygon(pt, polygon) != .isOutside {
            if pp.isHole {
                counter -= 1
            } else {
                counter += 1
            }
        }
        for i in 0..<pp.count {
            let child = pp.get(i)
            counter = TestPolytree.polyPathContainsPoint(child, pt, counter)
        }
        return counter
    }

    // MARK: - Tests

    func testPolytreeFile() throws {
        let testCases = try ClipperFileIO.loadTestCases("PolytreeHoleOwner2.txt")

        for test in testCases {
            XCTContext.runActivity(named: "\(test.caption) \(test.clipType) \(test.fillRule)") { _ in
                let solutionTree = PolyTree64()
                var solutionOpen: Paths64 = []
                let clipper = Clipper64()

                let subject = test.subj
                let subjectOpen = test.subjOpen
                let clip = test.clip

                let pointsOfInterestOutside: [Point64] = [
                    Point64(Int64(21887), Int64(10420)), Point64(Int64(21726), Int64(10825)),
                    Point64(Int64(21662), Int64(10845)), Point64(Int64(21617), Int64(10890))
                ]

                for pt in pointsOfInterestOutside {
                    for path in subject {
                        XCTAssertEqual(.isOutside, Clipper.pointInPolygon(pt, path),
                                       "outside point of interest found inside subject")
                    }
                }

                let pointsOfInterestInside: [Point64] = [
                    Point64(Int64(21887), Int64(10430)), Point64(Int64(21843), Int64(10520)),
                    Point64(Int64(21810), Int64(10686)), Point64(Int64(21900), Int64(10461))
                ]

                for pt in pointsOfInterestInside {
                    var poiInsideCounter = 0
                    for path in subject {
                        if Clipper.pointInPolygon(pt, path) == .isInside {
                            poiInsideCounter += 1
                        }
                    }
                    XCTAssertEqual(1, poiInsideCounter,
                                   "poi_inside_counter - expected 1 but got \(poiInsideCounter)")
                }

                clipper.addSubjects(subject)
                clipper.addOpenSubjects(subjectOpen)
                clipper.addClips(clip)
                clipper.execute(test.clipType, test.fillRule, solutionTree, &solutionOpen)

                let solutionPaths = Clipper.polyTreeToPaths64(solutionTree)
                let a1 = Clipper.area(solutionPaths)
                let a2 = solutionTree.area()

                XCTAssertTrue(a1 > 330000,
                              "solution has wrong area - value expected: 331,052; value returned: \(a1)")

                XCTAssertTrue(abs(a1 - a2) < 0.0001,
                              "solution tree has wrong area - value expected: \(a1); value returned: \(a2)")

                XCTAssertTrue(TestPolytree.checkPolytreeFullyContainsChildren(solutionTree),
                              "The polytree doesn't properly contain its children")

                for pt in pointsOfInterestOutside {
                    XCTAssertFalse(polytreeContainsPoint(solutionTree, pt),
                                   "The polytree indicates it contains a point that it should not contain")
                }

                for pt in pointsOfInterestInside {
                    XCTAssertTrue(polytreeContainsPoint(solutionTree, pt),
                                  "The polytree indicates it does not contain a point that it should contain")
                }
            }
        }
    }

    func testPolytree3() { // #942
        var subject: Paths64 = []
        subject.append(Clipper.makePath([Int64(1588700), -8717600, 1616200, -8474800, 1588700, -8474800]))
        subject.append(Clipper.makePath([Int64(13583800), -15601600, 13582800, -15508500, 13555300, -15508500, 13555500, -15182200, 13010900, -15185400]))
        subject.append(Clipper.makePath([Int64(956700), -3092300, 1152600, 3147400, 25600, 3151700]))
        subject.append(Clipper.makePath([Int64(22575900), -16604000, 31286800, -12171900, 31110200, 4882800, 30996200, 4826300, 30414400, 5447400, 30260000, 5391500,
                29662200, 5805400, 28844500, 5337900, 28435000, 5789300, 27721400, 5026400, 22876300, 5034300, 21977700, 4414900, 21148000, 4654700, 20917600, 4653400,
                19334300, 12411000, -2591700, 12177200, 53200, 3151100, -2564300, 12149800, 7819400, 4692400, 10116000, 5228600, 6975500, 3120100, 7379700, 3124700,
                11037900, 596200, 12257000, 2587800, 12257000, 596200, 15227300, 2352700, 18444400, 1112100, 19961100, 5549400, 20173200, 5078600, 20330000, 5079300,
                20970200, 4544300, 20989600, 4563700, 19465500, 1112100, 21611600, 4182100, 22925100, 1112200, 22952700, 1637200, 23059000, 1112200, 24908100, 4181200,
                27070100, 3800600, 27238000, 3800700, 28582200, 520300, 29367800, 1050100, 29291400, 179400, 29133700, 360700, 29056700, 312600, 29121900, 332500,
                29269900, 162300, 28941400, 213100, 27491300, -3041500, 27588700, -2997800, 22104900, -16142800, 13010900, -15603000, 13555500, -15182200,
                13555300, -15508500, 13582800, -15508500, 13583100, -15154700, 1588700, -8822800, 1588700, -8379900, 1588700, -8474800, 1616200, -8474800, 1003900,
                -630100, 1253300, -12284500, 12983400, -16239900]))
        subject.append(Clipper.makePath([Int64(198200), 12149800, 1010600, 12149800, 1011500, 11859600]))
        subject.append(Clipper.makePath([Int64(21996700), -7432000, 22096700, -7432000, 22096700, -7332000]))

        let solutionTree = PolyTree64()
        let clipper = Clipper64()
        clipper.addSubjects(subject)
        clipper.execute(.union, .nonZero, solutionTree)

        XCTAssertTrue(solutionTree.count == 1 && solutionTree.get(0).count == 2 && solutionTree.get(0).get(1).count == 1)
    }

    func testPolytree4() { // #957
        var subject: Paths64 = []
        subject.append(Clipper.makePath([Int64(77910), 46865, 78720, 46865, 78720, 48000, 77910, 48000, 77910, 46865]))
        subject.append(Clipper.makePath([Int64(82780), 53015, 93600, 53015, 93600, 54335, 82780, 54335, 82780, 53015]))
        subject.append(Clipper.makePath([Int64(82780), 48975, 84080, 48975, 84080, 53015, 82780, 53015, 82780, 48975]))
        subject.append(Clipper.makePath([Int64(77910), 48000, 84080, 48000, 84080, 48975, 77910, 48975, 77910, 48000]))
        subject.append(Clipper.makePath([Int64(89880), 40615, 90700, 40615, 90700, 46865, 89880, 46865, 89880, 40615]))
        subject.append(Clipper.makePath([Int64(92700), 54335, 93600, 54335, 93600, 61420, 92700, 61420, 92700, 54335]))
        subject.append(Clipper.makePath([Int64(78950), 47425, 84080, 47425, 84080, 47770, 78950, 47770, 78950, 47425]))
        subject.append(Clipper.makePath([Int64(82780), 61420, 93600, 61420, 93600, 62435, 82780, 62435, 82780, 61420]))
        subject.append(Clipper.makePath([Int64(101680), 63085, 100675, 63085, 100675, 47770, 100680, 47770, 100680, 40615, 101680, 40615, 101680, 63085]))
        subject.append(Clipper.makePath([Int64(76195), 39880, 89880, 39880, 89880, 41045, 76195, 41045, 76195, 39880]))
        subject.append(Clipper.makePath([Int64(85490), 56145, 90520, 56145, 90520, 59235, 85490, 59235, 85490, 56145]))
        subject.append(Clipper.makePath([Int64(89880), 39880, 101680, 39880, 101680, 40615, 89880, 40615, 89880, 39880]))
        subject.append(Clipper.makePath([Int64(89880), 46865, 100680, 46865, 100680, 47770, 89880, 47770, 89880, 46865]))
        subject.append(Clipper.makePath([Int64(82780), 54335, 83280, 54335, 83280, 61420, 82780, 61420, 82780, 54335]))
        subject.append(Clipper.makePath([Int64(76195), 41045, 76855, 41045, 76855, 62665, 76195, 62665, 76195, 41045]))
        subject.append(Clipper.makePath([Int64(76195), 62665, 100675, 62665, 100675, 63085, 76195, 63085, 76195, 62665]))
        subject.append(Clipper.makePath([Int64(82780), 41045, 84080, 41045, 84080, 47425, 82780, 47425, 82780, 41045]))

        let solutionTree = PolyTree64()
        let clipper = Clipper64()
        clipper.addSubjects(subject)
        clipper.execute(.union, .nonZero, solutionTree)

        XCTAssertTrue(solutionTree.count == 1 && solutionTree.get(0).count == 2 && solutionTree.get(0).get(0).count == 1)
    }

    func testPolytree5() { // #973
        var subject: Paths64 = []
        subject.append(Clipper.makePath([Int64(0), 0, 79530, 0, 79530, 940, 0, 940, 0, 0]))
        subject.append(Clipper.makePath([Int64(0), 33360, 79530, 33360, 79530, 34300, 0, 34300, 0, 33360]))
        subject.append(Clipper.makePath([Int64(78470), 940, 79530, 940, 79530, 33360, 78470, 33360, 78470, 940]))
        subject.append(Clipper.makePath([Int64(0), 940, 940, 940, 940, 33360, 0, 33360, 0, 940]))
        subject.append(Clipper.makePath([Int64(29290), 940, 30350, 940, 30350, 33360, 29290, 33360, 29290, 940]))

        let solutionTree = PolyTree64()
        let clipper = Clipper64()
        clipper.addSubjects(subject)
        clipper.execute(.union, .nonZero, solutionTree)

        XCTAssertTrue(solutionTree.count == 1 && solutionTree.get(0).count == 2)
    }

    func testPolytreeUnion() {
        var subject: Paths64 = []
        subject.append(Clipper.makePath([Int64(0), 0, 0, 5, 5, 5, 5, 0]))
        subject.append(Clipper.makePath([Int64(1), 1, 1, 6, 6, 6, 6, 1]))

        let clipper = Clipper64()
        clipper.addSubjects(subject)

        let solution = PolyTree64()
        var openPaths: Paths64 = []
        if Clipper.isPositive(subject[0]) {
            clipper.execute(.union, .positive, solution, &openPaths)
        } else {
            clipper.reverseSolution = true
            clipper.execute(.union, .negative, solution, &openPaths)
        }

        XCTAssertEqual(0, openPaths.count)
        XCTAssertEqual(1, solution.count)
        XCTAssertEqual(8, solution.get(0).getPolygon()!.count)
        XCTAssertEqual(Clipper.isPositive(subject[0]), Clipper.isPositive(solution.get(0).getPolygon()!))
    }

    func testPolytreeUnion2() { // #987
        var subject: Paths64 = []
        subject.append(Clipper.makePath([Int64(534), 1024, 534, -800, 1026, -800, 1026, 1024]))
        subject.append(Clipper.makePath([Int64(1), 1024, 8721, 1024, 8721, 1920, 1, 1920]))
        subject.append(Clipper.makePath([Int64(30), 1024, 30, -800, 70, -800, 70, 1024]))
        subject.append(Clipper.makePath([Int64(1), 1024, 1, -1024, 3841, -1024, 3841, 1024]))
        subject.append(Clipper.makePath([Int64(3900), -1024, 6145, -1024, 6145, 1024, 3900, 1024]))
        subject.append(Clipper.makePath([Int64(5884), 1024, 5662, 1024, 5662, -1024, 5884, -1024]))
        subject.append(Clipper.makePath([Int64(534), 1024, 200, 1024, 200, -800, 534, -800]))
        subject.append(Clipper.makePath([Int64(200), -800, 200, 1024, 70, 1024, 70, -800]))
        subject.append(Clipper.makePath([Int64(1200), 1920, 1313, 1920, 1313, -800, 1200, -800]))
        subject.append(Clipper.makePath([Int64(6045), -800, 6045, 1024, 5884, 1024, 5884, -800]))

        let clipper = Clipper64()
        clipper.addSubjects(subject)
        let solution = PolyTree64()
        var openPaths: Paths64 = []
        clipper.execute(.union, .evenOdd, solution, &openPaths)

        XCTAssertEqual(1, solution.count)
        XCTAssertEqual(1, solution.get(0).count)
    }

    func testPolytreeUnion3() {
        var subject: Paths64 = []
        subject.append(Clipper.makePath([Int64(-120927680), 590077597,
                -120919386, 590077307,
                -120919432, 590077309,
                -120919451, 590077309,
                -120919455, 590077310,
                -120099297, 590048669,
                -120928004, 590077608,
                -120902794, 590076728,
                -120919444, 590077309,
                -120919450, 590077309,
                -120919842, 590077323,
                -120922852, 590077428,
                -120902452, 590076716,
                -120902455, 590076716,
                -120912590, 590077070,
                11914491, 249689797
        ]))

        let clipper = Clipper64()
        clipper.addSubjects(subject)
        let solution = PolyTree64()
        clipper.execute(.union, .evenOdd, solution)

        XCTAssertTrue(solution.count >= 0)
    }
}
