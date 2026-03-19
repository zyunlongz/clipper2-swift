import Foundation

public struct RectD {
    public var left: Double
    public var top: Double
    public var right: Double
    public var bottom: Double

    public init() {
        left = 0; top = 0; right = 0; bottom = 0
    }

    public init(_ l: Double, _ t: Double, _ r: Double, _ b: Double) {
        precondition(r >= l && b >= t, "Invalid RectD assignment")
        left = l; top = t; right = r; bottom = b
    }

    public init(_ rec: RectD) {
        left = rec.left; top = rec.top; right = rec.right; bottom = rec.bottom
    }

    public init(isValid: Bool) {
        if isValid {
            left = 0; top = 0; right = 0; bottom = 0
        } else {
            left = Double.greatestFiniteMagnitude; top = Double.greatestFiniteMagnitude
            right = -Double.greatestFiniteMagnitude; bottom = -Double.greatestFiniteMagnitude
        }
    }

    public static var invalid: RectD {
        return RectD(isValid: false)
    }

    public var width: Double {
        get { return right - left }
        set { right = left + newValue }
    }

    public var height: Double {
        get { return bottom - top }
        set { bottom = top + newValue }
    }

    public var isEmpty: Bool {
        return bottom <= top || right <= left
    }

    public func midPoint() -> PointD {
        return PointD((left + right) / 2, (top + bottom) / 2)
    }

    public func contains(_ pt: PointD) -> Bool {
        return pt.x > left && pt.x < right && pt.y > top && pt.y < bottom
    }

    public func contains(_ rec: RectD) -> Bool {
        return rec.left >= left && rec.right <= right && rec.top >= top && rec.bottom <= bottom
    }

    public func intersects(_ rec: RectD) -> Bool {
        return (max(left, rec.left) < min(right, rec.right)) && (max(top, rec.top) < min(bottom, rec.bottom))
    }

    public func asPath() -> PathD {
        return [
            PointD(left, top),
            PointD(right, top),
            PointD(right, bottom),
            PointD(left, bottom),
        ]
    }
}
