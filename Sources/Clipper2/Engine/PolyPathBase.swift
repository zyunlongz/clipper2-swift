import Foundation

public class PolyPathBase: Sequence, CustomStringConvertible {
    var parent: PolyPathBase?
    var children: [PolyPathBase] = []

    init(parent: PolyPathBase? = nil) {
        self.parent = parent
    }

    public func makeIterator() -> IndexingIterator<[PolyPathBase]> {
        return children.makeIterator()
    }

    private var level: Int {
        var result = 0
        var pp = parent
        while pp != nil {
            result += 1
            pp = pp?.parent
        }
        return result
    }

    public var isHole: Bool {
        let lvl = level
        return lvl != 0 && (lvl & 1) == 0
    }

    public var count: Int {
        return children.count
    }

    @discardableResult
    public func addChild(_ p: Path64) -> PolyPathBase {
        fatalError("Must be overridden")
    }

    public func clear() {
        children.removeAll()
    }

    private func toStringInternal(_ idx: Int, _ level: Int) -> String {
        let count = children.count
        var result = ""
        let padding = String(repeating: " ", count: level * 2)
        let plural = children.count == 1 ? "" : "s"

        if (level & 1) == 0 {
            result += "\(padding)+- hole (\(idx)) contains \(children.count) nested polygon\(plural).\n"
        } else {
            result += "\(padding)+- polygon (\(idx)) contains \(children.count) hole\(plural).\n"
        }
        for i in 0..<count {
            if children[i].count > 0 {
                result += children[i].toStringInternal(i, level + 1)
            }
        }
        return result
    }

    public var treeDescription: String {
        let count = children.count
        if level > 0 {
            return ""
        }
        let plural = children.count == 1 ? "" : "s"
        var result = "Polytree with \(children.count) polygon\(plural).\n"
        for i in 0..<count {
            if children[i].count > 0 {
                result += children[i].toStringInternal(i, 1)
            }
        }
        result += "\n"
        return result
    }

    public var description: String {
        treeDescription
    }
}
