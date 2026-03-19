import XCTest
@testable import Clipper2

final class TestApiParity: XCTestCase {

    func testOffsetCanBuildPolytree64() {
        let subject: Path64 = [
            Point64(Int64(0), Int64(0)),
            Point64(Int64(10), Int64(0)),
            Point64(Int64(10), Int64(10)),
            Point64(Int64(0), Int64(10))
        ]

        let offset = ClipperOffset()
        offset.addPath(subject, .miter, .polygon)

        var solutionPaths: Paths64 = []
        offset.execute(2.0, &solutionPaths)

        let solutionTree = PolyTree64()
        offset.execute(2.0, solutionTree)

        XCTAssertEqual(solutionPaths, Clipper.polyTreeToPaths64(solutionTree))
    }

    func testInvalidPrecisionThrows() {
        let rect = RectD(0, 0, 10, 10)
        let path: PathD = [PointD(1.0, 1.0), PointD(9.0, 1.0), PointD(9.0, 9.0), PointD(1.0, 9.0)]

        XCTAssertThrowsError(try Clipper.rectClip(rect, path, 9)) { error in
            XCTAssertEqual(error as? ClipperError, .precisionOutOfRange)
        }

        XCTAssertThrowsError(try Clipper.pointInPolygon(PointD(2.0, 2.0), path, 9)) { error in
            XCTAssertEqual(error as? ClipperError, .precisionOutOfRange)
        }

        XCTAssertThrowsError(try ClipperD(roundingDecimalPrecision: 9)) { error in
            XCTAssertEqual(error as? ClipperError, .precisionOutOfRange)
        }
    }

    func testRemainingJavaStyleApiAliasesExist() {
        XCTAssertEqual(Clipper.InvalidRect64.left, Clipper.invalidRect64.left)
        XCTAssertEqual(Clipper.InvalidRectD.left, Clipper.invalidRectD.left)

        let rect = Rect64(Int64(0), Int64(0), Int64(5), Int64(5))
        let path: Path64 = [[
            Point64(Int64(1), Int64(1)),
            Point64(Int64(4), Int64(1)),
            Point64(Int64(4), Int64(4)),
            Point64(Int64(1), Int64(4))
        ]][0]

        let rc = RectClip64(rect)
        XCTAssertEqual(rc.execute([path]), [path])

        let rcl = RectClipLines64(rect)
        let openPath: Path64 = [Point64(Int64(1), Int64(1)), Point64(Int64(4), Int64(4))]
        XCTAssertEqual(rcl.execute([openPath]), [openPath])

        let tree = PolyTreeD()
        let child = tree.addChild(path)
        var paths = PathsD()
        Clipper.addPolyNodeToPathsD(child as! PolyPathD, &paths)
        XCTAssertEqual(paths.count, 1)
    }
}
