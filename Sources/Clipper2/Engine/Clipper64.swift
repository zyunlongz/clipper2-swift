public class Clipper64: ClipperBase {

    @discardableResult
    public func execute(_ clipType: ClipType, _ fillRule: FillRule, _ solutionClosed: inout Paths64, _ solutionOpen: inout Paths64) -> Bool {
        solutionClosed.removeAll()
        solutionOpen.removeAll()
        do {
            try executeInternal(clipType, fillRule)
            buildPaths(&solutionClosed, &solutionOpen)
        } catch {
            succeeded = false
        }
        clearSolutionOnly()
        return succeeded
    }

    @discardableResult
    public func execute(_ clipType: ClipType, _ fillRule: FillRule, _ solutionClosed: inout Paths64) -> Bool {
        var solutionOpen: Paths64 = []
        return execute(clipType, fillRule, &solutionClosed, &solutionOpen)
    }

    @discardableResult
    public func execute(_ clipType: ClipType, _ fillRule: FillRule, _ polytree: PolyTree64, _ openPaths: inout Paths64) -> Bool {
        polytree.clear()
        openPaths.removeAll()
        usingPolytree = true
        do {
            try executeInternal(clipType, fillRule)
            buildTree(polytree, &openPaths)
        } catch {
            succeeded = false
        }
        clearSolutionOnly()
        return succeeded
    }

    @discardableResult
    public func execute(_ clipType: ClipType, _ fillRule: FillRule, _ polytree: PolyTree64) -> Bool {
        var openPaths: Paths64 = []
        return execute(clipType, fillRule, polytree, &openPaths)
    }

    public override func addReuseableData(_ reuseableData: ReuseableDataContainer64) {
        super.addReuseableData(reuseableData)
    }
}
