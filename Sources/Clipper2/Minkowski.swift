import Foundation

public enum Minkowski {

    public static func sum(_ pattern: Path64, _ path: Path64, isClosed: Bool) -> Paths64 {
        return Clipper.union(minkowskiInternal(pattern, path, isSum: true, isClosed: isClosed), .nonZero)
    }

    public static func sum(_ pattern: PathD, _ path: PathD, isClosed: Bool, decimalPlaces: Int = 2) -> PathsD {
        let scale = pow(10.0, Double(decimalPlaces))
        let tmp = Clipper.union(
            minkowskiInternal(Clipper.scalePath64(pattern, scale), Clipper.scalePath64(path, scale), isSum: true, isClosed: isClosed),
            .nonZero
        )
        return Clipper.scalePathsD(tmp, 1.0 / scale)
    }

    public static func diff(_ pattern: Path64, _ path: Path64, isClosed: Bool) -> Paths64 {
        return Clipper.union(minkowskiInternal(pattern, path, isSum: false, isClosed: isClosed), .nonZero)
    }

    public static func diff(_ pattern: PathD, _ path: PathD, isClosed: Bool, decimalPlaces: Int = 2) -> PathsD {
        let scale = pow(10.0, Double(decimalPlaces))
        let tmp = Clipper.union(
            minkowskiInternal(Clipper.scalePath64(pattern, scale), Clipper.scalePath64(path, scale), isSum: false, isClosed: isClosed),
            .nonZero
        )
        return Clipper.scalePathsD(tmp, 1.0 / scale)
    }

    private static func minkowskiInternal(_ pattern: Path64, _ path: Path64, isSum: Bool, isClosed: Bool) -> Paths64 {
        let delta = isClosed ? 0 : 1
        let patLen = pattern.count
        let pathLen = path.count
        var tmp: Paths64 = []
        tmp.reserveCapacity(pathLen)

        for pathPt in path {
            var path2: Path64 = []
            path2.reserveCapacity(patLen)
            if isSum {
                for basePt in pattern {
                    path2.append(pathPt + basePt)
                }
            } else {
                for basePt in pattern {
                    path2.append(pathPt - basePt)
                }
            }
            tmp.append(path2)
        }

        var result: Paths64 = []
        result.reserveCapacity((pathLen - delta) * patLen)
        var g = isClosed ? pathLen - 1 : 0

        var h = patLen - 1
        for i in delta..<pathLen {
            for j in 0..<patLen {
                var quad: Path64 = [tmp[g][h], tmp[i][h], tmp[i][j], tmp[g][j]]
                if !Clipper.isPositive(quad) {
                    quad.reverse()
                }
                result.append(quad)
                h = j
            }
            g = i
        }
        return result
    }
}
