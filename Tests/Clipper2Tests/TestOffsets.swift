import XCTest
import Foundation
@testable import Clipper2

final class TestOffsets: XCTestCase {

    // MARK: - Helper functions

    private static func midPoint(_ p1: Point64, _ p2: Point64) -> Point64 {
        return Point64((p1.x + p2.x) / 2, (p1.y + p2.y) / 2)
    }

    private static func distance(_ pt1: Point64, _ pt2: Point64) -> Double {
        let dx = Double(pt1.x - pt2.x)
        let dy = Double(pt1.y - pt2.y)
        return sqrt(dx * dx + dy * dy)
    }

    private static func distancePD(_ pt1: PointD, _ pt2: PointD) -> Double {
        return sqrt(distanceSqr(pt1, pt2))
    }

    private static func distanceSqr(_ pt1: PointD, _ pt2: PointD) -> Double {
        let dx = pt1.x - pt2.x
        let dy = pt1.y - pt2.y
        return dx * dx + dy * dy
    }

    private struct OffsetQual {
        var smallestInSub: PointD = PointD()
        var smallestInSol: PointD = PointD()
        var largestInSub: PointD = PointD()
        var largestInSol: PointD = PointD()
    }

    private static func getClosestPointOnSegment(_ offPt: PointD, _ seg1: Point64, _ seg2: Point64) -> PointD {
        if seg1.x == seg2.x && seg1.y == seg2.y {
            return PointD(seg1)
        }
        let dx = Double(seg2.x - seg1.x)
        let dy = Double(seg2.y - seg1.y)
        var q = ((offPt.x - Double(seg1.x)) * dx + (offPt.y - Double(seg1.y)) * dy) / (dx * dx + dy * dy)
        q = max(0, min(1, q))
        return PointD(Double(seg1.x) + q * dx, Double(seg1.y) + q * dy)
    }

    private static func getOffsetQuality(_ subject: Path64, _ solution: Path64, _ delta: Double) -> OffsetQual {
        if subject.isEmpty || solution.isEmpty {
            return OffsetQual()
        }

        let desiredDistSqr = delta * delta
        var smallestSqr = desiredDistSqr
        var largestSqr = desiredDistSqr
        var oq = OffsetQual()

        let subVertexCount = 4
        let subVertexFrac = 1.0 / Double(subVertexCount)
        var solPrev = solution[solution.count - 1]

        for solPt0 in solution {
            for i in 0..<subVertexCount {
                let solPt = PointD(
                    Double(solPrev.x) + Double(solPt0.x - solPrev.x) * subVertexFrac * Double(i),
                    Double(solPrev.y) + Double(solPt0.y - solPrev.y) * subVertexFrac * Double(i)
                )

                var closestToSolPt = PointD(0.0, 0.0)
                var closestDistSqr = Double.infinity
                var subPrev = subject[subject.count - 1]

                for subPt in subject {
                    let closestPt = getClosestPointOnSegment(solPt, subPt, subPrev)
                    subPrev = subPt
                    let sqrDist = distanceSqr(closestPt, solPt)
                    if sqrDist < closestDistSqr {
                        closestDistSqr = sqrDist
                        closestToSolPt = closestPt
                    }
                }

                if closestDistSqr < smallestSqr {
                    smallestSqr = closestDistSqr
                    oq.smallestInSub = closestToSolPt
                    oq.smallestInSol = solPt
                }
                if closestDistSqr > largestSqr {
                    largestSqr = closestDistSqr
                    oq.largestInSub = closestToSolPt
                    oq.largestInSol = solPt
                }
            }
            solPrev = solPt0
        }
        return oq
    }

    // MARK: - Tests

    func testOffsets2() { // see #448 & #456
        let scale: Double = 10
        let delta = 10 * scale
        let arcTol = 0.25 * scale

        var subject: Paths64 = []
        subject.append(Clipper.makePath([Int64(50), 50, 100, 50, 100, 150, 50, 150, 0, 100]))

        subject = Clipper.scalePaths(subject, scale)

        let c = ClipperOffset()
        c.addPaths(subject, .round, .polygon)
        c.arcTolerance = arcTol
        var solution: Paths64 = []
        c.execute(delta, &solution)

        var minDist = delta * 2
        var maxDist: Double = 0

        for subjPt in subject[0] {
            var prevPt = solution[0][solution[0].count - 1]
            for pt in solution[0] {
                let mp = TestOffsets.midPoint(prevPt, pt)
                let d = TestOffsets.distance(mp, subjPt)
                if d < delta * 2 {
                    if d < minDist { minDist = d }
                    if d > maxDist { maxDist = d }
                }
                prevPt = pt
            }
        }

        XCTAssertTrue(minDist + 1 >= delta - arcTol) // +1 for rounding errors
        XCTAssertTrue(solution[0].count <= 21)
    }

    func testOffsets3() { // see #424
        let subjects: Paths64 = [Clipper.makePath([Int64(1525311078), 1352369439, 1526632284, 1366692987, 1519397110, 1367437476, 1520246456,
                1380177674, 1520613458, 1385913385, 1517383844, 1386238444, 1517771817, 1392099983, 1518233190, 1398758441, 1518421934, 1401883197, 1518694564,
                1406612275, 1520267428, 1430289121, 1520770744, 1438027612, 1521148232, 1443438264, 1521441833, 1448964260, 1521683005, 1452518932, 1521819320,
                1454374912, 1527943004, 1454154711, 1527649403, 1448523858, 1535901696, 1447989084, 1535524209, 1442788147, 1538953052, 1442463089, 1541553521,
                1442242888, 1541459149, 1438855987, 1538764308, 1439076188, 1538575565, 1436832236, 1538764308, 1436832236, 1536509870, 1405374956, 1550497874,
                1404347351, 1550214758, 1402428457, 1543818445, 1402868859, 1543734559, 1402124370, 1540672717, 1402344571, 1540473487, 1399995761, 1524996506,
                1400981422, 1524807762, 1398223667, 1530092585, 1397898609, 1531675935, 1397783265, 1531392819, 1394920653, 1529809469, 1395025510, 1529348096,
                1388880855, 1531099218, 1388660654, 1530826588, 1385158410, 1532955197, 1384938209, 1532661596, 1379003269, 1532472852, 1376235028, 1531277476,
                1376350372, 1530050642, 1361806623, 1599487345, 1352704983, 1602758902, 1378489467, 1618990858, 1376350372, 1615058698, 1344085688, 1603230761,
                1345700495, 1598648484, 1346329641, 1598931599, 1348667965, 1596698132, 1348993024, 1595775386, 1342722540])]

        let solution = Clipper.inflatePaths(subjects, -209715, .miter, .polygon)
        XCTAssertTrue(solution[0].count - subjects[0].count <= 1)
    }

    func testOffsets4() { // see #482
        var paths: Paths64 = [Clipper.makePath([Int64(0), 0, 20000, 200, 40000, 0, 40000, 50000, 0, 50000, 0, 0])]
        var solution = Clipper.inflatePaths(paths, -5000, .square, .polygon)
        XCTAssertEqual(5, solution[0].count)

        paths = [Clipper.makePath([Int64(0), 0, 20000, 400, 40000, 0, 40000, 50000, 0, 50000, 0, 0])]
        solution = Clipper.inflatePaths(paths, -5000, .square, .polygon)
        XCTAssertEqual(5, solution[0].count)

        paths = [Clipper.makePath([Int64(0), 0, 20000, 400, 40000, 0, 40000, 50000, 0, 50000, 0, 0])]
        solution = Clipper.inflatePaths(paths, -5000, .round, .polygon, 2, 100)
        XCTAssertTrue(solution[0].count > 5)

        paths = [Clipper.makePath([Int64(0), 0, 20000, 1500, 40000, 0, 40000, 50000, 0, 50000, 0, 0])]
        solution = Clipper.inflatePaths(paths, -5000, .round, .polygon, 2, 100)
        XCTAssertTrue(solution[0].count > 5)
    }

    func testOffsets6() {
        let squarePath = Clipper.makePath([Int64(620), 620, -620, 620, -620, -620, 620, -620])

        let complexPath = Clipper.makePath([Int64(20), -277, 42, -275, 59, -272, 80, -266, 97, -261, 114, -254, 135, -243, 149, -235, 167, -222, 182,
                -211, 197, -197, 212, -181, 223, -167, 234, -150, 244, -133, 253, -116, 260, -99, 267, -78, 272, -61, 275, -40, 278, -18, 276, -39, 272, -61,
                267, -79, 260, -99, 253, -116, 245, -133, 235, -150, 223, -167, 212, -181, 197, -197, 182, -211, 168, -222, 152, -233, 135, -243, 114, -254, 97,
                -261, 80, -267, 59, -272, 42, -275, 20, -278])

        let subjects: Paths64 = [squarePath, complexPath]

        let offset: Double = -50
        let offseter = ClipperOffset()

        offseter.addPaths(subjects, .round, .polygon)
        var solution: Paths64 = []
        offseter.execute(offset, &solution)

        XCTAssertEqual(2, solution.count)

        let area = Clipper.area(solution[1])
        XCTAssertTrue(area < -47500)
    }

    func testOffsets7() { // (#593 & #715)
        var subject: Paths64 = [Clipper.makePath([Int64(0), 0, 100, 0, 100, 100, 0, 100])]

        var solution = Clipper.inflatePaths(subject, -50, .miter, .polygon)
        XCTAssertEqual(0, solution.count)

        subject.append(Clipper.makePath([Int64(40), 60, 60, 60, 60, 40, 40, 40]))
        solution = Clipper.inflatePaths(subject, 10, .miter, .polygon)
        XCTAssertEqual(1, solution.count)

        subject[0].reverse()
        subject[1].reverse()
        solution = Clipper.inflatePaths(subject, 10, .miter, .polygon)
        XCTAssertEqual(1, solution.count)

        subject = [subject[0]]
        solution = Clipper.inflatePaths(subject, -50, .miter, .polygon)
        XCTAssertEqual(0, solution.count)
    }

    func testOffsets8() { // (#724)
        let subject: Paths64 = [Clipper.makePath([Int64(91759700), -49711991, 83886095, -50331657, -872415388, -50331657, -880288993,
                -49711991, -887968725, -47868251, -895265482, -44845834, -901999593, -40719165, -908005244, -35589856, -913134553, -29584205, -917261224,
                -22850094, -920283639, -15553337, -922127379, -7873605, -922747045, 0, -922747045, 1434498600, -922160557, 1442159790, -920414763, 1449642437,
                -917550346, 1456772156, -913634061, 1463382794, -908757180, 1469320287, -903033355, 1474446264, -896595982, 1478641262, -889595081, 1481807519,
                -882193810, 1483871245, -876133965, 1484596521, -876145751, 1484713389, -875781839, 1485061090, -874690056, 1485191762, -874447580, 1485237014,
                -874341490, 1485264094, -874171960, 1485309394, -873612294, 1485570372, -873201878, 1485980788, -872941042, 1486540152, -872893274, 1486720070,
                -872835064, 1487162210, -872834788, 1487185500, -872769052, 1487406000, -872297948, 1487583168, -871995958, 1487180514, -871995958, 1486914040,
                -871908872, 1486364208, -871671308, 1485897962, -871301302, 1485527956, -870835066, 1485290396, -870285226, 1485203310, -868659019, 1485203310,
                -868548443, 1485188472, -868239649, 1484791011, -868239527, 1484783879, -838860950, 1484783879, -830987345, 1484164215, -823307613, 1482320475,
                -816010856, 1479298059, -809276745, 1475171390, -803271094, 1470042081, -752939437, 1419710424, -747810128, 1413704773, -743683459, 1406970662,
                -740661042, 1399673904, -738817302, 1391994173, -738197636, 1384120567, -738197636, 1244148246, -738622462, 1237622613, -739889768, 1231207140,
                -802710260, 995094494, -802599822, 995052810, -802411513, 994586048, -802820028, 993050638, -802879992, 992592029, -802827240, 992175479,
                -802662144, 991759637, -802578556, 991608039, -802511951, 991496499, -801973473, 990661435, -801899365, 990554757, -801842657, 990478841,
                -801770997, 990326371, -801946911, 989917545, -801636397, 989501855, -801546099, 989389271, -800888669, 988625013, -800790843, 988518907,
                -800082405, 987801675, -799977513, 987702547, -799221423, 987035738, -799109961, 986944060, -798309801, 986330832, -798192297, 986247036,
                -797351857, 985690294, -797228867, 985614778, -796352124, 985117160, -796224232, 985050280, -795315342, 984614140, -795183152, 984556216,
                -794246418, 984183618, -794110558, 984134924, -793150414, 983827634, -793011528, 983788398, -792032522, 983547874, -791891266, 983518284,
                -790898035, 983345662, -790755079, 983325856, -789752329, 983221956, -789608349, 983212030, -787698545, 983146276, -787626385, 983145034,
                -536871008, 983145034, -528997403, 982525368, -521317671, 980681627, -514020914, 977659211, -507286803, 973532542, -501281152, 968403233,
                -496151843, 962397582, -492025174, 955663471, -489002757, 948366714, -487159017, 940686982, -486539351, 932813377, -486539351, 667455555,
                -486537885, 667377141, -486460249, 665302309, -486448529, 665145917, -486325921, 664057737, -486302547, 663902657, -486098961, 662826683,
                -486064063, 662673784, -485780639, 661616030, -485734413, 661466168, -485372735, 660432552, -485315439, 660286564, -484877531, 659282866,
                -484809485, 659141568, -484297795, 658173402, -484219379, 658037584, -483636768, 657110363, -483548422, 656980785, -482898150, 656099697,
                -482800368, 655977081, -482086070, 655147053, -481979398, 655032087, -481205068, 654257759, -481090104, 654151087, -480260074, 653436789,
                -480137460, 653339007, -479256372, 652688735, -479126794, 652600389, -478199574, 652017779, -478063753, 651939363, -477095589, 651427672,
                -476954289, 651359626, -475950593, 650921718, -475804605, 650864422, -474770989, 650502744, -474621127, 650456518, -473563373, 650173094,
                -473410475, 650138196, -472334498, 649934610, -472179420, 649911236, -471091240, 649788626, -470934848, 649776906, -468860016, 649699272,
                -468781602, 649697806, -385876037, 649697806, -378002432, 649078140, -370322700, 647234400, -363025943, 644211983, -356291832, 640085314,
                -350286181, 634956006, -345156872, 628950354, -341030203, 622216243, -338007786, 614919486, -336164046, 607239755, -335544380, 599366149,
                -335544380, 571247184, -335426942, 571236100, -335124952, 570833446, -335124952, 569200164, -335037864, 568650330, -334800300, 568184084,
                -334430294, 567814078, -333964058, 567576517, -333414218, 567489431, -331787995, 567489431, -331677419, 567474593, -331368625, 567077133,
                -331368503, 567070001, -142068459, 567070001, -136247086, 566711605, -136220070, 566848475, -135783414, 567098791, -135024220, 567004957,
                -134451560, 566929159, -134217752, 566913755, -133983942, 566929159, -133411282, 567004957, -132665482, 567097135, -132530294, 567091859,
                -132196038, 566715561, -132195672, 566711157, -126367045, 567070001, -33554438, 567070001, -27048611, 566647761, -20651940, 565388127,
                -14471751, 563312231, -8611738, 560454902, 36793963, 534548454, 43059832, 530319881, 48621743, 525200596, 53354240, 519306071, 57150572,
                512769270, 59925109, 505737634, 61615265, 498369779, 62182919, 490831896, 62182919, 474237629, 62300359, 474226543, 62602349, 473823889,
                62602349, 472190590, 62689435, 471640752, 62926995, 471174516, 63297005, 470804506, 63763241, 470566946, 64313081, 470479860, 65939308,
                470479860, 66049884, 470465022, 66358678, 470067562, 66358800, 470060430, 134217752, 470060430, 134217752, 0, 133598086, -7873605, 131754346,
                -15553337, 128731929, -22850094, 124605260, -29584205, 119475951, -35589856, 113470300, -40719165, 106736189, -44845834, 99439432, -47868251,
                91759700, -49711991
        ])]

        let offset: Double = -50329979.277800001
        let arcTol: Double = 5000
        let solution = Clipper.inflatePaths(subject, offset, .round, .polygon, 2, arcTol)
        let oq = TestOffsets.getOffsetQuality(subject[0], solution[0], offset)
        let smallestDist = TestOffsets.distancePD(oq.smallestInSub, oq.smallestInSol)
        let largestDist = TestOffsets.distancePD(oq.largestInSub, oq.largestInSol)
        let roundingTolerance: Double = 1.0
        let absOffset = abs(offset)

        XCTAssertTrue(absOffset - smallestDist - roundingTolerance <= arcTol)
        XCTAssertTrue(largestDist - absOffset - roundingTolerance <= arcTol)
    }

    func testOffsets9() { // (#733)
        // solution orientations should match subject orientations UNLESS
        // reverse_solution is set true in ClipperOffset's constructor

        // start subject's orientation positive ...
        var subject: Paths64 = [Clipper.makePath([Int64(100), 100, 200, 100, 200, 400, 100, 400])]
        var solution = Clipper.inflatePaths(subject, 50, .miter, .polygon)
        XCTAssertEqual(1, solution.count)
        XCTAssertTrue(Clipper.isPositive(solution[0]))

        // reversing subject's orientation should not affect delta direction
        subject[0].reverse()
        solution = Clipper.inflatePaths(subject, 50, .miter, .polygon)
        XCTAssertEqual(1, solution.count)
        XCTAssertTrue(abs(Clipper.area(solution[0])) > abs(Clipper.area(subject[0])))
        XCTAssertFalse(Clipper.isPositive(solution[0]))

        let co = ClipperOffset(miterLimit: 2, arcTolerance: 0, preserveCollinear: false, reverseSolution: true)
        co.addPaths(subject, .miter, .polygon)
        co.execute(50, &solution)
        XCTAssertEqual(1, solution.count)
        XCTAssertTrue(abs(Clipper.area(solution[0])) > abs(Clipper.area(subject[0])))
        XCTAssertTrue(Clipper.isPositive(solution[0]))

        // add a hole (ie has reverse orientation to outer path)
        subject.append(Clipper.makePath([Int64(130), 130, 170, 130, 170, 370, 130, 370]))
        solution = Clipper.inflatePaths(subject, 30, .miter, .polygon)
        XCTAssertEqual(1, solution.count)
        XCTAssertFalse(Clipper.isPositive(solution[0]))

        co.clear() // should still reverse solution orientation
        co.addPaths(subject, .miter, .polygon)
        co.execute(30, &solution)
        XCTAssertEqual(1, solution.count)
        XCTAssertTrue(abs(Clipper.area(solution[0])) > abs(Clipper.area(subject[0])))
        XCTAssertTrue(Clipper.isPositive(solution[0]))

        solution = Clipper.inflatePaths(subject, -15, .miter, .polygon)
        XCTAssertEqual(0, solution.count)
    }

    func testOffsets10() { // see #715
        let subjects: Paths64 = [
            Clipper.makePath([Int64(508685336), -435806096, 509492982, -434729201, 509615525, -434003092, 509615525,
                493372891, 509206033, 494655198, 508129138, 495462844, 507403029, 495585387, -545800889, 495585387, -547083196, 495175895, -547890842,
                494099000, -548013385, 493372891, -548013385, -434003092, -547603893, -435285399, -546526998, -436093045, -545800889, -436215588, 507403029,
                -436215588]),
            Clipper.makePath([Int64(106954765), -62914568, 106795129, -63717113, 106340524, -64397478, 105660159, -64852084, 104857613,
                    -65011720, 104055068, -64852084, 103374703, -64397478, 102920097, -63717113, 102760461, -62914568, 102920097, -62112022, 103374703,
                    -61431657, 104055068, -60977052, 104857613, -60817416, 105660159, -60977052, 106340524, -61431657, 106795129, -62112022])
        ]

        let offseter = ClipperOffset(miterLimit: 2, arcTolerance: 104857.61318750000)
        var solution: Paths64 = []
        offseter.addPaths(subjects, .round, .polygon)
        offseter.execute(-2212495.6382562499, &solution)
        XCTAssertEqual(2, solution.count)
    }

    func testOffsets11() { // see #405
        var subject: PathsD = []
        subject.append(Clipper.makePath([-1.0, -1.0, -1.0, 11.0, 11.0, 11.0, 11.0, -1.0]))
        // offset polygon
        let solution = Clipper.inflatePaths(subject, -50, .miter, .polygon)
        XCTAssertTrue(solution.isEmpty)
    }

    func testOffsets12() { // see #873
        var subject: Paths64 = []
        subject.append(Clipper.makePath([Int64(667680768), -36382704, 737202688, -87034880, 742581888, -86055680, 747603968, -84684800]))
        let solution = Clipper.inflatePaths(subject, -249561088, .miter, .polygon)
        XCTAssertTrue(solution.isEmpty)
    }

    func testOffsets13() { // see #965
        let subject1: Path64 = [Point64(Int64(0), Int64(0)), Point64(Int64(0), Int64(10)), Point64(Int64(10), Int64(0))]
        let delta: Double = 2

        var subjects1: Paths64 = []
        subjects1.append(subject1)
        let solution1 = Clipper.inflatePaths(subjects1, delta, .miter, .polygon)
        let area1 = Int64((abs(Clipper.area(solution1))).rounded())
        XCTAssertEqual(122, area1)

        var subjects2: Paths64 = []
        subjects2.append(subject1)
        subjects2.append([Point64(Int64(0), Int64(20))]) // single-point path should not change output
        let solution2 = Clipper.inflatePaths(subjects2, delta, .miter, .polygon)
        let area2 = Int64((abs(Clipper.area(solution2))).rounded())
        XCTAssertEqual(122, area2)
    }
}
