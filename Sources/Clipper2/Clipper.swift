import Foundation

/// Utility functions for Clipper2 operations.
public enum Clipper {

    // MARK: - Area

    /// Returns the signed area of the supplied polygon using the Shoelace formula.
    public static func area(_ path: Path64) -> Double {
        var a = 0.0
        let cnt = path.count
        if cnt < 3 { return 0.0 }
        var prevPt = path[cnt - 1]
        for pt in path {
            a += Double(prevPt.y + pt.y) * Double(prevPt.x - pt.x)
            prevPt = pt
        }
        return a * 0.5
    }

    /// Returns the combined signed area of the supplied polygons.
    public static func area(_ paths: Paths64) -> Double {
        var a = 0.0
        for path in paths {
            a += area(path)
        }
        return a
    }

    /// Returns the signed area of the supplied floating-point polygon.
    public static func area(_ path: PathD) -> Double {
        var a = 0.0
        let cnt = path.count
        if cnt < 3 { return 0.0 }
        var prevPt = path[cnt - 1]
        for pt in path {
            a += (prevPt.y + pt.y) * (prevPt.x - pt.x)
            prevPt = pt
        }
        return a * 0.5
    }

    /// Returns the combined signed area of the supplied floating-point polygons.
    public static func area(_ paths: PathsD) -> Double {
        var a = 0.0
        for path in paths {
            a += area(path)
        }
        return a
    }

    // MARK: - Reverse

    /// Returns a reversed copy of the path.
    public static func reversePath(_ path: Path64) -> Path64 {
        return Path64(path.reversed())
    }

    /// Returns a reversed copy of the floating-point path.
    public static func reversePath(_ path: PathD) -> PathD {
        return PathD(path.reversed())
    }

    // MARK: - Strip Duplicates

    /// Removes consecutive duplicate points from a path.
    public static func stripDuplicates(_ path: Path64, isClosedPath: Bool) -> Path64 {
        let cnt = path.count
        var result = Path64()
        if cnt == 0 { return result }
        result.reserveCapacity(cnt)
        var lastPt = path[0]
        result.append(lastPt)
        for i in 1..<cnt {
            if path[i] != lastPt {
                lastPt = path[i]
                result.append(lastPt)
            }
        }
        if isClosedPath && result.count > 1 && result[0] == result[result.count - 1] {
            result.removeLast()
        }
        return result
    }

    // MARK: - Sqr

    /// Returns value squared.
    public static func sqr(_ value: Double) -> Double {
        return value * value
    }

    /// Returns value squared (Int64 variant).
    public static func sqr(_ value: Int64) -> Double {
        return Double(value) * Double(value)
    }

    // MARK: - Orientation

    /// Returns true if the polygon has positive (counter-clockwise) winding.
    public static func isPositive(_ poly: Path64) -> Bool {
        return area(poly) >= 0
    }

    /// Returns true if the floating-point polygon has positive winding.
    public static func isPositive(_ poly: PathD) -> Bool {
        return area(poly) >= 0
    }

    // MARK: - Scaling

    /// Scales a floating-point path to an integer path.
    public static func scalePath64(_ path: PathD, _ scale: Double) -> Path64 {
        var res = Path64()
        res.reserveCapacity(path.count)
        for pt in path {
            res.append(Point64(pt, scale: scale))
        }
        return res
    }

    /// Scales floating-point paths to integer paths.
    public static func scalePaths64(_ paths: PathsD, _ scale: Double) -> Paths64 {
        var res = Paths64()
        res.reserveCapacity(paths.count)
        for path in paths {
            res.append(scalePath64(path, scale))
        }
        return res
    }

    /// Scales an integer path to a floating-point path.
    public static func scalePathD(_ path: Path64, _ scale: Double) -> PathD {
        var res = PathD()
        res.reserveCapacity(path.count)
        for pt in path {
            res.append(PointD(pt, scale: scale))
        }
        return res
    }

    /// Scales integer paths to floating-point paths.
    public static func scalePathsD(_ paths: Paths64, _ scale: Double) -> PathsD {
        var res = PathsD()
        res.reserveCapacity(paths.count)
        for path in paths {
            res.append(scalePathD(path, scale))
        }
        return res
    }

    // MARK: - Boolean Operations

    /// Performs a boolean operation on subject and clip paths.
    public static func booleanOp(_ clipType: ClipType, _ subject: Paths64, _ clip: Paths64?, _ fillRule: FillRule) -> Paths64 {
        var solution = Paths64()
        let c = Clipper64()
        c.addPaths(subject, .subject)
        if let clip = clip {
            c.addPaths(clip, .clip)
        }
        c.execute(clipType, fillRule, &solution)
        return solution
    }

    /// Unites the supplied subject paths.
    public static func union(_ subject: Paths64, _ fillRule: FillRule) -> Paths64 {
        return booleanOp(.union, subject, nil, fillRule)
    }

    /// Unites two sets of integer paths.
    public static func union(_ subject: Paths64, _ clip: Paths64, _ fillRule: FillRule) -> Paths64 {
        return booleanOp(.union, subject, clip, fillRule)
    }

    // MARK: - Ellipse

    /// Approximates an integer ellipse.
    public static func ellipse(_ center: Point64, _ radiusX: Double, _ radiusY: Double = 0, _ steps: Int = 0) -> Path64 {
        if radiusX <= 0 { return Path64() }
        var ry = radiusY
        if ry <= 0 { ry = radiusX }
        var stps = steps
        if stps <= 2 {
            stps = Int(ceil(Double.pi * sqrt((radiusX + ry) / 2)))
        }

        let si = sin(2 * Double.pi / Double(stps))
        let co = cos(2 * Double.pi / Double(stps))
        var dx = co
        var dy = si
        var result = Path64()
        result.reserveCapacity(stps)
        result.append(Point64(Double(center.x) + radiusX, Double(center.y)))
        for _ in 1..<stps {
            result.append(Point64(Double(center.x) + radiusX * dx, Double(center.y) + ry * dy))
            let x = dx * co - dy * si
            dy = dy * co + dx * si
            dx = x
        }
        return result
    }

    // MARK: - Make Path

    /// Creates an integer path from alternating x,y coordinate pairs (Int64).
    public static func makePath(_ arr: [Int64]) -> Path64 {
        let len = arr.count / 2
        var p = Path64()
        p.reserveCapacity(len)
        for i in 0..<len {
            p.append(Point64(arr[i * 2], arr[i * 2 + 1]))
        }
        return p
    }

    /// Creates an integer path from alternating x,y coordinate pairs (Int32).
    public static func makePath(_ arr: [Int32]) -> Path64 {
        let len = arr.count / 2
        var p = Path64()
        p.reserveCapacity(len)
        for i in 0..<len {
            p.append(Point64(Int64(arr[i * 2]), Int64(arr[i * 2 + 1])))
        }
        return p
    }

    /// Creates a floating-point path from alternating x,y coordinate pairs.
    public static func makePath(_ arr: [Double]) -> PathD {
        let len = arr.count / 2
        var p = PathD()
        p.reserveCapacity(len)
        for i in 0..<len {
            p.append(PointD(arr[i * 2], arr[i * 2 + 1]))
        }
        return p
    }

    // MARK: - Scale Paths (same type)

    /// Scales an integer path by a given factor.
    public static func scalePath(_ path: Path64, _ scale: Double) -> Path64 {
        if InternalClipper.isAlmostZero(scale - 1) { return path }
        var result = Path64()
        result.reserveCapacity(path.count)
        for pt in path {
            result.append(Point64(Double(pt.x) * scale, Double(pt.y) * scale))
        }
        return result
    }

    /// Scales integer paths by a given factor.
    public static func scalePaths(_ paths: Paths64, _ scale: Double) -> Paths64 {
        if InternalClipper.isAlmostZero(scale - 1) { return paths }
        var result = Paths64()
        result.reserveCapacity(paths.count)
        for path in paths {
            result.append(scalePath(path, scale))
        }
        return result
    }

    // MARK: - Inflate Paths

    /// Inflates or shrinks integer paths with default miter limit and arc tolerance.
    public static func inflatePaths(_ paths: Paths64, _ delta: Double, _ joinType: JoinType, _ endType: EndType) -> Paths64 {
        return inflatePaths(paths, delta, joinType, endType, 2.0, 0.0)
    }

    /// Inflates or shrinks integer paths with specified miter limit and arc tolerance.
    public static func inflatePaths(_ paths: Paths64, _ delta: Double, _ joinType: JoinType, _ endType: EndType, _ miterLimit: Double, _ arcTolerance: Double) -> Paths64 {
        let co = ClipperOffset(miterLimit: miterLimit, arcTolerance: arcTolerance)
        co.addPaths(paths, joinType, endType)
        var solution = Paths64()
        co.execute(delta, &solution)
        return solution
    }

    /// Inflates or shrinks floating-point paths.
    public static func inflatePaths(_ paths: PathsD, _ delta: Double, _ joinType: JoinType, _ endType: EndType) -> PathsD {
        return try! inflatePaths(paths, delta, joinType, endType, 2.0, 0.0, 8)
    }

    /// Inflates or shrinks floating-point paths with specified parameters.
    public static func inflatePaths(_ paths: PathsD, _ delta: Double, _ joinType: JoinType, _ endType: EndType, _ miterLimit: Double, _ arcTolerance: Double, _ precision: Int) throws -> PathsD {
        try InternalClipper.checkPrecision(precision)
        let scale = pow(10, Double(precision))
        var tmp = scalePaths64(paths, scale)
        let co = ClipperOffset(miterLimit: miterLimit, arcTolerance: arcTolerance * scale)
        co.addPaths(tmp, joinType, endType)
        co.execute(delta * scale, &tmp)
        return scalePathsD(tmp, 1 / scale)
    }

    // MARK: - Rect Clip

    /// Clips paths to a rectangle.
    public static func rectClip(_ rect: Rect64, _ paths: Paths64) -> Paths64 {
        if rect.isEmpty || paths.isEmpty { return Paths64() }
        let rc = RectClip64(rect)
        return rc.execute(paths)
    }

    /// Clips a single path to a rectangle.
    public static func rectClip(_ rect: Rect64, _ path: Path64) -> Paths64 {
        if rect.isEmpty || path.isEmpty { return Paths64() }
        return rectClip(rect, [path])
    }

    // MARK: - Intersect

    /// Performs an intersection operation on subject and clip paths.
    public static func intersect(_ subject: Paths64, _ clip: Paths64, _ fillRule: FillRule) -> Paths64 {
        return booleanOp(.intersection, subject, clip, fillRule)
    }

    // MARK: - Get Bounds

    /// Returns the bounds of a single integer path.
    public static func getBounds(_ path: Path64) -> Rect64 {
        return InternalClipper.getBounds(path)
    }

    /// Returns the bounds of multiple integer paths.
    public static func getBounds(_ paths: Paths64) -> Rect64 {
        var result = Rect64.invalid
        for path in paths {
            for pt in path {
                if pt.x < result.left { result.left = pt.x }
                if pt.x > result.right { result.right = pt.x }
                if pt.y < result.top { result.top = pt.y }
                if pt.y > result.bottom { result.bottom = pt.y }
            }
        }
        return result.left == Int64.max ? Rect64() : result
    }

    // MARK: - Point In Polygon

    /// Tests whether a point is inside, outside, or on the edge of a polygon.
    public static func pointInPolygon(_ pt: Point64, _ path: Path64) -> PointInPolygonResult {
        return InternalClipper.pointInPolygon(pt, path)
    }

    // MARK: - PolyTree to Paths

    /// Flattens a PolyTree64 into a Paths64 collection.
    public static func polyTreeToPaths64(_ polyTree: PolyTree64) -> Paths64 {
        var result = Paths64()
        for child in polyTree {
            addPolyNodeToPaths(child as! PolyPath64, &result)
        }
        return result
    }

    private static func addPolyNodeToPaths(_ polyPath: PolyPath64, _ paths: inout Paths64) {
        if let polygon = polyPath.getPolygon(), !polygon.isEmpty {
            paths.append(polygon)
        }
        for child in polyPath {
            addPolyNodeToPaths(child as! PolyPath64, &paths)
        }
    }

    // MARK: - Static Invalid Rects

    /// Sentinel invalid Rect64 used while computing integer bounds.
    public static let invalidRect64 = Rect64(isValid: false)
    public static let InvalidRect64 = invalidRect64

    /// Sentinel invalid RectD used while computing floating-point bounds.
    public static let invalidRectD = RectD(isValid: false)
    public static let InvalidRectD = invalidRectD

    // MARK: - Ellipse (PointD overload)

    /// Approximates a floating-point ellipse.
    public static func ellipse(_ center: PointD, _ radiusX: Double, _ radiusY: Double = 0, _ steps: Int = 0) -> PathD {
        if radiusX <= 0 { return PathD() }
        var ry = radiusY
        if ry <= 0 { ry = radiusX }
        var stps = steps
        if stps <= 2 {
            stps = Int(ceil(Double.pi * sqrt((radiusX + ry) / 2)))
        }

        let si = sin(2 * Double.pi / Double(stps))
        let co = cos(2 * Double.pi / Double(stps))
        var dx = co
        var dy = si
        var result = PathD()
        result.reserveCapacity(stps)
        result.append(PointD(center.x + radiusX, center.y))
        for _ in 1..<stps {
            result.append(PointD(center.x + radiusX * dx, center.y + ry * dy))
            let x = dx * co - dy * si
            dy = dy * co + dx * si
            dx = x
        }
        return result
    }

    // MARK: - Intersect (PathsD overloads)

    /// Intersects two sets of floating-point paths using the default precision.
    public static func intersect(_ subject: PathsD, _ clip: PathsD, _ fillRule: FillRule) -> PathsD {
        return try! intersect(subject, clip, fillRule, 2)
    }

    /// Intersects two sets of floating-point paths.
    public static func intersect(_ subject: PathsD, _ clip: PathsD, _ fillRule: FillRule, _ precision: Int) throws -> PathsD {
        return try booleanOp(.intersection, subject, clip, fillRule, precision)
    }

    // MARK: - Difference

    /// Subtracts the clip paths from the subject paths (integer).
    public static func difference(_ subject: Paths64, _ clip: Paths64, _ fillRule: FillRule) -> Paths64 {
        return booleanOp(.difference, subject, clip, fillRule)
    }

    /// Subtracts the clip paths from the subject paths (floating-point, default precision).
    public static func difference(_ subject: PathsD, _ clip: PathsD, _ fillRule: FillRule) -> PathsD {
        return try! difference(subject, clip, fillRule, 2)
    }

    /// Subtracts the clip paths from the subject paths (floating-point).
    public static func difference(_ subject: PathsD, _ clip: PathsD, _ fillRule: FillRule, _ precision: Int) throws -> PathsD {
        return try booleanOp(.difference, subject, clip, fillRule, precision)
    }

    // MARK: - Xor

    /// Computes the exclusive-or of two sets of integer paths.
    public static func xor(_ subject: Paths64, _ clip: Paths64, _ fillRule: FillRule) -> Paths64 {
        return booleanOp(.xor, subject, clip, fillRule)
    }

    /// Computes the exclusive-or of two sets of floating-point paths (default precision).
    public static func xor(_ subject: PathsD, _ clip: PathsD, _ fillRule: FillRule) -> PathsD {
        return try! xor(subject, clip, fillRule, 2)
    }

    /// Computes the exclusive-or of two sets of floating-point paths.
    public static func xor(_ subject: PathsD, _ clip: PathsD, _ fillRule: FillRule, _ precision: Int) throws -> PathsD {
        return try booleanOp(.xor, subject, clip, fillRule, precision)
    }

    // MARK: - Union (PathsD overloads)

    /// Unites the supplied floating-point subject paths using the default precision.
    public static func union(_ subject: PathsD, _ fillRule: FillRule) -> PathsD {
        return booleanOp(.union, subject, nil, fillRule)
    }

    /// Unites two sets of floating-point paths using the default precision.
    public static func union(_ subject: PathsD, _ clip: PathsD, _ fillRule: FillRule) -> PathsD {
        return try! union(subject, clip, fillRule, 2)
    }

    /// Unites two sets of floating-point paths.
    public static func union(_ subject: PathsD, _ clip: PathsD, _ fillRule: FillRule, _ precision: Int) throws -> PathsD {
        return try booleanOp(.union, subject, clip, fillRule, precision)
    }

    // MARK: - BooleanOp (PolyTree64 overload)

    /// Performs a boolean operation on integer paths and stores the result in a PolyTree64.
    public static func booleanOp(_ clipType: ClipType, _ subject: Paths64?, _ clip: Paths64?, _ polytree: PolyTree64, _ fillRule: FillRule) {
        guard let subject = subject else { return }
        let c = Clipper64()
        c.addPaths(subject, .subject)
        if let clip = clip {
            c.addPaths(clip, .clip)
        }
        c.execute(clipType, fillRule, polytree)
    }

    // MARK: - BooleanOp (PathsD overloads)

    /// Performs a boolean operation on floating-point paths (default precision).
    public static func booleanOp(_ clipType: ClipType, _ subject: PathsD?, _ clip: PathsD?, _ fillRule: FillRule) -> PathsD {
        return try! booleanOp(clipType, subject, clip, fillRule, 2)
    }

    /// Performs a boolean operation on floating-point paths.
    public static func booleanOp(_ clipType: ClipType, _ subject: PathsD?, _ clip: PathsD?, _ fillRule: FillRule, _ precision: Int) throws -> PathsD {
        var solution = PathsD()
        guard let subject = subject else { return solution }
        let c = try ClipperD(roundingDecimalPrecision: precision)
        c.addSubjects(subject)
        if let clip = clip {
            c.addClips(clip)
        }
        c.execute(clipType, fillRule, &solution)
        return solution
    }

    // MARK: - BooleanOp (PolyTreeD overloads)

    /// Performs a boolean operation on floating-point paths and stores the result in a PolyTreeD (default precision).
    public static func booleanOp(_ clipType: ClipType, _ subject: PathsD?, _ clip: PathsD?, _ polytree: PolyTreeD, _ fillRule: FillRule) {
        try! booleanOp(clipType, subject, clip, polytree, fillRule, 2)
    }

    /// Performs a boolean operation on floating-point paths and stores the result in a PolyTreeD.
    public static func booleanOp(_ clipType: ClipType, _ subject: PathsD?, _ clip: PathsD?, _ polytree: PolyTreeD, _ fillRule: FillRule, _ precision: Int) throws {
        guard let subject = subject else { return }
        let c = try ClipperD(roundingDecimalPrecision: precision)
        c.addPaths(subject, .subject)
        if let clip = clip {
            c.addPaths(clip, .clip)
        }
        c.execute(clipType, fillRule, polytree)
    }

    // MARK: - Inflate Paths (PathsD with miterLimit only)

    /// Inflates or shrinks floating-point paths with a custom miter limit.
    public static func inflatePaths(_ paths: PathsD, _ delta: Double, _ joinType: JoinType, _ endType: EndType, _ miterLimit: Double) -> PathsD {
        return try! inflatePaths(paths, delta, joinType, endType, miterLimit, 0.0, 8)
    }

    // MARK: - Rect Clip (RectD overloads)

    /// Clips floating-point paths to a rectangle (default precision).
    public static func rectClip(_ rect: RectD, _ paths: PathsD) -> PathsD {
        return try! rectClip(rect, paths, 2)
    }

    /// Clips floating-point paths to a rectangle.
    public static func rectClip(_ rect: RectD, _ paths: PathsD, _ precision: Int) throws -> PathsD {
        try InternalClipper.checkPrecision(precision)
        if rect.isEmpty || paths.isEmpty { return PathsD() }
        let scale = pow(10.0, Double(precision))
        let r = scaleRect(rect, scale)
        var tmpPath = scalePaths64(paths, scale)
        let rc = RectClip64(r)
        tmpPath = rc.execute(tmpPath)
        return scalePathsD(tmpPath, 1.0 / scale)
    }

    /// Clips a single floating-point path to a rectangle (default precision).
    public static func rectClip(_ rect: RectD, _ path: PathD) -> PathsD {
        return try! rectClip(rect, path, 2)
    }

    /// Clips a single floating-point path to a rectangle.
    public static func rectClip(_ rect: RectD, _ path: PathD, _ precision: Int) throws -> PathsD {
        if rect.isEmpty || path.isEmpty { return PathsD() }
        return try rectClip(rect, [path], precision)
    }

    // MARK: - Rect Clip Lines

    /// Clips integer polylines to the specified rectangle.
    public static func rectClipLines(_ rect: Rect64, _ paths: Paths64) -> Paths64 {
        if rect.isEmpty || paths.isEmpty { return Paths64() }
        let rc = RectClipLines64(rect)
        return rc.executeLines(paths)
    }

    /// Clips a single integer polyline to the specified rectangle.
    public static func rectClipLines(_ rect: Rect64, _ path: Path64) -> Paths64 {
        if rect.isEmpty || path.isEmpty { return Paths64() }
        return rectClipLines(rect, [path])
    }

    /// Clips floating-point polylines to the specified rectangle (default precision).
    public static func rectClipLines(_ rect: RectD, _ paths: PathsD) -> PathsD {
        return try! rectClipLines(rect, paths, 2)
    }

    /// Clips floating-point polylines to the specified rectangle.
    public static func rectClipLines(_ rect: RectD, _ paths: PathsD, _ precision: Int) throws -> PathsD {
        try InternalClipper.checkPrecision(precision)
        if rect.isEmpty || paths.isEmpty { return PathsD() }
        let scale = pow(10.0, Double(precision))
        let r = scaleRect(rect, scale)
        var tmpPath = scalePaths64(paths, scale)
        let rc = RectClipLines64(r)
        tmpPath = rc.executeLines(tmpPath)
        return scalePathsD(tmpPath, 1.0 / scale)
    }

    /// Clips a single floating-point polyline to the specified rectangle (default precision).
    public static func rectClipLines(_ rect: RectD, _ path: PathD) -> PathsD {
        return try! rectClipLines(rect, path, 2)
    }

    /// Clips a single floating-point polyline to the specified rectangle.
    public static func rectClipLines(_ rect: RectD, _ path: PathD, _ precision: Int) throws -> PathsD {
        if rect.isEmpty || path.isEmpty { return PathsD() }
        return try rectClipLines(rect, [path], precision)
    }

    // MARK: - Minkowski Sum / Diff

    /// Computes the Minkowski sum of an integer pattern and path.
    public static func minkowskiSum(_ pattern: Path64, _ path: Path64, _ isClosed: Bool) -> Paths64 {
        return Minkowski.sum(pattern, path, isClosed: isClosed)
    }

    /// Computes the Minkowski sum of a floating-point pattern and path.
    public static func minkowskiSum(_ pattern: PathD, _ path: PathD, _ isClosed: Bool) -> PathsD {
        return Minkowski.sum(pattern, path, isClosed: isClosed)
    }

    /// Computes the Minkowski difference of an integer pattern and path.
    public static func minkowskiDiff(_ pattern: Path64, _ path: Path64, _ isClosed: Bool) -> Paths64 {
        return Minkowski.diff(pattern, path, isClosed: isClosed)
    }

    /// Computes the Minkowski difference of a floating-point pattern and path.
    public static func minkowskiDiff(_ pattern: PathD, _ path: PathD, _ isClosed: Bool) -> PathsD {
        return Minkowski.diff(pattern, path, isClosed: isClosed)
    }

    // MARK: - Translate Path

    /// Translates an integer path by dx, dy.
    public static func translatePath(_ path: Path64, _ dx: Int64, _ dy: Int64) -> Path64 {
        var result = Path64()
        result.reserveCapacity(path.count)
        for pt in path {
            result.append(Point64(pt.x + dx, pt.y + dy))
        }
        return result
    }

    /// Translates multiple integer paths by dx, dy.
    public static func translatePaths(_ paths: Paths64, _ dx: Int64, _ dy: Int64) -> Paths64 {
        var result = Paths64()
        result.reserveCapacity(paths.count)
        for path in paths {
            result.append(translatePath(path, dx, dy))
        }
        return result
    }

    /// Translates a floating-point path by dx, dy.
    public static func translatePath(_ path: PathD, _ dx: Double, _ dy: Double) -> PathD {
        var result = PathD()
        result.reserveCapacity(path.count)
        for pt in path {
            result.append(PointD(pt.x + dx, pt.y + dy))
        }
        return result
    }

    /// Translates multiple floating-point paths by dx, dy.
    public static func translatePaths(_ paths: PathsD, _ dx: Double, _ dy: Double) -> PathsD {
        var result = PathsD()
        result.reserveCapacity(paths.count)
        for path in paths {
            result.append(translatePath(path, dx, dy))
        }
        return result
    }

    // MARK: - GetBounds (PathD / PathsD overloads)

    /// Returns the bounds of a floating-point path.
    public static func getBounds(_ path: PathD) -> RectD {
        var result = RectD(isValid: false)
        for pt in path {
            if pt.x < result.left { result.left = pt.x }
            if pt.x > result.right { result.right = pt.x }
            if pt.y < result.top { result.top = pt.y }
            if pt.y > result.bottom { result.bottom = pt.y }
        }
        return InternalClipper.isAlmostZero(result.left - Double.greatestFiniteMagnitude) ? RectD() : result
    }

    /// Returns the bounds of multiple floating-point paths.
    public static func getBounds(_ paths: PathsD) -> RectD {
        var result = RectD(isValid: false)
        for path in paths {
            for pt in path {
                if pt.x < result.left { result.left = pt.x }
                if pt.x > result.right { result.right = pt.x }
                if pt.y < result.top { result.top = pt.y }
                if pt.y > result.bottom { result.bottom = pt.y }
            }
        }
        return InternalClipper.isAlmostZero(result.left - Double.greatestFiniteMagnitude) ? RectD() : result
    }

    // MARK: - Scale Point

    /// Scales an integer point by a factor, returning a new Point64.
    public static func scalePoint64(_ pt: Point64, _ scale: Double) -> Point64 {
        return Point64(Double(pt.x) * scale, Double(pt.y) * scale)
    }

    /// Scales an integer point by a factor, returning a new PointD.
    public static func scalePointD(_ pt: Point64, _ scale: Double) -> PointD {
        return PointD(Double(pt.x) * scale, Double(pt.y) * scale)
    }

    // MARK: - Scale Rect

    /// Scales a floating-point rectangle to an integer rectangle.
    public static func scaleRect(_ rec: RectD, _ scale: Double) -> Rect64 {
        return Rect64(Int64(rec.left * scale), Int64(rec.top * scale),
                      Int64(rec.right * scale), Int64(rec.bottom * scale))
    }

    // MARK: - Scale Path (PathD -> PathD)

    /// Scales a floating-point path by a factor, returning a new PathD.
    public static func scalePath(_ path: PathD, _ scale: Double) -> PathD {
        if InternalClipper.isAlmostZero(scale - 1) { return path }
        var result = PathD()
        result.reserveCapacity(path.count)
        for pt in path {
            result.append(PointD(pt, scale: scale))
        }
        return result
    }

    /// Scales multiple floating-point paths by a factor.
    public static func scalePaths(_ paths: PathsD, _ scale: Double) -> PathsD {
        if InternalClipper.isAlmostZero(scale - 1) { return paths }
        var result = PathsD()
        result.reserveCapacity(paths.count)
        for path in paths {
            result.append(scalePath(path, scale))
        }
        return result
    }

    // MARK: - Type conversion (without scaling)

    /// Converts a PathD to a Path64 without scaling.
    public static func path64(_ path: PathD) -> Path64 {
        var result = Path64()
        result.reserveCapacity(path.count)
        for pt in path {
            result.append(Point64(pt))
        }
        return result
    }

    /// Converts PathsD to Paths64 without scaling.
    public static func paths64(_ paths: PathsD) -> Paths64 {
        var result = Paths64()
        result.reserveCapacity(paths.count)
        for path in paths {
            result.append(path64(path))
        }
        return result
    }

    /// Converts a Path64 to a PathD without scaling.
    public static func pathD(_ path: Path64) -> PathD {
        var result = PathD()
        result.reserveCapacity(path.count)
        for pt in path {
            result.append(PointD(pt))
        }
        return result
    }

    /// Converts Paths64 to PathsD without scaling.
    public static func pathsD(_ paths: Paths64) -> PathsD {
        var result = PathsD()
        result.reserveCapacity(paths.count)
        for path in paths {
            result.append(pathD(path))
        }
        return result
    }

    // MARK: - Offset Path

    /// Offsets an integer path by dx, dy (alias for translatePath).
    public static func offsetPath(_ path: Path64, _ dx: Int64, _ dy: Int64) -> Path64 {
        return translatePath(path, dx, dy)
    }

    // MARK: - String Formatting

    /// Formats a Path64 as a string.
    public static func path64ToString(_ path: Path64) -> String {
        var s = ""
        for pt in path {
            s += pt.description
        }
        return s + "\n"
    }

    /// Formats Paths64 as a string.
    public static func paths64ToString(_ paths: Paths64) -> String {
        var s = ""
        for path in paths {
            s += path64ToString(path)
        }
        return s
    }

    /// Formats a PathD as a string.
    public static func pathDToString(_ path: PathD) -> String {
        var s = ""
        for pt in path {
            s += pt.description
        }
        return s + "\n"
    }

    /// Formats PathsD as a string.
    public static func pathsDToString(_ paths: PathsD) -> String {
        var s = ""
        for path in paths {
            s += pathDToString(path)
        }
        return s
    }

    // MARK: - Reverse Paths

    /// Returns reversed copies of integer paths.
    public static func reversePaths(_ paths: Paths64) -> Paths64 {
        var result = Paths64()
        result.reserveCapacity(paths.count)
        for path in paths {
            result.append(reversePath(path))
        }
        return result
    }

    /// Returns reversed copies of floating-point paths.
    public static func reversePaths(_ paths: PathsD) -> PathsD {
        var result = PathsD()
        result.reserveCapacity(paths.count)
        for path in paths {
            result.append(reversePath(path))
        }
        return result
    }

    // MARK: - PolyTree to PathsD

    /// Recursively adds a PolyPathD and its children to a PathsD collection.
    public static func addPolyNodeToPathsD(_ polyPath: PolyPathD, _ paths: inout PathsD) {
        if let polygon = polyPath.getPolygon(), !polygon.isEmpty {
            paths.append(polygon)
        }
        for child in polyPath {
            if let childD = child as? PolyPathD {
                addPolyNodeToPathsD(childD, &paths)
            }
        }
    }

    /// Converts a PolyTreeD to PathsD.
    public static func polyTreeToPathsD(_ polyTree: PolyTreeD) -> PathsD {
        var result = PathsD()
        for child in polyTree {
            if let childD = child as? PolyPathD {
                addPolyNodeToPathsD(childD, &result)
            }
        }
        return result
    }

    // MARK: - Point In Polygon (PointD overloads)

    /// Tests whether a floating-point point is inside a polygon (default precision).
    public static func pointInPolygon(_ pt: PointD, _ polygon: PathD) -> PointInPolygonResult {
        return try! pointInPolygon(pt, polygon, 2)
    }

    /// Tests whether a floating-point point is inside a polygon.
    public static func pointInPolygon(_ pt: PointD, _ polygon: PathD, _ precision: Int) throws -> PointInPolygonResult {
        try InternalClipper.checkPrecision(precision)
        let scale = pow(10.0, Double(precision))
        let p = Point64(pt, scale: scale)
        let path = scalePath64(polygon, scale)
        return InternalClipper.pointInPolygon(p, path)
    }

    // MARK: - Distance and Midpoint

    /// Returns the squared distance between two integer points.
    public static func distanceSqr(_ pt1: Point64, _ pt2: Point64) -> Double {
        return sqr(pt1.x - pt2.x) + sqr(pt1.y - pt2.y)
    }

    /// Returns the midpoint of two integer points.
    public static func midPoint(_ pt1: Point64, _ pt2: Point64) -> Point64 {
        return Point64((pt1.x + pt2.x) / 2, (pt1.y + pt2.y) / 2)
    }

    /// Returns the midpoint of two floating-point points.
    public static func midPoint(_ pt1: PointD, _ pt2: PointD) -> PointD {
        return PointD((pt1.x + pt2.x) / 2, (pt1.y + pt2.y) / 2)
    }

    // MARK: - Inflate Rect

    /// Expands or contracts an integer rectangle in place.
    public static func inflateRect(_ rec: inout Rect64, _ dx: Int64, _ dy: Int64) {
        rec.left -= dx
        rec.right += dx
        rec.top -= dy
        rec.bottom += dy
    }

    /// Expands or contracts a floating-point rectangle in place.
    public static func inflateRect(_ rec: inout RectD, _ dx: Double, _ dy: Double) {
        rec.left -= dx
        rec.right += dx
        rec.top -= dy
        rec.bottom += dy
    }

    // MARK: - Near-duplicate handling

    /// Returns whether two floating-point points are within squared distance.
    public static func pointsNearEqual(_ pt1: PointD, _ pt2: PointD, _ distanceSqrd: Double) -> Bool {
        return sqr(pt1.x - pt2.x) + sqr(pt1.y - pt2.y) < distanceSqrd
    }

    /// Removes near-duplicate points from a floating-point path.
    public static func stripNearDuplicates(_ path: PathD, _ minEdgeLenSqrd: Double, _ isClosedPath: Bool) -> PathD {
        let cnt = path.count
        var result = PathD()
        if cnt == 0 { return result }
        result.reserveCapacity(cnt)
        var lastPt = path[0]
        result.append(lastPt)
        for i in 1..<cnt {
            if !pointsNearEqual(lastPt, path[i], minEdgeLenSqrd) {
                lastPt = path[i]
                result.append(lastPt)
            }
        }
        if isClosedPath && result.count > 1 && pointsNearEqual(lastPt, result[0], minEdgeLenSqrd) {
            result.removeLast()
        }
        return result
    }

    // MARK: - Perpendicular Distance

    /// Returns the squared perpendicular distance from a point to a line (floating-point).
    public static func perpendicDistFromLineSqrd(_ pt: PointD, _ line1: PointD, _ line2: PointD) -> Double {
        let a = pt.x - line1.x
        let b = pt.y - line1.y
        let c = line2.x - line1.x
        let d = line2.y - line1.y
        if c == 0 && d == 0 { return 0 }
        return sqr(a * d - c * b) / (c * c + d * d)
    }

    /// Returns the squared perpendicular distance from a point to a line (integer).
    public static func perpendicDistFromLineSqrd(_ pt: Point64, _ line1: Point64, _ line2: Point64) -> Double {
        let a = Double(pt.x) - Double(line1.x)
        let b = Double(pt.y) - Double(line1.y)
        let c = Double(line2.x) - Double(line1.x)
        let d = Double(line2.y) - Double(line1.y)
        if c == 0 && d == 0 { return 0 }
        return sqr(a * d - c * b) / (c * c + d * d)
    }

    // MARK: - Ramer-Douglas-Peucker

    /// Internal RDP helper for Path64.
    public static func rDP(_ path: Path64, _ begin: Int, _ end: Int, _ epsSqrd: Double, _ flags: inout [Bool]) {
        var begin = begin
        var end = end
        while true {
            var idx = 0
            var maxD = 0.0
            while end > begin && path[begin] == path[end] {
                flags[end] = false
                end -= 1
            }
            for i in (begin + 1)..<end {
                let d = perpendicDistFromLineSqrd(path[i], path[begin], path[end])
                if d <= maxD { continue }
                maxD = d
                idx = i
            }
            if maxD <= epsSqrd { return }
            flags[idx] = true
            if idx > begin + 1 {
                rDP(path, begin, idx, epsSqrd, &flags)
            }
            if idx < end - 1 {
                begin = idx
                continue
            }
            break
        }
    }

    /// Simplifies a Path64 using the Ramer-Douglas-Peucker algorithm.
    public static func ramerDouglasPeuckerPath(_ path: Path64, _ epsilon: Double) -> Path64 {
        let len = path.count
        if len < 5 { return path }
        var flags = [Bool](repeating: false, count: len)
        flags[0] = true
        flags[len - 1] = true
        rDP(path, 0, len - 1, sqr(epsilon), &flags)
        var result = Path64()
        result.reserveCapacity(len)
        for i in 0..<len {
            if flags[i] { result.append(path[i]) }
        }
        return result
    }

    /// Simplifies Paths64 using the Ramer-Douglas-Peucker algorithm.
    public static func ramerDouglasPeucker(_ paths: Paths64, _ epsilon: Double) -> Paths64 {
        var result = Paths64()
        result.reserveCapacity(paths.count)
        for path in paths {
            result.append(ramerDouglasPeuckerPath(path, epsilon))
        }
        return result
    }

    /// Internal RDP helper for PathD.
    public static func rDP(_ path: PathD, _ begin: Int, _ end: Int, _ epsSqrd: Double, _ flags: inout [Bool]) {
        var begin = begin
        var end = end
        while true {
            var idx = 0
            var maxD = 0.0
            while end > begin && path[begin] == path[end] {
                flags[end] = false
                end -= 1
            }
            for i in (begin + 1)..<end {
                let d = perpendicDistFromLineSqrd(path[i], path[begin], path[end])
                if d <= maxD { continue }
                maxD = d
                idx = i
            }
            if maxD <= epsSqrd { return }
            flags[idx] = true
            if idx > begin + 1 {
                rDP(path, begin, idx, epsSqrd, &flags)
            }
            if idx < end - 1 {
                begin = idx
                continue
            }
            break
        }
    }

    /// Simplifies a PathD using the Ramer-Douglas-Peucker algorithm.
    public static func ramerDouglasPeucker(_ path: PathD, _ epsilon: Double) -> PathD {
        let len = path.count
        if len < 5 { return path }
        var flags = [Bool](repeating: false, count: len)
        flags[0] = true
        flags[len - 1] = true
        rDP(path, 0, len - 1, sqr(epsilon), &flags)
        var result = PathD()
        result.reserveCapacity(len)
        for i in 0..<len {
            if flags[i] { result.append(path[i]) }
        }
        return result
    }

    /// Simplifies PathsD using the Ramer-Douglas-Peucker algorithm.
    public static func ramerDouglasPeucker(_ paths: PathsD, _ epsilon: Double) -> PathsD {
        var result = PathsD()
        result.reserveCapacity(paths.count)
        for path in paths {
            result.append(ramerDouglasPeucker(path, epsilon))
        }
        return result
    }

    // MARK: - SimplifyPath helpers

    private static func getNext(_ current: Int, _ high: Int, _ flags: [Bool]) -> Int {
        var current = current + 1
        while current <= high && flags[current] {
            current += 1
        }
        if current <= high { return current }
        current = 0
        while flags[current] {
            current += 1
        }
        return current
    }

    private static func getPrior(_ current: Int, _ high: Int, _ flags: [Bool]) -> Int {
        var current = current
        if current == 0 {
            current = high
        } else {
            current -= 1
        }
        while current > 0 && flags[current] {
            current -= 1
        }
        if !flags[current] { return current }
        current = high
        while flags[current] {
            current -= 1
        }
        return current
    }

    // MARK: - Simplify Paths

    /// Simplifies a Path64 (assumes open path by default).
    public static func simplifyPath(_ path: Path64, _ epsilon: Double) -> Path64 {
        return simplifyPath(path, epsilon, false)
    }

    /// Simplifies a Path64 by removing vertices closer than epsilon to the line through adjacent vertices.
    public static func simplifyPath(_ path: Path64, _ epsilon: Double, _ isClosedPath: Bool) -> Path64 {
        let len = path.count
        let high = len - 1
        let epsSqr = sqr(epsilon)
        if len < 4 { return path }

        var flags = [Bool](repeating: false, count: len)
        var dsq = [Double](repeating: 0, count: len)
        var curr = 0

        if isClosedPath {
            dsq[0] = perpendicDistFromLineSqrd(path[0], path[high], path[1])
            dsq[high] = perpendicDistFromLineSqrd(path[high], path[0], path[high - 1])
        } else {
            dsq[0] = Double.greatestFiniteMagnitude
            dsq[high] = Double.greatestFiniteMagnitude
        }

        for i in 1..<high {
            dsq[i] = perpendicDistFromLineSqrd(path[i], path[i - 1], path[i + 1])
        }

        while true {
            if dsq[curr] > epsSqr {
                let start = curr
                repeat {
                    curr = getNext(curr, high, flags)
                } while curr != start && dsq[curr] > epsSqr
                if curr == start { break }
            }

            let prev = getPrior(curr, high, flags)
            var next = getNext(curr, high, flags)
            if next == prev { break }

            var prior2: Int
            var prevVar = prev
            if dsq[next] < dsq[curr] {
                prior2 = prevVar
                prevVar = curr
                curr = next
                next = getNext(next, high, flags)
            } else {
                prior2 = getPrior(prevVar, high, flags)
            }

            flags[curr] = true
            curr = next
            next = getNext(next, high, flags)

            if isClosedPath || (curr != high && curr != 0) {
                dsq[curr] = perpendicDistFromLineSqrd(path[curr], path[prevVar], path[next])
            }
            if isClosedPath || (prevVar != 0 && prevVar != high) {
                dsq[prevVar] = perpendicDistFromLineSqrd(path[prevVar], path[prior2], path[curr])
            }
        }

        var result = Path64()
        result.reserveCapacity(len)
        for i in 0..<len {
            if !flags[i] { result.append(path[i]) }
        }
        return result
    }

    /// Simplifies multiple Path64 (assumes open paths by default).
    public static func simplifyPaths(_ paths: Paths64, _ epsilon: Double) -> Paths64 {
        return simplifyPaths(paths, epsilon, false)
    }

    /// Simplifies multiple Path64.
    public static func simplifyPaths(_ paths: Paths64, _ epsilon: Double, _ isClosedPath: Bool) -> Paths64 {
        var result = Paths64()
        result.reserveCapacity(paths.count)
        for path in paths {
            result.append(simplifyPath(path, epsilon, isClosedPath))
        }
        return result
    }

    /// Simplifies a PathD (assumes open path by default).
    public static func simplifyPath(_ path: PathD, _ epsilon: Double) -> PathD {
        return simplifyPath(path, epsilon, false)
    }

    /// Simplifies a PathD by removing vertices closer than epsilon to the line through adjacent vertices.
    public static func simplifyPath(_ path: PathD, _ epsilon: Double, _ isClosedPath: Bool) -> PathD {
        let len = path.count
        let high = len - 1
        let epsSqr = sqr(epsilon)
        if len < 4 { return path }

        var flags = [Bool](repeating: false, count: len)
        var dsq = [Double](repeating: 0, count: len)
        var curr = 0

        if isClosedPath {
            dsq[0] = perpendicDistFromLineSqrd(path[0], path[high], path[1])
            dsq[high] = perpendicDistFromLineSqrd(path[high], path[0], path[high - 1])
        } else {
            dsq[0] = Double.greatestFiniteMagnitude
            dsq[high] = Double.greatestFiniteMagnitude
        }

        for i in 1..<high {
            dsq[i] = perpendicDistFromLineSqrd(path[i], path[i - 1], path[i + 1])
        }

        while true {
            if dsq[curr] > epsSqr {
                let start = curr
                repeat {
                    curr = getNext(curr, high, flags)
                } while curr != start && dsq[curr] > epsSqr
                if curr == start { break }
            }

            let prev = getPrior(curr, high, flags)
            var next = getNext(curr, high, flags)
            if next == prev { break }

            var prior2: Int
            var prevVar = prev
            if dsq[next] < dsq[curr] {
                prior2 = prevVar
                prevVar = curr
                curr = next
                next = getNext(next, high, flags)
            } else {
                prior2 = getPrior(prevVar, high, flags)
            }

            flags[curr] = true
            curr = next
            next = getNext(next, high, flags)

            if isClosedPath || (curr != high && curr != 0) {
                dsq[curr] = perpendicDistFromLineSqrd(path[curr], path[prevVar], path[next])
            }
            if isClosedPath || (prevVar != 0 && prevVar != high) {
                dsq[prevVar] = perpendicDistFromLineSqrd(path[prevVar], path[prior2], path[curr])
            }
        }

        var result = PathD()
        result.reserveCapacity(len)
        for i in 0..<len {
            if !flags[i] { result.append(path[i]) }
        }
        return result
    }

    /// Simplifies multiple PathD (assumes open paths by default).
    public static func simplifyPaths(_ paths: PathsD, _ epsilon: Double) -> PathsD {
        return simplifyPaths(paths, epsilon, false)
    }

    /// Simplifies multiple PathD.
    public static func simplifyPaths(_ paths: PathsD, _ epsilon: Double, _ isClosedPath: Bool) -> PathsD {
        var result = PathsD()
        result.reserveCapacity(paths.count)
        for path in paths {
            result.append(simplifyPath(path, epsilon, isClosedPath))
        }
        return result
    }

    // MARK: - Trim Collinear

    /// Removes collinear and duplicate vertices from an integer path (closed by default).
    public static func trimCollinear(_ path: Path64, isOpen: Bool = false) -> Path64 {
        var len = path.count
        var i = 0
        if !isOpen {
            while i < len - 1 && InternalClipper.isCollinear(path[len - 1], path[i], path[i + 1]) {
                i += 1
            }
            while i < len - 1 && InternalClipper.isCollinear(path[len - 2], path[len - 1], path[i]) {
                len -= 1
            }
        }

        if len - i < 3 {
            if !isOpen || len < 2 || path[0] == path[1] {
                return Path64()
            }
            return path
        }

        var result = Path64()
        result.reserveCapacity(len - i)
        var last = path[i]
        result.append(last)
        i += 1
        while i < len - 1 {
            if InternalClipper.isCollinear(last, path[i], path[i + 1]) {
                i += 1
                continue
            }
            last = path[i]
            result.append(last)
            i += 1
        }

        if isOpen {
            result.append(path[len - 1])
        } else if !InternalClipper.isCollinear(last, path[len - 1], result[0]) {
            result.append(path[len - 1])
        } else {
            while result.count > 2 && InternalClipper.isCollinear(result[result.count - 1], result[result.count - 2], result[0]) {
                result.removeLast()
            }
            if result.count < 3 {
                result.removeAll()
            }
        }
        return result
    }

    /// Removes collinear and duplicate vertices from a floating-point path (closed by default).
    public static func trimCollinear(_ path: PathD, _ precision: Int, isOpen: Bool = false) throws -> PathD {
        try InternalClipper.checkPrecision(precision)
        let scale = pow(10.0, Double(precision))
        var p = scalePath64(path, scale)
        p = trimCollinear(p, isOpen: isOpen)
        return scalePathD(p, 1.0 / scale)
    }
}
