import Foundation

public enum ClipperError: Error, Equatable, LocalizedError {
    case precisionOutOfRange

    public var errorDescription: String? {
        switch self {
        case .precisionOutOfRange:
            return "Error: Precision is out of range."
        }
    }
}

public enum InternalClipper {

    public static let maxCoord: Double = Double(Int64.max >> 2)
    public static let minCoord: Double = -maxCoord
    static let invalid64: Int64 = Int64.max

    private static let floatingPointTolerance: Double = 1e-12

    public static func checkPrecision(_ precision: Int) throws {
        if precision < -8 || precision > 8 {
            throw ClipperError.precisionOutOfRange
        }
    }

    public static func isAlmostZero(_ value: Double) -> Bool {
        return abs(value) <= floatingPointTolerance
    }

    public static func crossProduct(_ pt1: Point64, _ pt2: Point64, _ pt3: Point64) -> Double {
        return (Double(pt2.x - pt1.x) * Double(pt3.y - pt2.y) - Double(pt2.y - pt1.y) * Double(pt3.x - pt2.x))
    }

    public static func crossProductSign(_ pt1: Point64, _ pt2: Point64, _ pt3: Point64) -> Int {
        let a = pt2.x - pt1.x
        let b = pt3.y - pt2.y
        let c = pt2.y - pt1.y
        let d = pt3.x - pt2.x
        let ab = multiplyUInt64(abs(a), abs(b))
        let cd = multiplyUInt64(abs(c), abs(d))
        let signAB = triSign(a) * triSign(b)
        let signCD = triSign(c) * triSign(d)

        if signAB == signCD {
            let result: Int
            if ab.hi64 == cd.hi64 {
                if ab.lo64 == cd.lo64 {
                    return 0
                }
                result = compareUnsigned(ab.lo64, cd.lo64)
            } else {
                result = compareUnsigned(ab.hi64, cd.hi64)
            }
            return signAB > 0 ? result : -result
        }
        return signAB > signCD ? 1 : -1
    }

    public static func dotProduct(_ pt1: Point64, _ pt2: Point64, _ pt3: Point64) -> Double {
        return (Double(pt2.x - pt1.x) * Double(pt3.x - pt2.x) + Double(pt2.y - pt1.y) * Double(pt3.y - pt2.y))
    }

    public static func crossProduct(_ vec1: PointD, _ vec2: PointD) -> Double {
        return (vec1.y * vec2.x - vec2.y * vec1.x)
    }

    public static func dotProduct(_ vec1: PointD, _ vec2: PointD) -> Double {
        return (vec1.x * vec2.x + vec1.y * vec2.y)
    }

    public static func checkCastInt64(_ val: Double) -> Int64 {
        if val >= maxCoord || val <= minCoord {
            return invalid64
        }
        return Int64(val.rounded())
    }

    @discardableResult
    public static func getLineIntersectPt(_ ln1a: Point64, _ ln1b: Point64, _ ln2a: Point64, _ ln2b: Point64, _ ip: inout Point64) -> Bool {
        let dy1 = Double(ln1b.y - ln1a.y)
        let dx1 = Double(ln1b.x - ln1a.x)
        let dy2 = Double(ln2b.y - ln2a.y)
        let dx2 = Double(ln2b.x - ln2a.x)

        let det = dy1 * dx2 - dy2 * dx1

        if det == 0.0 {
            ip.x = 0
            ip.y = 0
            return false
        }

        let t = (Double(ln1a.x - ln2a.x) * dy2 - Double(ln1a.y - ln2a.y) * dx2) / det

        if t <= 0.0 {
            ip.x = ln1a.x
            ip.y = ln1a.y
        } else if t >= 1.0 {
            ip.x = ln1b.x
            ip.y = ln1b.y
        } else {
            ip.x = Int64(Double(ln1a.x) + t * dx1)
            ip.y = Int64(Double(ln1a.y) + t * dy1)
        }

        return true
    }

    @discardableResult
    public static func getLineIntersectPt(_ ln1a: PointD, _ ln1b: PointD, _ ln2a: PointD, _ ln2b: PointD, _ ip: inout PointD) -> Bool {
        let dy1 = ln1b.y - ln1a.y
        let dx1 = ln1b.x - ln1a.x
        let dy2 = ln2b.y - ln2a.y
        let dx2 = ln2b.x - ln2a.x

        let det = dy1 * dx2 - dy2 * dx1
        if det == 0.0 {
            ip.x = 0
            ip.y = 0
            return false
        }

        let t = ((ln1a.x - ln2a.x) * dy2 - (ln1a.y - ln2a.y) * dx2) / det
        if t <= 0.0 {
            ip.x = ln1a.x
            ip.y = ln1a.y
        } else if t >= 1.0 {
            ip.x = ln1b.x
            ip.y = ln1b.y
        } else {
            ip.x = ln1a.x + t * dx1
            ip.y = ln1a.y + t * dy1
        }
        return true
    }

    public static func getSegmentIntersectPt(_ ln1a: Point64, _ ln1b: Point64, _ ln2a: Point64, _ ln2b: Point64, _ ip: inout Point64) -> Bool {
        return getLineIntersectPt(ln1a, ln1b, ln2a, ln2b, &ip)
    }

    public static func segsIntersect(_ seg1a: Point64, _ seg1b: Point64, _ seg2a: Point64, _ seg2b: Point64, inclusive: Bool = false) -> Bool {
        if inclusive {
            let res1 = crossProduct(seg1a, seg2a, seg2b)
            let res2 = crossProduct(seg1b, seg2a, seg2b)
            if res1 * res2 > 0 { return false }
            let res3 = crossProduct(seg2a, seg1a, seg1b)
            let res4 = crossProduct(seg2b, seg1a, seg1b)
            if res3 * res4 > 0 { return false }
            return (res1 != 0 || res2 != 0 || res3 != 0 || res4 != 0)
        }
        return (crossProduct(seg1a, seg2a, seg2b) * crossProduct(seg1b, seg2a, seg2b) < 0)
            && (crossProduct(seg2a, seg1a, seg1b) * crossProduct(seg2b, seg1a, seg1b) < 0)
    }

    public static func getClosestPtOnSegment(_ offPt: Point64, _ seg1: Point64, _ seg2: Point64) -> Point64 {
        if seg1.x == seg2.x && seg1.y == seg2.y {
            return seg1
        }
        let dx = Double(seg2.x - seg1.x)
        let dy = Double(seg2.y - seg1.y)
        var q = (Double(offPt.x - seg1.x) * dx + Double(offPt.y - seg1.y) * dy) / (dx * dx + dy * dy)
        if q < 0 { q = 0 } else if q > 1 { q = 1 }
        return Point64(Double(seg1.x) + (q * dx).rounded(), Double(seg1.y) + (q * dy).rounded())
    }

    public static func pointInPolygon(_ pt: Point64, _ polygon: Path64) -> PointInPolygonResult {
        let len = polygon.count
        var start = 0
        if len < 3 {
            return .isOutside
        }

        while start < len && polygon[start].y == pt.y {
            start += 1
        }
        if start == len {
            return .isOutside
        }

        var isAbove = polygon[start].y < pt.y
        let startingAbove = isAbove
        var val = 0
        var i = start + 1
        var end = len
        while true {
            if i == end {
                if end == 0 || start == 0 {
                    break
                }
                end = start
                i = 0
            }

            if isAbove {
                while i < end && polygon[i].y < pt.y {
                    i += 1
                }
                if i == end { continue }
            } else {
                while i < end && polygon[i].y > pt.y {
                    i += 1
                }
                if i == end { continue }
            }

            let curr = polygon[i]
            let prev: Point64
            if i > 0 {
                prev = polygon[i - 1]
            } else {
                prev = polygon[len - 1]
            }

            if curr.y == pt.y {
                if curr.x == pt.x || (curr.y == prev.y && ((pt.x < prev.x) != (pt.x < curr.x))) {
                    return .isOn
                }
                i += 1
                if i == start { break }
                continue
            }

            if pt.x < curr.x && pt.x < prev.x {
                // we're only interested in edges crossing on the left
            } else if pt.x > prev.x && pt.x > curr.x {
                val = 1 - val
            } else {
                let cps = crossProductSign(prev, curr, pt)
                if cps == 0 {
                    return .isOn
                }
                if (cps < 0) == isAbove {
                    val = 1 - val
                }
            }
            isAbove = !isAbove
            i += 1
        }

        if isAbove != startingAbove {
            if i == len { i = 0 }
            let cps: Int
            if i == 0 {
                cps = crossProductSign(polygon[len - 1], polygon[0], pt)
            } else {
                cps = crossProductSign(polygon[i - 1], polygon[i], pt)
            }
            if cps == 0 { return .isOn }
            if (cps < 0) == isAbove {
                val = 1 - val
            }
        }

        if val == 0 {
            return .isOutside
        }
        return .isInside
    }

    public static func isCollinear(_ pt1: Point64, _ sharedPt: Point64, _ pt2: Point64) -> Bool {
        let a = sharedPt.x - pt1.x
        let b = pt2.y - sharedPt.y
        let c = sharedPt.y - pt1.y
        let d = pt2.x - sharedPt.x
        return productsAreEqual(a, b, c, d)
    }

    // MARK: - 128-bit arithmetic

    struct UInt128Struct {
        let lo64: Int64
        let hi64: Int64
    }

    static func multiplyUInt64(_ a: Int64, _ b: Int64) -> UInt128Struct {
        let mask32: Int64 = 0x00000000FFFFFFFF
        let aLow = a & mask32
        let aHigh = Int64(bitPattern: UInt64(bitPattern: a) >> 32)
        let bLow = b & mask32
        let bHigh = Int64(bitPattern: UInt64(bitPattern: b) >> 32)

        let x1 = aLow &* bLow
        let x2 = aHigh &* bLow &+ Int64(bitPattern: UInt64(bitPattern: x1) >> 32)
        let x3 = aLow &* bHigh &+ (x2 & mask32)

        let lo64 = ((x3 & mask32) << 32) | (x1 & mask32)
        let hi64 = aHigh &* bHigh &+ Int64(bitPattern: UInt64(bitPattern: x2) >> 32) &+ Int64(bitPattern: UInt64(bitPattern: x3) >> 32)

        return UInt128Struct(lo64: lo64, hi64: hi64)
    }

    private static func productsAreEqual(_ a: Int64, _ b: Int64, _ c: Int64, _ d: Int64) -> Bool {
        let absA = a < 0 ? -a : a
        let absB = b < 0 ? -b : b
        let absC = c < 0 ? -c : c
        let absD = d < 0 ? -d : d

        let p1 = multiplyUInt64(absA, absB)
        let p2 = multiplyUInt64(absC, absD)

        let signAB = triSign(a) * triSign(b)
        let signCD = triSign(c) * triSign(d)

        return p1.lo64 == p2.lo64 && p1.hi64 == p2.hi64 && signAB == signCD
    }

    private static func triSign(_ x: Int64) -> Int {
        return x < 0 ? -1 : (x > 0 ? 1 : 0)
    }

    private static func compareUnsigned(_ a: Int64, _ b: Int64) -> Int {
        let ua = UInt64(bitPattern: a)
        let ub = UInt64(bitPattern: b)
        if ua < ub { return -1 }
        if ua > ub { return 1 }
        return 0
    }

    public static func getBounds(_ path: Path64) -> Rect64 {
        if path.isEmpty {
            return Rect64()
        }
        var result = Rect64.invalid
        for pt in path {
            if pt.x < result.left { result.left = pt.x }
            if pt.x > result.right { result.right = pt.x }
            if pt.y < result.top { result.top = pt.y }
            if pt.y > result.bottom { result.bottom = pt.y }
        }
        return result
    }

    public static func path2ContainsPath1(_ path1: Path64, _ path2: Path64) -> Bool {
        var pip = PointInPolygonResult.isOn
        for pt in path1 {
            switch pointInPolygon(pt, path2) {
            case .isOutside:
                if pip == .isOutside { return false }
                pip = .isOutside
            case .isInside:
                if pip == .isInside { return true }
                pip = .isInside
            default:
                break
            }
        }
        let mp = getBounds(path1).midPoint()
        return pointInPolygon(mp, path2) != .isOutside
    }
}
