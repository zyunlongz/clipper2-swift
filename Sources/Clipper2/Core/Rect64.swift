import Foundation

public struct Rect64 {
    public var left: Int64
    public var top: Int64
    public var right: Int64
    public var bottom: Int64

    public init() {
        left = 0; top = 0; right = 0; bottom = 0
    }

    public init(_ l: Int64, _ t: Int64, _ r: Int64, _ b: Int64) {
        precondition(r >= l && b >= t, "Invalid Rect64 assignment")
        left = l; top = t; right = r; bottom = b
    }

    public init(isValid: Bool) {
        if isValid {
            left = 0; top = 0; right = 0; bottom = 0
        } else {
            left = Int64.max; top = Int64.max
            right = Int64.min; bottom = Int64.min
        }
    }

    public init(_ rec: Rect64) {
        left = rec.left; top = rec.top; right = rec.right; bottom = rec.bottom
    }

    public static var invalid: Rect64 {
        return Rect64(isValid: false)
    }

    public var width: Int64 {
        get { return right - left }
        set { right = left + newValue }
    }

    public var height: Int64 {
        get { return bottom - top }
        set { bottom = top + newValue }
    }

    public func asPath() -> Path64 {
        return [
            Point64(left, top),
            Point64(right, top),
            Point64(right, bottom),
            Point64(left, bottom),
        ]
    }

    public var isEmpty: Bool {
        return bottom <= top || right <= left
    }

    public var isValid: Bool {
        return left < Int64.max
    }

    public func midPoint() -> Point64 {
        return Point64((left + right) / 2, (top + bottom) / 2)
    }

    public func contains(_ pt: Point64) -> Bool {
        return pt.x > left && pt.x < right && pt.y > top && pt.y < bottom
    }

    public func intersects(_ rec: Rect64) -> Bool {
        return (max(left, rec.left) <= min(right, rec.right)) && (max(top, rec.top) <= min(bottom, rec.bottom))
    }

    public func contains(_ rec: Rect64) -> Bool {
        return rec.left >= left && rec.right <= right && rec.top >= top && rec.bottom <= bottom
    }

    public static func + (lhs: Rect64, rhs: Rect64) -> Rect64 {
        if !lhs.isValid { return rhs }
        if !rhs.isValid { return lhs }
        return Rect64(min(lhs.left, rhs.left), min(lhs.top, rhs.top),
                       max(lhs.right, rhs.right), max(lhs.bottom, rhs.bottom))
    }
}
