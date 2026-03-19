import Foundation

/// RectClip64 intersects subject polygons with the specified rectangular
/// clipping region. Polygons may be simple or complex (self-intersecting).
///
/// This function is extremely fast when compared to the Library's general
/// purpose Intersect clipper. Where Intersect has roughly O(n^3) performance,
/// RectClip64 has O(n) performance.
public class RectClip64 {

    // MARK: - Nested Types

    enum Location: Int, CaseIterable {
        case left = 0
        case top = 1
        case right = 2
        case bottom = 3
        case inside = 4
    }

    struct LocationResult {
        let outside: Bool
        let location: Location
    }

    struct IntersectionResult {
        let intersects: Bool
        let location: Location
    }

    class OutPt2 {
        var next: OutPt2!
        var prev: OutPt2!
        var pt: Point64
        var ownerIdx: Int = 0
        var edge: ReferenceArray<OutPt2>?

        init(_ pt: Point64) {
            self.pt = pt
        }
    }

    /// A reference-type wrapper around an array so that `OutPt2.edge` can
    /// point to the same mutable collection held in `edges_`.
    class ReferenceArray<T> {
        var items: [T?]

        init() {
            items = []
        }

        var count: Int { items.count }
        var isEmpty: Bool { items.isEmpty }

        func append(_ item: T) {
            items.append(item)
        }

        func removeAll() {
            items.removeAll()
        }

        subscript(index: Int) -> T? {
            get { items[index] }
            set { items[index] = newValue }
        }
    }

    // MARK: - Properties

    let rect_: Rect64
    let mp_: Point64
    let rectPath_: Path64
    var pathBounds_: Rect64 = Rect64()
    var results_: [OutPt2?] = []
    var edges_: [ReferenceArray<OutPt2>]
    var currIdx_: Int = -1

    // MARK: - Init

    public init(_ rect: Rect64) {
        rect_ = rect
        mp_ = rect.midPoint()
        rectPath_ = rect.asPath()
        edges_ = (0..<8).map { _ in ReferenceArray<OutPt2>() }
    }

    // MARK: - Add points

    @discardableResult
    func add(_ pt: Point64, startingNewPath: Bool = false) -> OutPt2 {
        let curr = results_.count
        let result: OutPt2
        if curr == 0 || startingNewPath {
            result = OutPt2(pt)
            results_.append(result)
            result.ownerIdx = results_.count - 1
            result.prev = result
            result.next = result
        } else {
            let lastIdx = curr - 1
            let prevOp = results_[lastIdx]!
            if prevOp.pt == pt {
                return prevOp
            }
            result = OutPt2(pt)
            result.ownerIdx = lastIdx
            result.next = prevOp.next
            prevOp.next.prev = result
            prevOp.next = result
            result.prev = prevOp
            results_[lastIdx] = result
        }
        return result
    }

    // MARK: - Static helpers

    private static func path1ContainsPath2(_ p1: Path64, _ p2: Path64) -> Bool {
        var io = 0
        for pt in p2 {
            let pip = InternalClipper.pointInPolygon(pt, p1)
            switch pip {
            case .isInside:
                io -= 1
            case .isOutside:
                io += 1
            default:
                break
            }
            if abs(io) > 1 {
                break
            }
        }
        return io <= 0
    }

    private static func isClockwise(_ prev: Location, _ curr: Location, _ p1: Point64, _ p2: Point64, _ mid: Point64) -> Bool {
        if areOpposites(prev, curr) {
            return InternalClipper.crossProductSign(p1, mid, p2) < 0
        }
        return headingClockwise(prev, curr)
    }

    private static func areOpposites(_ a: Location, _ b: Location) -> Bool {
        return abs(a.rawValue - b.rawValue) == 2
    }

    static func headingClockwise(_ a: Location, _ b: Location) -> Bool {
        return (a.rawValue + 1) % 4 == b.rawValue
    }

    private static func getAdjacentLocation(_ loc: Location, cw: Bool) -> Location {
        let d = cw ? 1 : 3
        return Location(rawValue: (loc.rawValue + d) % 4)!
    }

    private static func unlinkOp(_ op: OutPt2) -> OutPt2? {
        if op.next === op {
            return nil
        }
        op.prev.next = op.next
        op.next.prev = op.prev
        return op.next
    }

    private static func unlinkOpBack(_ op: OutPt2) -> OutPt2? {
        if op.next === op {
            return nil
        }
        op.prev.next = op.next
        op.next.prev = op.prev
        return op.prev
    }

    private static func getEdgesForPt(_ pt: Point64, _ r: Rect64) -> Int {
        var res = 0
        if pt.x == r.left {
            res = 1
        } else if pt.x == r.right {
            res = 4
        }
        if pt.y == r.top {
            res += 2
        } else if pt.y == r.bottom {
            res += 8
        }
        return res
    }

    private static func isHeadingClockwise(_ p1: Point64, _ p2: Point64, _ idx: Int) -> Bool {
        switch idx {
        case 0: return p2.y < p1.y
        case 1: return p2.x > p1.x
        case 2: return p2.y > p1.y
        default: return p2.x < p1.x
        }
    }

    private static func hasHorzOverlap(_ l1: Point64, _ r1: Point64, _ l2: Point64, _ r2: Point64) -> Bool {
        return l1.x < r2.x && r1.x > l2.x
    }

    private static func hasVertOverlap(_ t1: Point64, _ b1: Point64, _ t2: Point64, _ b2: Point64) -> Bool {
        return t1.y < b2.y && b1.y > t2.y
    }

    private static func addToEdge(_ edge: ReferenceArray<OutPt2>, _ op: OutPt2) {
        if op.edge != nil {
            return
        }
        op.edge = edge
        edge.append(op)
    }

    private static func uncoupleEdge(_ op: OutPt2) {
        guard let e = op.edge else { return }
        for i in 0..<e.count {
            if e[i] === op {
                e[i] = nil
                break
            }
        }
        op.edge = nil
    }

    private static func setNewOwner(_ op: OutPt2, _ idx: Int) {
        op.ownerIdx = idx
        var o = op.next!
        while o !== op {
            o.ownerIdx = idx
            o = o.next
        }
    }

    // MARK: - Corner helpers

    private func addCorner(_ prev: Location, _ curr: Location) {
        add(RectClip64.headingClockwise(prev, curr) ? rectPath_[prev.rawValue] : rectPath_[curr.rawValue])
    }

    @discardableResult
    private func addCorner(_ loc: Location, _ cw: Bool) -> Location {
        if cw {
            add(rectPath_[loc.rawValue])
            return RectClip64.getAdjacentLocation(loc, cw: true)
        } else {
            let nextLoc = RectClip64.getAdjacentLocation(loc, cw: false)
            add(rectPath_[nextLoc.rawValue])
            return nextLoc
        }
    }

    // MARK: - Location / Intersection

    static func getLocation(_ r: Rect64, _ pt: Point64) -> LocationResult {
        if pt.x == r.left && pt.y >= r.top && pt.y <= r.bottom {
            return LocationResult(outside: false, location: .left)
        }
        if pt.x == r.right && pt.y >= r.top && pt.y <= r.bottom {
            return LocationResult(outside: false, location: .right)
        }
        if pt.y == r.top && pt.x >= r.left && pt.x <= r.right {
            return LocationResult(outside: false, location: .top)
        }
        if pt.y == r.bottom && pt.x >= r.left && pt.x <= r.right {
            return LocationResult(outside: false, location: .bottom)
        }
        let loc: Location
        if pt.x < r.left {
            loc = .left
        } else if pt.x > r.right {
            loc = .right
        } else if pt.y < r.top {
            loc = .top
        } else if pt.y > r.bottom {
            loc = .bottom
        } else {
            loc = .inside
        }
        return LocationResult(outside: true, location: loc)
    }

    private static func isHorizontal(_ a: Point64, _ b: Point64) -> Bool {
        return a.y == b.y
    }

    private static func getSegmentIntersection(_ p1: Point64, _ p2: Point64, _ p3: Point64, _ p4: Point64, _ ip: inout Point64) -> Bool {
        let r1 = InternalClipper.crossProductSign(p1, p3, p4)
        let r2 = InternalClipper.crossProductSign(p2, p3, p4)
        if r1 == 0 {
            ip = p1
            if r2 == 0 {
                return false
            }
            if p1 == p3 || p1 == p4 {
                return true
            }
            if isHorizontal(p3, p4) {
                return (p1.x > p3.x) == (p1.x < p4.x)
            }
            return (p1.y > p3.y) == (p1.y < p4.y)
        }
        if r2 == 0 {
            ip = p2
            if p2 == p3 || p2 == p4 {
                return true
            }
            if isHorizontal(p3, p4) {
                return (p2.x > p3.x) == (p2.x < p4.x)
            }
            return (p2.y > p3.y) == (p2.y < p4.y)
        }
        if (r1 > 0) == (r2 > 0) {
            ip = Point64(Int64(0), Int64(0))
            return false
        }
        let r3 = InternalClipper.crossProductSign(p3, p1, p2)
        let r4 = InternalClipper.crossProductSign(p4, p1, p2)
        if r3 == 0 {
            ip = p3
            if p3 == p1 || p3 == p2 {
                return true
            }
            if isHorizontal(p1, p2) {
                return (p3.x > p1.x) == (p3.x < p2.x)
            }
            return (p3.y > p1.y) == (p3.y < p2.y)
        }
        if r4 == 0 {
            ip = p4
            if p4 == p1 || p4 == p2 {
                return true
            }
            if isHorizontal(p1, p2) {
                return (p4.x > p1.x) == (p4.x < p2.x)
            }
            return (p4.y > p1.y) == (p4.y < p2.y)
        }
        if (r3 > 0) == (r4 > 0) {
            ip = Point64(Int64(0), Int64(0))
            return false
        }
        return InternalClipper.getLineIntersectPt(p1, p2, p3, p4, &ip)
    }

    static func getIntersection(_ rectPath: Path64, _ p: Point64, _ p2: Point64, _ loc: Location, _ ip: inout Point64) -> IntersectionResult {
        ip = Point64(Int64(0), Int64(0))
        switch loc {
        case .left:
            if getSegmentIntersection(p, p2, rectPath[0], rectPath[3], &ip) {
                return IntersectionResult(intersects: true, location: loc)
            }
            if p.y < rectPath[0].y && getSegmentIntersection(p, p2, rectPath[0], rectPath[1], &ip) {
                return IntersectionResult(intersects: true, location: .top)
            }
            if !getSegmentIntersection(p, p2, rectPath[2], rectPath[3], &ip) {
                return IntersectionResult(intersects: false, location: loc)
            }
            return IntersectionResult(intersects: true, location: .bottom)

        case .right:
            if getSegmentIntersection(p, p2, rectPath[1], rectPath[2], &ip) {
                return IntersectionResult(intersects: true, location: loc)
            }
            if p.y < rectPath[0].y && getSegmentIntersection(p, p2, rectPath[0], rectPath[1], &ip) {
                return IntersectionResult(intersects: true, location: .top)
            }
            if !getSegmentIntersection(p, p2, rectPath[2], rectPath[3], &ip) {
                return IntersectionResult(intersects: false, location: loc)
            }
            return IntersectionResult(intersects: true, location: .bottom)

        case .top:
            if getSegmentIntersection(p, p2, rectPath[0], rectPath[1], &ip) {
                return IntersectionResult(intersects: true, location: loc)
            }
            if p.x < rectPath[0].x && getSegmentIntersection(p, p2, rectPath[0], rectPath[3], &ip) {
                return IntersectionResult(intersects: true, location: .left)
            }
            if p.x <= rectPath[1].x || !getSegmentIntersection(p, p2, rectPath[1], rectPath[2], &ip) {
                return IntersectionResult(intersects: false, location: loc)
            }
            return IntersectionResult(intersects: true, location: .right)

        case .bottom:
            if getSegmentIntersection(p, p2, rectPath[2], rectPath[3], &ip) {
                return IntersectionResult(intersects: true, location: loc)
            }
            if p.x < rectPath[3].x && getSegmentIntersection(p, p2, rectPath[0], rectPath[3], &ip) {
                return IntersectionResult(intersects: true, location: .left)
            }
            if p.x <= rectPath[2].x || !getSegmentIntersection(p, p2, rectPath[1], rectPath[2], &ip) {
                return IntersectionResult(intersects: false, location: loc)
            }
            return IntersectionResult(intersects: true, location: .right)

        case .inside:
            if getSegmentIntersection(p, p2, rectPath[0], rectPath[3], &ip) {
                return IntersectionResult(intersects: true, location: .left)
            }
            if getSegmentIntersection(p, p2, rectPath[0], rectPath[1], &ip) {
                return IntersectionResult(intersects: true, location: .top)
            }
            if getSegmentIntersection(p, p2, rectPath[1], rectPath[2], &ip) {
                return IntersectionResult(intersects: true, location: .right)
            }
            if !getSegmentIntersection(p, p2, rectPath[2], rectPath[3], &ip) {
                return IntersectionResult(intersects: false, location: loc)
            }
            return IntersectionResult(intersects: true, location: .bottom)
        }
    }

    func getNextLocation(_ path: Path64, _ loc: inout Location, _ i: inout Int, _ highI: Int) {
        switch loc {
        case .left:
            while i <= highI && path[i].x <= rect_.left {
                i += 1
            }
            if i <= highI {
                if path[i].x >= rect_.right {
                    loc = .right
                } else if path[i].y <= rect_.top {
                    loc = .top
                } else if path[i].y >= rect_.bottom {
                    loc = .bottom
                } else {
                    loc = .inside
                }
            }

        case .top:
            while i <= highI && path[i].y <= rect_.top {
                i += 1
            }
            if i <= highI {
                if path[i].y >= rect_.bottom {
                    loc = .bottom
                } else if path[i].x <= rect_.left {
                    loc = .left
                } else if path[i].x >= rect_.right {
                    loc = .right
                } else {
                    loc = .inside
                }
            }

        case .right:
            while i <= highI && path[i].x >= rect_.right {
                i += 1
            }
            if i <= highI {
                if path[i].x <= rect_.left {
                    loc = .left
                } else if path[i].y <= rect_.top {
                    loc = .top
                } else if path[i].y >= rect_.bottom {
                    loc = .bottom
                } else {
                    loc = .inside
                }
            }

        case .bottom:
            while i <= highI && path[i].y >= rect_.bottom {
                i += 1
            }
            if i <= highI {
                if path[i].y <= rect_.top {
                    loc = .top
                } else if path[i].x <= rect_.left {
                    loc = .left
                } else if path[i].x >= rect_.right {
                    loc = .right
                } else {
                    loc = .inside
                }
            }

        case .inside:
            while i <= highI {
                let pt = path[i]
                if pt.x < rect_.left {
                    loc = .left
                    break
                } else if pt.x > rect_.right {
                    loc = .right
                    break
                } else if pt.y > rect_.bottom {
                    loc = .bottom
                    break
                } else if pt.y < rect_.top {
                    loc = .top
                    break
                } else {
                    add(pt)
                    i += 1
                    continue
                }
            }
        }
    }

    private static func startLocsAreClockwise(_ locs: [Location]) -> Bool {
        var res = 0
        for i in 1..<locs.count {
            let d = locs[i].rawValue - locs[i - 1].rawValue
            switch d {
            case -1: res -= 1
            case 1: res += 1
            case -3: res += 1
            case 3: res -= 1
            default: break
            }
        }
        return res > 0
    }

    // MARK: - Execute Internal

    func executeInternal(_ path: Path64) {
        if path.count < 3 || rect_.isEmpty {
            return
        }

        var startLocs: [Location] = []
        var firstCross: Location = .inside
        var crossingLoc: Location = .inside
        var prev: Location = .inside

        let highI = path.count - 1
        var loc: Location = .inside

        // find the location of the last point
        var locRes = RectClip64.getLocation(rect_, path[highI])
        loc = locRes.location
        if !locRes.outside {
            prev = loc
            var j = highI - 1
            var prevLocRes = LocationResult(outside: false, location: prev)
            while j >= 0 {
                prevLocRes = RectClip64.getLocation(rect_, path[j])
                if prevLocRes.outside {
                    break
                }
                j -= 1
            }
            if j < 0 {
                // never touched the rect at all
                for pt in path {
                    add(pt)
                }
                return
            }
            prev = prevLocRes.location
            if prev == .inside {
                loc = .inside
            }
        }

        // capture the very first loc for the tail-end test
        let startingLoc = loc

        // main loop
        var i = 0
        while i <= highI {
            prev = loc
            let prevCrossLoc = crossingLoc

            // advance i to the next index where the rect-location changes
            getNextLocation(path, &loc, &i, highI)
            if i > highI {
                break
            }

            // current segment runs from path[i-1] to path[i]
            let prevPt = (i == 0) ? path[highI] : path[i - 1]
            crossingLoc = loc

            // see if that segment hits the rectangle boundary
            var ip = Point64()
            let crossRes = RectClip64.getIntersection(rectPath_, path[i], prevPt, crossingLoc, &ip)
            if !crossRes.intersects {
                // still entirely outside
                crossingLoc = crossRes.location
                if prevCrossLoc == .inside {
                    let cw = RectClip64.isClockwise(prev, loc, prevPt, path[i], mp_)
                    var p = prev
                    repeat {
                        startLocs.append(p)
                        p = RectClip64.getAdjacentLocation(p, cw: cw)
                    } while p != loc
                    crossingLoc = prevCrossLoc
                } else if prev != .inside && prev != loc {
                    let cw = RectClip64.isClockwise(prev, loc, prevPt, path[i], mp_)
                    var p = prev
                    repeat {
                        p = addCorner(p, cw)
                    } while p != loc
                }

                i += 1
                continue
            }

            // we did intersect
            crossingLoc = crossRes.location

            if loc == .inside {
                // entering rectangle
                if firstCross == .inside {
                    firstCross = crossingLoc
                    startLocs.append(prev)
                } else if prev != crossingLoc {
                    let cw = RectClip64.isClockwise(prev, crossingLoc, prevPt, path[i], mp_)
                    var p = prev
                    repeat {
                        p = addCorner(p, cw)
                    } while p != crossingLoc
                }
            } else if prev != .inside {
                // passing all the way through
                var ip2 = Point64()
                let loc2Res = RectClip64.getIntersection(rectPath_, prevPt, path[i], prev, &ip2)
                if !loc2Res.intersects {
                    i += 1
                    continue
                }
                let newLoc = loc2Res.location

                if prevCrossLoc != .inside && prevCrossLoc != newLoc {
                    addCorner(prevCrossLoc, newLoc)
                }
                if firstCross == .inside {
                    firstCross = newLoc
                    startLocs.append(prev)
                }
                loc = crossingLoc
                add(ip2)

                if ip == ip2 {
                    let onRectLoc = RectClip64.getLocation(rect_, path[i]).location
                    crossingLoc = addCorner(crossingLoc, RectClip64.headingClockwise(crossingLoc, onRectLoc))

                    i += 1
                    continue
                }
            } else {
                // exiting rectangle
                loc = crossingLoc
                if firstCross == .inside {
                    firstCross = crossingLoc
                }
            }

            // add the intersection point
            add(ip)
        }

        // tail-end logic
        if firstCross == .inside {
            // never intersected
            if startingLoc == .inside || !pathBounds_.contains(rect_) || !RectClip64.path1ContainsPath2(path, rectPath_) {
                return
            }

            let cw = RectClip64.startLocsAreClockwise(startLocs)
            for j in 0..<4 {
                let k = cw ? j : 3 - j
                add(rectPath_[k])
                RectClip64.addToEdge(edges_[k * 2], results_[0]!)
            }
        } else if loc != .inside && (loc != firstCross || startLocs.count > 2) {
            if !startLocs.isEmpty {
                var p = loc
                for loc2 in startLocs {
                    if p == loc2 {
                        continue
                    }
                    let c = RectClip64.headingClockwise(p, loc2)
                    p = addCorner(p, c)
                }
                loc = p
            }
            if loc != firstCross {
                loc = addCorner(loc, RectClip64.headingClockwise(loc, firstCross))
            }
        }
    }

    // MARK: - Execute

    public func execute(_ paths: Paths64) -> Paths64 {
        var res: Paths64 = []
        if rect_.isEmpty {
            return res
        }
        for path in paths {
            if path.count < 3 {
                continue
            }
            pathBounds_ = InternalClipper.getBounds(path)
            if !rect_.intersects(pathBounds_) {
                continue
            }
            if rect_.contains(pathBounds_) {
                res.append(path)
                continue
            }
            executeInternal(path)
            checkEdges()
            for i in 0..<4 {
                tidyEdgePair(i, edges_[i * 2], edges_[i * 2 + 1])
            }
            for op in results_ {
                let tmp = RectClip64.getPath(op)
                if !tmp.isEmpty {
                    res.append(tmp)
                }
            }
            results_.removeAll()
            for i in 0..<8 {
                edges_[i].removeAll()
            }
        }
        return res
    }

    // MARK: - Check / Tidy Edges

    private func checkEdges() {
        for i in 0..<results_.count {
            guard var op = results_[i] else { continue }
            var o2: OutPt2? = op
            repeat {
                guard let current = o2 else { break }
                if InternalClipper.isCollinear(current.prev.pt, current.pt, current.next.pt) {
                    if current === op {
                        o2 = RectClip64.unlinkOpBack(current)
                        if o2 == nil { break }
                        op = o2!.prev
                    } else {
                        o2 = RectClip64.unlinkOpBack(current)
                        if o2 == nil { break }
                    }
                } else {
                    o2 = current.next
                }
            } while o2 !== op
            if o2 == nil {
                results_[i] = nil
                continue
            }
            results_[i] = o2
            var e1 = RectClip64.getEdgesForPt(op.prev.pt, rect_)
            var current2 = op
            repeat {
                let e2 = RectClip64.getEdgesForPt(current2.pt, rect_)
                if e2 != 0 && current2.edge == nil {
                    let comb = e1 & e2
                    for j in 0..<4 {
                        if (comb & (1 << j)) == 0 {
                            continue
                        }
                        if RectClip64.isHeadingClockwise(current2.prev.pt, current2.pt, j) {
                            RectClip64.addToEdge(edges_[j * 2], current2)
                        } else {
                            RectClip64.addToEdge(edges_[j * 2 + 1], current2)
                        }
                    }
                }
                e1 = e2
                current2 = current2.next
            } while current2 !== op
        }
    }

    private func tidyEdgePair(_ idx: Int, _ cw: ReferenceArray<OutPt2>, _ ccw: ReferenceArray<OutPt2>) {
        if ccw.isEmpty {
            return
        }
        let isH = (idx == 1 || idx == 3)
        let cwL = (idx == 1 || idx == 2)
        var i = 0, j = 0
        while i < cw.count {
            guard let p1Check = cw[i], p1Check.next !== p1Check.prev else {
                cw[i] = nil
                j = 0
                i += 1
                continue
            }
            while j < ccw.count && (ccw[j] == nil || ccw[j]!.next === ccw[j]!.prev) {
                j += 1
            }
            if j == ccw.count {
                i += 1
                j = 0
                continue
            }
            let p1: OutPt2
            let p1a: OutPt2
            let p2: OutPt2
            let p2a: OutPt2
            if cwL {
                p1 = cw[i]!.prev
                p1a = cw[i]!
                p2 = ccw[j]!
                p2a = ccw[j]!.prev
            } else {
                p1 = cw[i]!
                p1a = cw[i]!.prev
                p2 = ccw[j]!.prev
                p2a = ccw[j]!
            }
            if (isH && !RectClip64.hasHorzOverlap(p1.pt, p1a.pt, p2.pt, p2a.pt))
                || (!isH && !RectClip64.hasVertOverlap(p1.pt, p1a.pt, p2.pt, p2a.pt)) {
                j += 1
                continue
            }
            let rejoin = p1a.ownerIdx != p2.ownerIdx
            if rejoin {
                results_[p2.ownerIdx] = nil
                RectClip64.setNewOwner(p2, p1a.ownerIdx)
            }
            if cwL {
                p1.next = p2
                p2.prev = p1
                p1a.prev = p2a
                p2a.next = p1a
            } else {
                p1.prev = p2
                p2.next = p1
                p1a.next = p2a
                p2a.prev = p1a
            }
            if !rejoin {
                let ni = results_.count
                results_.append(p1a)
                RectClip64.setNewOwner(p1a, ni)
            }
            let o: OutPt2
            let o2: OutPt2
            if cwL {
                o = p2
                o2 = p1a
            } else {
                o = p1
                o2 = p2a
            }
            results_[o.ownerIdx] = o
            results_[o2.ownerIdx] = o2
            let oL: Bool
            let o2L: Bool
            if isH {
                oL = o.pt.x > o.prev.pt.x
                o2L = o2.pt.x > o2.prev.pt.x
            } else {
                oL = o.pt.y > o.prev.pt.y
                o2L = o2.pt.y > o2.prev.pt.y
            }
            if o.next === o.prev || o.pt == o.prev.pt {
                if o2L == cwL {
                    cw[i] = o2
                    ccw[j] = nil
                } else {
                    ccw[j] = o2
                    cw[i] = nil
                }
            } else if o2.next === o2.prev || o2.pt == o2.prev.pt {
                if oL == cwL {
                    cw[i] = o
                    ccw[j] = nil
                } else {
                    ccw[j] = o
                    cw[i] = nil
                }
            } else if oL == o2L {
                if oL == cwL {
                    cw[i] = o
                    RectClip64.uncoupleEdge(o2)
                    RectClip64.addToEdge(cw, o2)
                    ccw[j] = nil
                } else {
                    cw[i] = nil
                    ccw[j] = o2
                    RectClip64.uncoupleEdge(o)
                    RectClip64.addToEdge(ccw, o)
                    j = 0
                }
            } else {
                if oL == cwL {
                    cw[i] = o
                } else {
                    ccw[j] = o
                }
                if o2L == cwL {
                    cw[i] = o2
                } else {
                    ccw[j] = o2
                }
            }
        }
    }

    // MARK: - Get Path

    static func getPath(_ op: OutPt2?) -> Path64 {
        guard let op = op, op.prev !== op.next else {
            return []
        }
        var start: OutPt2? = op.next
        var opMut = op
        while start != nil && start !== opMut {
            if InternalClipper.isCollinear(start!.prev.pt, start!.pt, start!.next.pt) {
                opMut = start!.prev
                start = unlinkOp(start!)
            } else {
                start = start!.next
            }
        }
        guard start != nil else {
            return []
        }
        var res: Path64 = []
        res.append(opMut.pt)
        var p2 = opMut.next!
        while p2 !== opMut {
            res.append(p2.pt)
            p2 = p2.next
        }
        return res
    }
}
