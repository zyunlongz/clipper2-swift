import Foundation

internal class Group {

    var inPaths: Paths64
    var joinType: JoinType
    var endType: EndType
    var pathsReversed: Bool
    var lowestPathIdx: Int

    convenience init(_ paths: Paths64, _ joinType: JoinType) {
        self.init(paths, joinType, .polygon)
    }

    init(_ paths: Paths64, _ joinType: JoinType, _ endType: EndType) {
        self.joinType = joinType
        self.endType = endType

        let isJoined = (endType == .polygon) || (endType == .joined)
        inPaths = Paths64()
        inPaths.reserveCapacity(paths.count)

        for path in paths {
            inPaths.append(Clipper.stripDuplicates(path, isClosedPath: isJoined))
        }

        if endType == .polygon {
            let lowInfo = Group.getLowestPathInfo(inPaths)
            lowestPathIdx = lowInfo.idx

            // the lowermost path must be an outer path, so if its orientation is negative,
            // then flag that the whole group is 'reversed' (will negate delta etc.)
            // as this is much more efficient than reversing every path.
            pathsReversed = (lowestPathIdx >= 0) && lowInfo.isNegArea
        } else {
            lowestPathIdx = -1
            pathsReversed = false
        }
    }

    // MARK: - Private

    private struct LowestPathInfo {
        var idx: Int = -1
        var isNegArea: Bool = false
    }

    private static func getLowestPathInfo(_ paths: Paths64) -> LowestPathInfo {
        var result = LowestPathInfo()
        var botPt = Point64(Int64.max, Int64.min)
        for i in 0..<paths.count {
            var area = Double.greatestFiniteMagnitude
            for pt in paths[i] {
                if pt.y < botPt.y || (pt.y == botPt.y && pt.x >= botPt.x) {
                    continue
                }
                if area == Double.greatestFiniteMagnitude {
                    area = Clipper.area(paths[i])
                    if area == 0 {
                        break // invalid closed path
                    }
                    result.isNegArea = area < 0
                }
                result.idx = i
                botPt = Point64(pt.x, pt.y)
            }
        }
        return result
    }
}
