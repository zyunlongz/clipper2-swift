import XCTest
import Foundation
@testable import Clipper2

final class TestToStringOutput: XCTestCase {

    func testPath64ToStringMatchesExistingFormat() {
        let path: Path64 = [Point64(Int64(1), Int64(2)), Point64(Int64(3), Int64(4))]
        XCTAssertEqual("(1,2), (3,4)", path.pathDescription)
    }

    func testPathDToStringMatchesExistingFormat() {
        var path: PathD = []
        path.append(PointD(1.5, 2.5))
        path.append(PointD(3.5, 4.5))
        XCTAssertEqual("(1.500000,2.500000), (3.500000,4.500000)", path.pathDescription)
    }

    func testPaths64ToStringMatchesExistingFormat() {
        let paths: Paths64 = [[Point64(Int64(1), Int64(2))]]
        XCTAssertEqual("(1,2)", paths.pathsDescription)
    }

    func testPathsDToStringMatchesExistingFormat() {
        var paths: PathsD = []
        var path: PathD = []
        path.append(PointD(1.5, 2.5))
        paths.append(path)
        XCTAssertEqual("(1.500000,2.500000)", paths.pathsDescription)
    }

    func testPolyPathBaseToStringMatchesExistingFormat() {
        let tree = PolyTree64()
        let polygon = tree.addChild(Path64())
        polygon.addChild(Path64())
        XCTAssertEqual("Polytree with 1 polygon.\n  +- polygon (0) contains 1 hole.\n\n", tree.treeDescription)
        XCTAssertEqual("Polytree with 1 polygon.\n  +- polygon (0) contains 1 hole.\n\n", tree.description)
    }
}
