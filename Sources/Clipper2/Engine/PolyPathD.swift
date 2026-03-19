public class PolyPathD: PolyPathBase {
    private(set) var polygon: PathD?
    public var scale: Double = 0

    override init(parent: PolyPathBase? = nil) {
        super.init(parent: parent)
    }

    @discardableResult
    public override func addChild(_ p: Path64) -> PolyPathBase {
        let newChild = PolyPathD(parent: self)
        newChild.scale = scale
        newChild.polygon = Clipper.scalePathD(p, scale)
        children.append(newChild)
        return newChild
    }

    public func get(_ index: Int) -> PolyPathD {
        precondition(index >= 0 && index < children.count)
        return children[index] as! PolyPathD
    }

    public func area() -> Double {
        var result: Double = polygon != nil ? Clipper.area(polygon!) : 0
        for child in children {
            let pp = child as! PolyPathD
            result += pp.area()
        }
        return result
    }

    public func getPolygon() -> PathD? {
        return polygon
    }
}
