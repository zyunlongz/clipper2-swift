public typealias Path64 = [Point64]
public typealias PathD = [PointD]
public typealias Paths64 = [Path64]
public typealias PathsD = [PathD]

extension Array where Element == Point64 {
    public var pathDescription: String {
        return self.map { String($0.description.dropLast()) }.joined(separator: ", ")
    }
}

extension Array where Element == PointD {
    public var pathDescription: String {
        return self.map { String($0.description.dropLast()) }.joined(separator: ", ")
    }
}

extension Array where Element == Path64 {
    public var pathsDescription: String {
        return self.map { $0.pathDescription }.joined(separator: "\n")
    }
}

extension Array where Element == PathD {
    public var pathsDescription: String {
        return self.map { $0.pathDescription }.joined(separator: "\n")
    }
}
