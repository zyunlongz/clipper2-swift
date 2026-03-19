import Foundation

public struct PointD: Equatable, Hashable, CustomStringConvertible {
    public var x: Double
    public var y: Double

    public init() {
        self.x = 0
        self.y = 0
    }

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public init(_ pt: PointD) {
        self.x = pt.x
        self.y = pt.y
    }

    public init(_ pt: Point64) {
        self.x = Double(pt.x)
        self.y = Double(pt.y)
    }

    public init(_ pt: PointD, scale: Double) {
        self.x = pt.x * scale
        self.y = pt.y * scale
    }

    public init(_ pt: Point64, scale: Double) {
        self.x = Double(pt.x) * scale
        self.y = Double(pt.y) * scale
    }

    public init(_ x: Int64, _ y: Int64) {
        self.x = Double(x)
        self.y = Double(y)
    }

    public mutating func negate() {
        x = -x
        y = -y
    }

    public static func == (lhs: PointD, rhs: PointD) -> Bool {
        return InternalClipper.isAlmostZero(lhs.x - rhs.x) && InternalClipper.isAlmostZero(lhs.y - rhs.y)
    }

    public static func != (lhs: PointD, rhs: PointD) -> Bool {
        return !InternalClipper.isAlmostZero(lhs.x - rhs.x) || !InternalClipper.isAlmostZero(lhs.y - rhs.y)
    }

    public var description: String {
        return String(format: "(%.6f,%.6f) ", locale: Locale(identifier: "en_US_POSIX"), x, y)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(x * 31 + y)
    }
}
