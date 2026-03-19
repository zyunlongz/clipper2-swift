import Foundation

/// RectClipLines64 intersects subject open paths (polylines) with the specified
/// rectangular clipping region.
///
/// This function is extremely fast when compared to the Library's general
/// purpose Intersect clipper. Where Intersect has roughly O(n^3) performance,
/// RectClipLines64 has O(n) performance.
public class RectClipLines64: RectClip64 {

    public override init(_ rect: Rect64) {
        super.init(rect)
    }

    public func executeLines(_ paths: Paths64) -> Paths64 {
        execute(paths)
    }

    public override func execute(_ paths: Paths64) -> Paths64 {
        var res: Paths64 = []
        if rect_.isEmpty {
            return res
        }
        for path in paths {
            if path.count < 2 {
                continue
            }
            pathBounds_ = InternalClipper.getBounds(path)
            if !rect_.intersects(pathBounds_) {
                continue
            }
            executeInternal(path)
            for op in results_ {
                let tmp = RectClipLines64.getPathLines(op)
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

    private static func getPathLines(_ op: OutPt2?) -> Path64 {
        guard let op = op, op.next !== op else {
            return []
        }
        var current = op.next!
        var res: Path64 = []
        res.append(current.pt)
        var p2 = current.next!
        while p2 !== current {
            res.append(p2.pt)
            p2 = p2.next
        }
        return res
    }

    override func executeInternal(_ path: Path64) {
        results_.removeAll()
        if path.count < 2 || rect_.isEmpty {
            return
        }
        var loc: Location = .inside
        var i = 1
        let highI = path.count - 1

        var locRes = RectClip64.getLocation(rect_, path[0])
        loc = locRes.location
        if !locRes.outside {
            var prevLocRes = LocationResult(outside: false, location: loc)
            while i <= highI {
                prevLocRes = RectClip64.getLocation(rect_, path[i])
                if prevLocRes.outside {
                    break
                }
                i += 1
            }
            if i > highI {
                for pt in path {
                    add(pt)
                }
                return
            }
            if prevLocRes.location == .inside {
                loc = .inside
            }
            i = 1
        }
        if loc == .inside {
            add(path[0])
        }
        while i <= highI {
            let prev = loc
            getNextLocation(path, &loc, &i, highI)
            if i > highI {
                break
            }
            let prevPt = path[i - 1]
            var ip = Point64()
            let crossRes = RectClip64.getIntersection(rectPath_, path[i], prevPt, loc, &ip)
            if !crossRes.intersects {
                i += 1
                continue
            }
            if loc == .inside {
                add(ip, startingNewPath: true)
            } else if prev != .inside {
                var ip2 = Point64()
                let crossRes2 = RectClip64.getIntersection(rectPath_, prevPt, path[i], prev, &ip2)
                if crossRes2.intersects {
                    add(ip2, startingNewPath: true)
                }
                add(ip, startingNewPath: true)
            } else {
                add(ip)
            }
            i += 1
        }
    }
}
