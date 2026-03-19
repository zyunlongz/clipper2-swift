import Foundation

/// Manages the process of offsetting (inflating/deflating) both open and closed
/// paths using different join types and end types.
///
/// Geometric offsetting refers to the process of creating parallel curves that
/// are offset a specified distance from their primary curves.
///
/// Library users will rarely need to access this class directly since it's
/// generally easier to use the `Clipper.inflatePaths` function for polygon
/// offsetting.
///
/// **Notes:**
/// - When offsetting closed paths (polygons), a positive offset delta specifies
///   how much outer polygon contours will expand and inner "hole" contours will
///   contract. The converse occurs with negative deltas.
/// - You cannot offset open paths (polylines) with negative deltas because it's
///   not possible to contract/shrink open paths.
/// - Offsetting should not be performed on intersecting closed paths.
///   Intersections must be removed before offsetting via a Union clipping operation.
/// - When offsetting closed paths (polygons), the winding direction of paths in
///   the solution will match that of the paths prior to offsetting.
public class ClipperOffset {

    private static let tolerance: Double = 1.0e-12
    private static let arcConst: Double = 0.002

    private var groupList: [Group] = []
    private var pathOut: Path64 = []
    private var normals: PathD = []
    private var solution: Paths64 = []
    private var solutionTree: PolyTree64?
    private var groupDelta: Double = 0  // *0.5 for open paths; *-1.0 for negative areas
    private var delta: Double = 0
    private var mitLimSqr: Double = 0
    private var stepsPerRad: Double = 0
    private var stepSin: Double = 0
    private var stepCos: Double = 0
    private var _joinType: JoinType = .square
    private var _endType: EndType = .polygon

    /// Maximum distance in multiples of groupDelta that vertices can be offset
    /// from their original positions before squaring is applied. Default is 2.
    public var miterLimit: Double = 2.0

    /// Maximum acceptable imperfection for rounded curves during offsetting.
    /// Default is 0.0 (automatic scaling).
    public var arcTolerance: Double = 0.0

    /// Whether to merge groups during offsetting.
    public var mergeGroups: Bool = true

    /// When true, collinear vertices are retained in closed path solutions.
    public var preserveCollinear: Bool = false

    /// When true, reverses the solution's orientation.
    public var reverseSolution: Bool = false

    /// Optional callback for calculating a variable delta during offsetting.
    public var deltaCallback: DeltaCallback64?

    /// Creates a ClipperOffset object with default parameters.
    public convenience init() {
        self.init(miterLimit: 2.0)
    }

    /// Creates a ClipperOffset object with the supplied parameters.
    ///
    /// - Parameters:
    ///   - miterLimit: Maximum distance in multiples of groupDelta that vertices
    ///     can be offset from their original positions before squaring is applied.
    ///     The default and minimum value is 2.
    ///   - arcTolerance: Maximum acceptable imperfection for rounded curves.
    ///     Default is 0.0 (automatic scaling).
    ///   - preserveCollinear: Whether to retain collinear vertices. Default is false.
    ///   - reverseSolution: Whether to reverse the solution's orientation. Default is false.
    public init(miterLimit: Double = 2.0, arcTolerance: Double = 0.0,
                preserveCollinear: Bool = false, reverseSolution: Bool = false) {
        self.miterLimit = miterLimit
        self.arcTolerance = arcTolerance
        self.mergeGroups = true
        self.preserveCollinear = preserveCollinear
        self.reverseSolution = reverseSolution
    }

    /// Removes all paths from the internal group list.
    public func clear() {
        groupList.removeAll()
    }

    /// Adds a single path with the specified join and end types.
    public func addPath(_ path: Path64, _ joinType: JoinType, _ endType: EndType) {
        if path.isEmpty { return }
        addPaths([path], joinType, endType)
    }

    /// Adds multiple paths with the specified join and end types.
    public func addPaths(_ paths: Paths64, _ joinType: JoinType, _ endType: EndType) {
        if paths.isEmpty { return }
        groupList.append(Group(paths, joinType, endType))
    }

    /// Executes the offset operation with the given delta and stores results in `solution`.
    public func execute(_ delta: Double, _ solution: inout Paths64) {
        solution.removeAll()
        solutionTree = nil
        self.solution = solution
        executeInternal(delta)
        solution = self.solution
    }

    /// Executes the offset operation using a delta callback.
    public func execute(_ deltaCallback: @escaping DeltaCallback64, _ solution: inout Paths64) {
        self.deltaCallback = deltaCallback
        execute(1.0, &solution)
    }

    /// Executes the offset operation with the given delta and stores results in `solutionTree`.
    public func execute(_ delta: Double, _ solutionTree: PolyTree64) {
        solutionTree.clear()
        self.solutionTree = solutionTree
        solution.removeAll()
        executeInternal(delta)
    }

    // MARK: - Private Implementation

    private func calcSolutionCapacity() -> Int {
        var result = 0
        for g in groupList {
            result += (g.endType == .joined) ? g.inPaths.count * 2 : g.inPaths.count
        }
        return result
    }

    private func executeInternal(_ delta: Double) {
        if groupList.isEmpty { return }
        solution.reserveCapacity(calcSolutionCapacity())

        // make sure the offset delta is significant
        if abs(delta) < 0.5 {
            for group in groupList {
                for path in group.inPaths {
                    solution.append(path)
                }
            }
            return
        }

        self.delta = delta
        self.mitLimSqr = (miterLimit <= 1 ? 2.0 : 2.0 / Clipper.sqr(miterLimit))

        for group in groupList {
            doGroupOffset(group)
        }
        if groupList.isEmpty { return }

        let pathsReversed = checkPathsReversed()
        let fillRule: FillRule = pathsReversed ? .negative : .positive

        // clean up self-intersections ...
        let c = Clipper64()
        c.preserveCollinear = preserveCollinear
        // the solution should retain the orientation of the input
        c.reverseSolution = reverseSolution != pathsReversed
        c.addSubjects(solution)
        if let solutionTree = solutionTree {
            c.execute(.union, fillRule, solutionTree)
        } else {
            c.execute(.union, fillRule, &solution)
        }
    }

    private func checkPathsReversed() -> Bool {
        for g in groupList {
            if g.endType == .polygon {
                return g.pathsReversed
            }
        }
        return false
    }

    // MARK: - Geometry Helpers

    private static func getUnitNormal(_ pt1: Point64, _ pt2: Point64) -> PointD {
        var dx = Double(pt2.x - pt1.x)
        var dy = Double(pt2.y - pt1.y)
        if dx == 0 && dy == 0 {
            return PointD()
        }
        let f = 1.0 / sqrt(dx * dx + dy * dy)
        dx *= f
        dy *= f
        return PointD(dy, -dx)
    }

    private static func translatePoint(_ pt: PointD, _ dx: Double, _ dy: Double) -> PointD {
        return PointD(pt.x + dx, pt.y + dy)
    }

    private static func reflectPoint(_ pt: PointD, _ pivot: PointD) -> PointD {
        return PointD(pivot.x + (pivot.x - pt.x), pivot.y + (pivot.y - pt.y))
    }

    private static func almostZero(_ value: Double, _ epsilon: Double = 0.001) -> Bool {
        return abs(value) < epsilon
    }

    private static func hypotenuse(_ x: Double, _ y: Double) -> Double {
        return sqrt(x * x + y * y)
    }

    private static func normalizeVector(_ vec: PointD) -> PointD {
        let h = hypotenuse(vec.x, vec.y)
        if almostZero(h) {
            return PointD(0.0, 0.0)
        }
        let inverseHypot = 1 / h
        return PointD(vec.x * inverseHypot, vec.y * inverseHypot)
    }

    private static func getAvgUnitVector(_ vec1: PointD, _ vec2: PointD) -> PointD {
        return normalizeVector(PointD(vec1.x + vec2.x, vec1.y + vec2.y))
    }

    private func getPerpendic(_ pt: Point64, _ norm: PointD) -> Point64 {
        return Point64(Double(pt.x) + norm.x * groupDelta, Double(pt.y) + norm.y * groupDelta)
    }

    private func getPerpendicD(_ pt: Point64, _ norm: PointD) -> PointD {
        return PointD(Double(pt.x) + norm.x * groupDelta, Double(pt.y) + norm.y * groupDelta)
    }

    // MARK: - Join Operations

    private func doBevel(_ path: Path64, _ j: Int, _ k: Int) {
        let pt1: Point64
        let pt2: Point64
        if j == k {
            let absDelta = abs(groupDelta)
            pt1 = Point64(Double(path[j].x) - absDelta * normals[j].x,
                          Double(path[j].y) - absDelta * normals[j].y)
            pt2 = Point64(Double(path[j].x) + absDelta * normals[j].x,
                          Double(path[j].y) + absDelta * normals[j].y)
        } else {
            pt1 = Point64(Double(path[j].x) + groupDelta * normals[k].x,
                          Double(path[j].y) + groupDelta * normals[k].y)
            pt2 = Point64(Double(path[j].x) + groupDelta * normals[j].x,
                          Double(path[j].y) + groupDelta * normals[j].y)
        }
        pathOut.append(pt1)
        pathOut.append(pt2)
    }

    private func doSquare(_ path: Path64, _ j: Int, _ k: Int) {
        let vec: PointD
        if j == k {
            vec = PointD(normals[j].y, -normals[j].x)
        } else {
            vec = ClipperOffset.getAvgUnitVector(
                PointD(-normals[k].y, normals[k].x),
                PointD(normals[j].y, -normals[j].x))
        }
        let absDelta = abs(groupDelta)
        // now offset the original vertex delta units along unit vector
        var ptQ = PointD(path[j])
        ptQ = ClipperOffset.translatePoint(ptQ, absDelta * vec.x, absDelta * vec.y)

        // get perpendicular vertices
        let pt1 = ClipperOffset.translatePoint(ptQ, groupDelta * vec.y, groupDelta * -vec.x)
        let pt2 = ClipperOffset.translatePoint(ptQ, groupDelta * -vec.y, groupDelta * vec.x)
        // get 2 vertices along one edge offset
        let pt3 = getPerpendicD(path[k], normals[k])

        if j == k {
            let pt4 = PointD(pt3.x + vec.x * groupDelta, pt3.y + vec.y * groupDelta)
            var pt = PointD()
            InternalClipper.getLineIntersectPt(pt1, pt2, pt3, pt4, &pt)
            // get the second intersect point through reflection
            pathOut.append(Point64(ClipperOffset.reflectPoint(pt, ptQ)))
            pathOut.append(Point64(pt))
        } else {
            let pt4 = getPerpendicD(path[j], normals[k])
            var pt = PointD()
            InternalClipper.getLineIntersectPt(pt1, pt2, pt3, pt4, &pt)
            pathOut.append(Point64(pt))
            // get the second intersect point through reflection
            pathOut.append(Point64(ClipperOffset.reflectPoint(pt, ptQ)))
        }
    }

    private func doMiter(_ path: Path64, _ j: Int, _ k: Int, _ cosA: Double) {
        let q = groupDelta / (cosA + 1)
        pathOut.append(Point64(
            Double(path[j].x) + (normals[k].x + normals[j].x) * q,
            Double(path[j].y) + (normals[k].y + normals[j].y) * q))
    }

    private func doRound(_ path: Path64, _ j: Int, _ k: Int, _ angle: Double) {
        if deltaCallback != nil {
            // when deltaCallback is assigned, groupDelta won't be constant,
            // so we'll need to do the following calculations for *every* vertex.
            let absDelta = abs(groupDelta)
            let arcTol = arcTolerance > 0.01 ? arcTolerance : absDelta * ClipperOffset.arcConst
            let stepsPer360 = Double.pi / acos(1 - arcTol / absDelta)
            stepSin = sin((2 * Double.pi) / stepsPer360)
            stepCos = cos((2 * Double.pi) / stepsPer360)
            if groupDelta < 0.0 {
                stepSin = -stepSin
            }
            stepsPerRad = stepsPer360 / (2 * Double.pi)
        }

        let pt = path[j]
        var offsetVec = PointD(normals[k].x * groupDelta, normals[k].y * groupDelta)
        if j == k {
            offsetVec.negate()
        }
        pathOut.append(Point64(Double(pt.x) + offsetVec.x, Double(pt.y) + offsetVec.y))
        let steps = Int(ceil(stepsPerRad * abs(angle)))
        for _ in 1..<steps {
            offsetVec = PointD(offsetVec.x * stepCos - stepSin * offsetVec.y,
                               offsetVec.x * stepSin + offsetVec.y * stepCos)
            pathOut.append(Point64(Double(pt.x) + offsetVec.x, Double(pt.y) + offsetVec.y))
        }
        pathOut.append(getPerpendic(pt, normals[j]))
    }

    // MARK: - Normal Building

    private func buildNormals(_ path: Path64) {
        let cnt = path.count
        normals.removeAll()
        if cnt == 0 { return }
        normals.reserveCapacity(cnt)
        for i in 0..<(cnt - 1) {
            normals.append(ClipperOffset.getUnitNormal(path[i], path[i + 1]))
        }
        normals.append(ClipperOffset.getUnitNormal(path[cnt - 1], path[0]))
    }

    // MARK: - Offset Operations

    private func offsetPoint(_ group: Group, _ path: Path64, _ j: Int, _ k: Int) -> Int {
        if path[j] == path[k] {
            return j
        }

        // Let A = change in angle where edges join
        var sinA = InternalClipper.crossProduct(normals[j], normals[k])
        let cosA = InternalClipper.dotProduct(normals[j], normals[k])
        if sinA > 1.0 {
            sinA = 1.0
        } else if sinA < -1.0 {
            sinA = -1.0
        }

        if let cb = deltaCallback {
            groupDelta = cb(path, normals, j, k)
            if group.pathsReversed {
                groupDelta = -groupDelta
            }
        }
        if abs(groupDelta) < ClipperOffset.tolerance {
            pathOut.append(path[j])
            return j
        }

        if cosA > -0.999 && (sinA * groupDelta < 0) {
            // is concave
            pathOut.append(getPerpendic(path[j], normals[k]))
            pathOut.append(path[j])
            pathOut.append(getPerpendic(path[j], normals[j]))
        } else if cosA > 0.999 && _joinType != .round {
            // almost straight - less than 2.5 degree
            doMiter(path, j, k, cosA)
        } else if _joinType == .miter {
            if cosA > mitLimSqr - 1 {
                doMiter(path, j, k, cosA)
            } else {
                doSquare(path, j, k)
            }
        } else if _joinType == .round {
            doRound(path, j, k, atan2(sinA, cosA))
        } else if _joinType == .bevel {
            doBevel(path, j, k)
        } else {
            doSquare(path, j, k)
        }

        return j
    }

    private func offsetPolygon(_ group: Group, _ path: Path64) {
        pathOut = Path64()
        let cnt = path.count
        var prev = cnt - 1
        for i in 0..<cnt {
            prev = offsetPoint(group, path, i, prev)
        }
        solution.append(pathOut)
    }

    private func offsetOpenJoined(_ group: Group, _ path: Path64) {
        offsetPolygon(group, path)
        let reversed = Clipper.reversePath(path)
        buildNormals(reversed)
        offsetPolygon(group, reversed)
    }

    private func offsetOpenPath(_ group: Group, _ path: Path64) {
        pathOut = Path64()
        let highI = path.count - 1
        if highI < 1 {
            if highI == 0 {
                solution.append(Path64(path))
            }
            return
        }

        // Overwrite the polygon-based normals with normals for an open path
        normals.removeAll()
        for i in 0..<highI {
            normals.append(ClipperOffset.getUnitNormal(path[i], path[i + 1]))
        }
        normals.append(PointD(normals[highI - 1]))

        if let cb = deltaCallback {
            groupDelta = cb(path, normals, 0, 0)
        }

        // do the line start cap
        if abs(groupDelta) < ClipperOffset.tolerance {
            pathOut.append(path[0])
        } else {
            switch _endType {
            case .butt:
                doBevel(path, 0, 0)
            case .round:
                doRound(path, 0, 0, Double.pi)
            default:
                doSquare(path, 0, 0)
            }
        }

        // offset the left side going forward
        var k = 0
        for i in 1..<highI {
            k = offsetPoint(group, path, i, k)
        }

        // reverse normals ...
        for i in stride(from: highI, through: 1, by: -1) {
            normals[i] = PointD(-normals[i - 1].x, -normals[i - 1].y)
        }
        normals[0] = PointD(normals[highI])

        if let cb = deltaCallback {
            groupDelta = cb(path, normals, highI, highI)
        }

        // do the line end cap
        if abs(groupDelta) < ClipperOffset.tolerance {
            pathOut.append(path[highI])
        } else {
            switch _endType {
            case .butt:
                doBevel(path, highI, highI)
            case .round:
                doRound(path, highI, highI, Double.pi)
            default:
                doSquare(path, highI, highI)
            }
        }

        // offset the left side going back
        k = highI
        for i in stride(from: highI - 1, through: 1, by: -1) {
            k = offsetPoint(group, path, i, k)
        }

        solution.append(pathOut)
    }

    private func doGroupOffset(_ group: Group) {
        if group.endType == .polygon {
            // a straight path (2 points) can now also be 'polygon' offset
            // where the ends will be treated as (180 deg.) joins
            if group.lowestPathIdx < 0 {
                delta = abs(delta)
            }
            groupDelta = group.pathsReversed ? -delta : delta
        } else {
            groupDelta = abs(delta)
        }

        var absDelta = abs(groupDelta)

        _joinType = group.joinType
        _endType = group.endType

        if group.joinType == .round || group.endType == .round {
            // calculate the number of steps required to approximate a circle
            let arcTol = arcTolerance > 0.01 ? arcTolerance : absDelta * ClipperOffset.arcConst
            let stepsPer360 = Double.pi / acos(1 - arcTol / absDelta)
            stepSin = sin((2 * Double.pi) / stepsPer360)
            stepCos = cos((2 * Double.pi) / stepsPer360)
            if groupDelta < 0.0 {
                stepSin = -stepSin
            }
            stepsPerRad = stepsPer360 / (2 * Double.pi)
        }

        for p in group.inPaths {
            let cnt = p.count
            if cnt == 0 || (cnt < 3 && _endType == .polygon) {
                continue
            }

            pathOut = Path64()
            if cnt == 1 {
                let pt = p[0]
                if let cb = deltaCallback {
                    groupDelta = cb(p, normals, 0, 0)
                    if group.pathsReversed {
                        groupDelta = -groupDelta
                    }
                    absDelta = abs(groupDelta)
                }

                // single vertex so build a circle or square ...
                if group.endType == .round {
                    let r = absDelta
                    let steps = Int(ceil(stepsPerRad * 2 * Double.pi))
                    pathOut = Clipper.ellipse(pt, r, r, steps)
                } else {
                    let d = Int64(ceil(groupDelta))
                    let r = Rect64(pt.x - d, pt.y - d, pt.x + d, pt.y + d)
                    pathOut = r.asPath()
                }
                solution.append(pathOut)
                continue
            } // end of offsetting a single point

            if cnt == 2 && group.endType == .joined {
                _endType = (group.joinType == .round) ? .round : .square
            }

            buildNormals(p)
            if _endType == .polygon {
                offsetPolygon(group, p)
            } else if _endType == .joined {
                offsetOpenJoined(group, p)
            } else {
                offsetOpenPath(group, p)
            }
        }
    }
}
