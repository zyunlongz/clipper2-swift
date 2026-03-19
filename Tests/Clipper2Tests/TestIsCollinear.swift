import XCTest
import Foundation
@testable import Clipper2

final class TestIsCollinear: XCTestCase {

    // MARK: - Helper

    private func assertMulHi(_ aHex: String, _ bHex: String, _ expectedHiHex: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        let a = Int64(bitPattern: UInt64(aHex, radix: 16)!)
        let b = Int64(bitPattern: UInt64(bHex, radix: 16)!)
        let expectedHi = Int64(bitPattern: UInt64(expectedHiHex, radix: 16)!)
        let result = InternalClipper.multiplyUInt64(a, b)
        XCTAssertEqual(expectedHi, result.hi64, file: file, line: line)
    }

    // MARK: - Tests

    func testHiCalculation() {
        assertMulHi("51eaed81157de061", "3a271fb2745b6fe9", "129bbebdfae0464e")
        assertMulHi("3a271fb2745b6fe9", "51eaed81157de061", "129bbebdfae0464e")
        assertMulHi("c2055706a62883fa", "26c78bc79c2322cc", "1d640701d192519b")
        assertMulHi("26c78bc79c2322cc", "c2055706a62883fa", "1d640701d192519b")
        assertMulHi("874ddae32094b0de", "9b1559a06fdf83e0", "51f76c49563e5bfe")
        assertMulHi("9b1559a06fdf83e0", "874ddae32094b0de", "51f76c49563e5bfe")
        assertMulHi("81fb3ad3636ca900", "239c000a982a8da4", "12148e28207b83a3")
        assertMulHi("239c000a982a8da4", "81fb3ad3636ca900", "12148e28207b83a3")
        assertMulHi("4be0b4c5d2725c44", "990cd6db34a04c30", "2d5d1a4183fd6165")
        assertMulHi("990cd6db34a04c30", "4be0b4c5d2725c44", "2d5d1a4183fd6165")
        assertMulHi("978ec0c0433c01f6", "2df03d097966b536", "1b3251d91fe272a5")
        assertMulHi("2df03d097966b536", "978ec0c0433c01f6", "1b3251d91fe272a5")
        assertMulHi("49c5cbbcfd716344", "c489e3b34b007ad3", "38a32c74c8c191a4")
        assertMulHi("c489e3b34b007ad3", "49c5cbbcfd716344", "38a32c74c8c191a4")
        assertMulHi("d3361cdbeed655d5", "1240da41e324953a", "0f0f4fa11e7e8f2a")
        assertMulHi("1240da41e324953a", "d3361cdbeed655d5", "0f0f4fa11e7e8f2a")
        assertMulHi("51b854f8e71b0ae0", "6f8d438aae530af5", "239c04ee3c8cc248")
        assertMulHi("6f8d438aae530af5", "51b854f8e71b0ae0", "239c04ee3c8cc248")
        assertMulHi("bbecf7dbc6147480", "bb0f73d0f82e2236", "895170f4e9a216a7")
        assertMulHi("bb0f73d0f82e2236", "bbecf7dbc6147480", "895170f4e9a216a7")
    }

    func testIsCollinear() {
        // A large integer not representable exactly by double.
        let i: Int64 = 9007199254740993
        let pt1 = Point64(Int64(0), Int64(0))
        let sharedPt = Point64(i, i * 10)
        let pt2 = Point64(i * 10, i * 100)
        XCTAssertTrue(InternalClipper.isCollinear(pt1, sharedPt, pt2))
    }

    func testIsCollinear2() { // see #831
        let i: Int64 = 0x4000000000000
        let subject: Path64 = [Point64(-i, -i), Point64(i, -i), Point64(-i, i), Point64(i, i)]
        let clipper = Clipper64()
        clipper.addSubjects([subject])
        var solution: Paths64 = []
        clipper.execute(.union, .evenOdd, &solution)
        XCTAssertEqual(2, solution.count)
    }
}
