import Foundation

public class ClipperD: ClipperBase {

    private var scale: Double
    private var invScale: Double

    public init(roundingDecimalPrecision: Int = 2) throws {
        try InternalClipper.checkPrecision(roundingDecimalPrecision)
        scale = pow(10.0, Double(roundingDecimalPrecision))
        invScale = 1.0 / scale
        super.init()
    }

    public func addPath(_ path: PathD, _ polytype: PathType) {
        addPath(path, polytype, isOpen: false)
    }

    public func addPath(_ path: PathD, _ polytype: PathType, isOpen: Bool) {
        super.addPath(Clipper.scalePath64(path, scale), polytype, isOpen: isOpen)
    }

    public func addPaths(_ paths: PathsD, _ polytype: PathType) {
        addPaths(paths, polytype, isOpen: false)
    }

    public func addPaths(_ paths: PathsD, _ polytype: PathType, isOpen: Bool) {
        super.addPaths(Clipper.scalePaths64(paths, scale), polytype, isOpen: isOpen)
    }

    public func addSubject(_ path: PathD) {
        addPath(path, .subject)
    }

    public func addOpenSubject(_ path: PathD) {
        addPath(path, .subject, isOpen: true)
    }

    public func addClip(_ path: PathD) {
        addPath(path, .clip)
    }

    public func addSubjects(_ paths: PathsD) {
        addPaths(paths, .subject)
    }

    public func addOpenSubjects(_ paths: PathsD) {
        addPaths(paths, .subject, isOpen: true)
    }

    public func addClips(_ paths: PathsD) {
        addPaths(paths, .clip)
    }

    @discardableResult
    public func execute(_ clipType: ClipType, _ fillRule: FillRule, _ solutionClosed: inout PathsD, _ solutionOpen: inout PathsD) -> Bool {
        var solClosed64: Paths64 = []
        var solOpen64: Paths64 = []

        var success = true
        solutionClosed.removeAll()
        solutionOpen.removeAll()
        do {
            try executeInternal(clipType, fillRule)
            buildPaths(&solClosed64, &solOpen64)
        } catch {
            success = false
        }

        clearSolutionOnly()
        if !success { return false }

        solutionClosed.reserveCapacity(solClosed64.count)
        for path in solClosed64 {
            solutionClosed.append(Clipper.scalePathD(path, invScale))
        }
        solutionOpen.reserveCapacity(solOpen64.count)
        for path in solOpen64 {
            solutionOpen.append(Clipper.scalePathD(path, invScale))
        }

        return true
    }

    @discardableResult
    public func execute(_ clipType: ClipType, _ fillRule: FillRule, _ solutionClosed: inout PathsD) -> Bool {
        var solutionOpen: PathsD = []
        return execute(clipType, fillRule, &solutionClosed, &solutionOpen)
    }

    @discardableResult
    public func execute(_ clipType: ClipType, _ fillRule: FillRule, _ polytree: PolyTreeD, _ openPaths: inout PathsD) -> Bool {
        polytree.clear()
        polytree.scale = invScale
        openPaths.removeAll()
        var oPaths: Paths64 = []
        var success = true
        do {
            try executeInternal(clipType, fillRule)
            buildTree(polytree, &oPaths)
        } catch {
            success = false
        }
        clearSolutionOnly()
        if !success { return false }
        if oPaths.isEmpty { return true }
        openPaths.reserveCapacity(oPaths.count)
        for path in oPaths {
            openPaths.append(Clipper.scalePathD(path, invScale))
        }
        return true
    }

    @discardableResult
    public func execute(_ clipType: ClipType, _ fillRule: FillRule, _ polytree: PolyTreeD) -> Bool {
        var openPaths: PathsD = []
        return execute(clipType, fillRule, polytree, &openPaths)
    }
}
