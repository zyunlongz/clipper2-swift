public class PolyPath64: PolyPathBase {
    private(set) var polygon: Path64?

    public override init(parent: PolyPathBase? = nil) {
        super.init(parent: parent)
    }

    @discardableResult
    public override func addChild(_ p: Path64) -> PolyPathBase {
        let newChild = PolyPath64(parent: self)
        newChild.polygon = p
        children.append(newChild)
        return newChild
    }

    public func get(_ index: Int) -> PolyPath64 {
        precondition(index >= 0 && index < children.count)
        return children[index] as! PolyPath64
    }

    public func area() -> Double {
        var result: Double = polygon != nil ? Clipper.area(polygon!) : 0
        for child in children {
            let pp = child as! PolyPath64
            result += pp.area()
        }
        return result
    }

    public func getPolygon() -> Path64? {
        return polygon
    }
}
