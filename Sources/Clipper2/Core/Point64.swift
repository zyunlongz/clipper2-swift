import Foundation

public struct Point64: Equatable, Hashable, CustomStringConvertible {
    public var x: Int64
    public var y: Int64

    public init() {
        self.x = 0
        self.y = 0
    }

    public init(_ x: Int64, _ y: Int64) {
        self.x = x
        self.y = y
    }

    public init(_ pt: Point64) {
        self.x = pt.x
        self.y = pt.y
    }

    public init(_ x: Double, _ y: Double) {
        self.x = Int64(x.rounded())
        self.y = Int64(y.rounded())
    }

    public init(_ pt: PointD) {
        self.x = Int64(pt.x.rounded())
        self.y = Int64(pt.y.rounded())
    }

    public init(_ pt: Point64, scale: Double) {
        self.x = Int64((Double(pt.x) * scale).rounded())
        self.y = Int64((Double(pt.y) * scale).rounded())
    }

    public init(_ pt: PointD, scale: Double) {
        self.x = Int64((pt.x * scale).rounded())
        self.y = Int64((pt.y * scale).rounded())
    }

    public static func + (lhs: Point64, rhs: Point64) -> Point64 {
        return Point64(lhs.x + rhs.x, lhs.y + rhs.y)
    }

    public static func - (lhs: Point64, rhs: Point64) -> Point64 {
        return Point64(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    public var description: String {
        return "(\(x),\(y)) "
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(x &* 31 &+ y)
    }
}
