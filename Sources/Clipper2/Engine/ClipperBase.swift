import Foundation

// MARK: - Supporting Types

struct VertexFlags: OptionSet {
    let rawValue: Int

    static let none      = VertexFlags([])
    static let openStart = VertexFlags(rawValue: 1)
    static let openEnd   = VertexFlags(rawValue: 2)
    static let localMax  = VertexFlags(rawValue: 4)
    static let localMin  = VertexFlags(rawValue: 8)
}

enum JoinWith {
    case none, left, right
}

enum HorzPosition {
    case bottom, middle, top
}

// MARK: - ClipperBase

open class ClipperBase {

    // MARK: Nested Types

    class Vertex {
        var pt: Point64 = Point64()
        var next: Vertex?
        var prev: Vertex?
        var flags: VertexFlags

        init(pt: Point64, flags: VertexFlags, prev: Vertex?) {
            self.pt = pt
            self.flags = flags
            self.next = nil
            self.prev = prev
        }
    }

    class OutRec {
        var idx: Int = 0
        var owner: OutRec?
        var frontEdge: Active?
        var backEdge: Active?
        var pts: OutPt?
        var polypath: PolyPathBase?
        var bounds: Rect64 = Rect64()
        var path: Path64 = []
        var isOpen: Bool = false
        var splits: [Int]? = nil
        var recursiveSplit: OutRec? = nil
    }

    class OutPt {
        var pt: Point64
        var next: OutPt!
        var prev: OutPt!
        var outrec: OutRec
        var horz: HorzSegment?

        init(pt: Point64, outrec: OutRec) {
            self.pt = pt
            self.outrec = outrec
            self.horz = nil
            self.next = self
            self.prev = self
        }
    }

    class Active {
        var bot: Point64 = Point64()
        var top: Point64 = Point64()
        var curX: Int64 = 0
        var dx: Double = 0
        var windDx: Int = 0
        var windCount: Int = 0
        var windCount2: Int = 0
        var outrec: OutRec?
        var prevInAEL: Active?
        var nextInAEL: Active?
        var prevInSEL: Active?
        var nextInSEL: Active?
        var jump: Active?
        var vertexTop: Vertex!
        var localMin: LocalMinima = LocalMinima()
        var isLeftBound: Bool = false
        var joinWith: JoinWith = .none
    }

    class IntersectNode {
        let pt: Point64
        let edge1: Active
        let edge2: Active

        init(pt: Point64, edge1: Active, edge2: Active) {
            self.pt = pt
            self.edge1 = edge1
            self.edge2 = edge2
        }
    }

    class HorzSegment {
        var leftOp: OutPt?
        var rightOp: OutPt?
        var leftToRight: Bool

        init(op: OutPt) {
            leftOp = op
            rightOp = nil
            leftToRight = true
        }
    }

    class HorzJoin {
        var op1: OutPt?
        var op2: OutPt?

        init(ltor: OutPt, rtol: OutPt) {
            op1 = ltor
            op2 = rtol
        }
    }

    // MARK: ScanlineSet

    struct ScanlineSet {
        private var storage: [Int64] = []

        mutating func insert(_ y: Int64) {
            let idx = storage.firstIndex(where: { $0 >= y }) ?? storage.endIndex
            if idx < storage.count && storage[idx] == y { return }
            storage.insert(y, at: idx)
        }

        mutating func pollLast() -> Int64? { storage.popLast() }
        var isEmpty: Bool { storage.isEmpty }
        mutating func clear() { storage.removeAll() }
    }

    // MARK: ReuseableDataContainer64

    public class ReuseableDataContainer64 {
        var minimaList: [LocalMinima] = []
        var vertexList: [Vertex] = []

        public init() {}

        public func clear() {
            minimaList.removeAll()
            vertexList.removeAll()
        }

        public func addPaths(_ paths: Paths64, _ pt: PathType, isOpen: Bool) {
            ClipperEngine.addPathsToVertexList(paths, polytype: pt, isOpen: isOpen,
                                               minimaList: &minimaList, vertexList: &vertexList)
        }
    }

    // MARK: ClipperEngine (static helpers)

    private enum ClipperEngine {

        static func addLocMin(_ vert: Vertex, _ polytype: PathType, _ isOpen: Bool,
                              _ minimaList: inout [LocalMinima]) {
            if vert.flags.contains(.localMin) { return }
            vert.flags.insert(.localMin)
            let lm = LocalMinima(vertex: vert, polytype: polytype, isOpen: isOpen)
            minimaList.append(lm)
        }

        static func addPathsToVertexList(_ paths: Paths64, polytype: PathType, isOpen: Bool,
                                         minimaList: inout [LocalMinima],
                                         vertexList: inout [Vertex]) {
            var totalVertCnt = 0
            for path in paths { totalVertCnt += path.count }
            vertexList.reserveCapacity(vertexList.count + totalVertCnt)

            for path in paths {
                var v0: Vertex? = nil
                var prevV: Vertex? = nil

                for pt in path {
                    if v0 == nil {
                        let v = Vertex(pt: pt, flags: .none, prev: nil)
                        vertexList.append(v)
                        v0 = v
                        prevV = v
                    } else if prevV!.pt != pt {
                        let currV = Vertex(pt: pt, flags: .none, prev: prevV)
                        vertexList.append(currV)
                        prevV!.next = currV
                        prevV = currV
                    }
                }

                guard let pV = prevV, pV.prev != nil else { continue }
                guard let v0 = v0 else { continue }

                var prevVUnwrapped = pV
                if !isOpen && v0.pt == prevVUnwrapped.pt {
                    prevVUnwrapped = prevVUnwrapped.prev!
                }
                prevVUnwrapped.next = v0
                v0.prev = prevVUnwrapped
                if !isOpen && prevVUnwrapped === prevVUnwrapped.next { continue }

                var goingup: Bool
                let goingup0: Bool

                if isOpen {
                    var currV: Vertex = v0.next!
                    while currV !== v0 && currV.pt.y == v0.pt.y {
                        currV = currV.next!
                    }
                    goingup = currV.pt.y <= v0.pt.y
                    if goingup {
                        v0.flags = .openStart
                        addLocMin(v0, polytype, true, &minimaList)
                    } else {
                        v0.flags = [.openStart, .localMax]
                    }
                } else {
                    prevVUnwrapped = v0.prev!
                    while prevVUnwrapped !== v0 && prevVUnwrapped.pt.y == v0.pt.y {
                        prevVUnwrapped = prevVUnwrapped.prev!
                    }
                    if prevVUnwrapped === v0 { continue }
                    goingup = prevVUnwrapped.pt.y > v0.pt.y
                }

                goingup0 = goingup
                prevVUnwrapped = v0
                var currV: Vertex = v0.next!
                while currV !== v0 {
                    if currV.pt.y > prevVUnwrapped.pt.y && goingup {
                        prevVUnwrapped.flags.insert(.localMax)
                        goingup = false
                    } else if currV.pt.y < prevVUnwrapped.pt.y && !goingup {
                        goingup = true
                        addLocMin(prevVUnwrapped, polytype, isOpen, &minimaList)
                    }
                    prevVUnwrapped = currV
                    currV = currV.next!
                }

                if isOpen {
                    prevVUnwrapped.flags.insert(.openEnd)
                    if goingup {
                        prevVUnwrapped.flags.insert(.localMax)
                    } else {
                        addLocMin(prevVUnwrapped, polytype, isOpen, &minimaList)
                    }
                } else if goingup != goingup0 {
                    if goingup0 {
                        addLocMin(prevVUnwrapped, polytype, false, &minimaList)
                    } else {
                        prevVUnwrapped.flags.insert(.localMax)
                    }
                }
            }
        }
    }

    // MARK: - Instance Properties

    private var cliptype: ClipType = .noClip
    private var fillrule: FillRule = .evenOdd
    private var actives: Active? = nil
    private var sel: Active? = nil
    private var minimaList: [LocalMinima] = []
    private var intersectList: [IntersectNode] = []
    private var vertexList: [Vertex] = []
    var outrecList: [OutRec] = []
    private var scanlineSet = ScanlineSet()
    private var horzSegList: [HorzSegment] = []
    private var horzJoinList: [HorzJoin] = []
    private var currentLocMin: Int = 0
    private var currentBotY: Int64 = 0
    private var isSortedMinimaList: Bool = false
    private var hasOpenPaths: Bool = false
    var usingPolytree: Bool = false
    var succeeded: Bool = false
    var preserveCollinear: Bool = true
    var reverseSolution: Bool = false

    // MARK: - Init

    public init() {
        self.preserveCollinear = true
    }

    // MARK: - Public Properties

    public final var getPreserveCollinear: Bool {
        return preserveCollinear
    }

    public final func setPreserveCollinear(_ value: Bool) {
        preserveCollinear = value
    }

    public final var getReverseSolution: Bool {
        return reverseSolution
    }

    public final func setReverseSolution(_ value: Bool) {
        reverseSolution = value
    }

    // MARK: - Static Helpers

    private static func isOdd(_ val: Int) -> Bool {
        return (val & 1) != 0
    }

    private static func isHotEdge(_ ae: Active) -> Bool {
        return ae.outrec != nil
    }

    private static func isOpen(_ ae: Active) -> Bool {
        return ae.localMin.isOpen
    }

    private static func isOpenEnd(_ ae: Active) -> Bool {
        return ae.localMin.isOpen && isOpenEnd(ae.vertexTop)
    }

    private static func isOpenEnd(_ v: Vertex) -> Bool {
        return !v.flags.intersection([.openStart, .openEnd]).isEmpty
    }

    private static func getPrevHotEdge(_ ae: Active) -> Active? {
        var prev = ae.prevInAEL
        while prev != nil && (isOpen(prev!) || !isHotEdge(prev!)) {
            prev = prev!.prevInAEL
        }
        return prev
    }

    private static func isFront(_ ae: Active) -> Bool {
        return ae === ae.outrec!.frontEdge
    }

    private static func getDx(_ pt1: Point64, _ pt2: Point64) -> Double {
        let dy = Double(pt2.y - pt1.y)
        if dy != 0 {
            return Double(pt2.x - pt1.x) / dy
        }
        if pt2.x > pt1.x {
            return -.infinity
        }
        return .infinity
    }

    private static func topX(_ ae: Active, _ currentY: Int64) -> Int64 {
        if currentY == ae.top.y || ae.top.x == ae.bot.x {
            return ae.top.x
        }
        if currentY == ae.bot.y {
            return ae.bot.x
        }
        return ae.bot.x + Int64((ae.dx * Double(currentY - ae.bot.y)).rounded())
    }

    private static func isHorizontal(_ ae: Active) -> Bool {
        return ae.top.y == ae.bot.y
    }

    private static func isHeadingRightHorz(_ ae: Active) -> Bool {
        return ae.dx == -.infinity
    }

    private static func isHeadingLeftHorz(_ ae: Active) -> Bool {
        return ae.dx == .infinity
    }

    private static func getPolyType(_ ae: Active) -> PathType {
        return ae.localMin.polytype
    }

    private static func isSamePolyType(_ ae1: Active, _ ae2: Active) -> Bool {
        return ae1.localMin.polytype == ae2.localMin.polytype
    }

    private static func setDx(_ ae: Active) {
        ae.dx = getDx(ae.bot, ae.top)
    }

    private static func nextVertex(_ ae: Active) -> Vertex {
        if ae.windDx > 0 {
            return ae.vertexTop.next!
        }
        return ae.vertexTop.prev!
    }

    private static func prevPrevVertex(_ ae: Active) -> Vertex {
        if ae.windDx > 0 {
            return ae.vertexTop.prev!.prev!
        }
        return ae.vertexTop.next!.next!
    }

    private static func isMaxima(_ vertex: Vertex) -> Bool {
        return vertex.flags.contains(.localMax)
    }

    private static func isMaxima(_ ae: Active) -> Bool {
        return isMaxima(ae.vertexTop)
    }

    private static func getMaximaPair(_ ae: Active) -> Active? {
        var ae2 = ae.nextInAEL
        while ae2 != nil {
            if ae2!.vertexTop === ae.vertexTop {
                return ae2
            }
            ae2 = ae2!.nextInAEL
        }
        return nil
    }

    private static func getCurrYMaximaVertex_Open(_ ae: Active) -> Vertex? {
        var result: Vertex? = ae.vertexTop
        if ae.windDx > 0 {
            while result!.next!.pt.y == result!.pt.y &&
                  result!.flags.intersection([.openEnd, .localMax]).isEmpty {
                result = result!.next
            }
        } else {
            while result!.prev!.pt.y == result!.pt.y &&
                  result!.flags.intersection([.openEnd, .localMax]).isEmpty {
                result = result!.prev
            }
        }
        if !isMaxima(result!) {
            result = nil
        }
        return result
    }

    private static func getCurrYMaximaVertex(_ ae: Active) -> Vertex? {
        var result: Vertex = ae.vertexTop
        if ae.windDx > 0 {
            while result.next!.pt.y == result.pt.y {
                result = result.next!
            }
        } else {
            while result.prev!.pt.y == result.pt.y {
                result = result.prev!
            }
        }
        if !isMaxima(result) {
            return nil
        }
        return result
    }

    private static func setSides(_ outrec: OutRec, _ startEdge: Active, _ endEdge: Active) {
        outrec.frontEdge = startEdge
        outrec.backEdge = endEdge
    }

    private static func swapOutrecs(_ ae1: Active, _ ae2: Active) {
        let or1 = ae1.outrec
        let or2 = ae2.outrec
        if or1 === or2 {
            let ae = or1!.frontEdge
            or1!.frontEdge = or1!.backEdge
            or1!.backEdge = ae
            return
        }

        if or1 != nil {
            if ae1 === or1!.frontEdge {
                or1!.frontEdge = ae2
            } else {
                or1!.backEdge = ae2
            }
        }

        if or2 != nil {
            if ae2 === or2!.frontEdge {
                or2!.frontEdge = ae1
            } else {
                or2!.backEdge = ae1
            }
        }

        ae1.outrec = or2
        ae2.outrec = or1
    }

    private static func setOwner(_ outrec: OutRec, _ newOwner: OutRec) {
        let nOwner = newOwner
        while nOwner.owner != nil && nOwner.owner!.pts == nil {
            nOwner.owner = nOwner.owner!.owner
        }

        var tmp: OutRec? = nOwner
        while tmp != nil && tmp !== outrec {
            tmp = tmp!.owner
        }
        if tmp != nil {
            nOwner.owner = outrec.owner
        }
        outrec.owner = nOwner
    }

    private static func area(_ op: OutPt) -> Double {
        var area = 0.0
        var op2: OutPt = op
        repeat {
            area += Double(op2.prev.pt.y + op2.pt.y) * Double(op2.prev.pt.x - op2.pt.x)
            op2 = op2.next
        } while op2 !== op
        return area * 0.5
    }

    private static func areaTriangle(_ pt1: Point64, _ pt2: Point64, _ pt3: Point64) -> Double {
        return Double(pt3.y + pt1.y) * Double(pt3.x - pt1.x) +
               Double(pt1.y + pt2.y) * Double(pt1.x - pt2.x) +
               Double(pt2.y + pt3.y) * Double(pt2.x - pt3.x)
    }

    private static func getRealOutRec(_ outRec: OutRec?) -> OutRec? {
        var or = outRec
        while or != nil && or!.pts == nil {
            or = or!.owner
        }
        return or
    }

    private static func isValidOwner(_ outRec: OutRec, _ testOwner: OutRec?) -> Bool {
        var to = testOwner
        while to != nil && to !== outRec {
            to = to!.owner
        }
        return to == nil
    }

    private static func uncoupleOutRec(_ ae: Active) {
        guard let outrec = ae.outrec else { return }
        outrec.frontEdge?.outrec = nil
        outrec.backEdge?.outrec = nil
        outrec.frontEdge = nil
        outrec.backEdge = nil
    }

    private static func outrecIsAscending(_ hotEdge: Active) -> Bool {
        return hotEdge === hotEdge.outrec!.frontEdge
    }

    private static func swapFrontBackSides(_ outrec: OutRec) {
        let ae2 = outrec.frontEdge
        outrec.frontEdge = outrec.backEdge
        outrec.backEdge = ae2
        outrec.pts = outrec.pts!.next
    }

    private static func edgesAdjacentInAEL(_ inode: IntersectNode) -> Bool {
        return inode.edge1.nextInAEL === inode.edge2 || inode.edge1.prevInAEL === inode.edge2
    }

    // MARK: - Instance Methods

    final func clearSolutionOnly() {
        while actives != nil {
            deleteFromAEL(actives!)
        }
        scanlineSet.clear()
        disposeIntersectNodes()
        outrecList.removeAll()
        horzSegList.removeAll()
        horzJoinList.removeAll()
    }

    public final func clear() {
        clearSolutionOnly()
        minimaList.removeAll()
        vertexList.removeAll()
        currentLocMin = 0
        isSortedMinimaList = false
        hasOpenPaths = false
    }

    final func reset() {
        if !isSortedMinimaList {
            minimaList.sort { $0.vertex.pt.y > $1.vertex.pt.y }
            isSortedMinimaList = true
        }

        for i in stride(from: minimaList.count - 1, through: 0, by: -1) {
            scanlineSet.insert(minimaList[i].vertex.pt.y)
        }

        currentBotY = 0
        currentLocMin = 0
        actives = nil
        sel = nil
        succeeded = true
    }

    private func hasLocMinAtY(_ y: Int64) -> Bool {
        return currentLocMin < minimaList.count && minimaList[currentLocMin].vertex.pt.y == y
    }

    private func popLocalMinima() -> LocalMinima {
        let lm = minimaList[currentLocMin]
        currentLocMin += 1
        return lm
    }

    // MARK: - Add Paths

    public final func addSubject(_ path: Path64) {
        addPath(path, .subject)
    }

    public final func addSubjects(_ paths: Paths64) {
        for path in paths { addPath(path, .subject) }
    }

    public final func addOpenSubject(_ path: Path64) {
        addPath(path, .subject, isOpen: true)
    }

    public final func addOpenSubjects(_ paths: Paths64) {
        for path in paths { addPath(path, .subject, isOpen: true) }
    }

    public final func addClip(_ path: Path64) {
        addPath(path, .clip)
    }

    public final func addClips(_ paths: Paths64) {
        for path in paths { addPath(path, .clip) }
    }

    public func addPath(_ path: Path64, _ polytype: PathType) {
        addPath(path, polytype, isOpen: false)
    }

    public func addPath(_ path: Path64, _ polytype: PathType, isOpen: Bool) {
        let tmp: Paths64 = [path]
        addPaths(tmp, polytype, isOpen: isOpen)
    }

    public func addPaths(_ paths: Paths64, _ polytype: PathType) {
        addPaths(paths, polytype, isOpen: false)
    }

    public func addPaths(_ paths: Paths64, _ polytype: PathType, isOpen: Bool) {
        if isOpen { hasOpenPaths = true }
        isSortedMinimaList = false
        ClipperEngine.addPathsToVertexList(paths, polytype: polytype, isOpen: isOpen,
                                           minimaList: &minimaList, vertexList: &vertexList)
    }

    func addReuseableData(_ reuseableData: ReuseableDataContainer64) {
        if reuseableData.minimaList.isEmpty { return }
        isSortedMinimaList = false
        for lm in reuseableData.minimaList {
            minimaList.append(LocalMinima(vertex: lm.vertex, polytype: lm.polytype, isOpen: lm.isOpen))
            if lm.isOpen { hasOpenPaths = true }
        }
    }

    // MARK: - Contributing

    private func isContributingClosed(_ ae: Active) -> Bool {
        switch fillrule {
        case .positive:
            if ae.windCount != 1 { return false }
        case .negative:
            if ae.windCount != -1 { return false }
        case .nonZero:
            if abs(ae.windCount) != 1 { return false }
        case .evenOdd:
            break
        }

        switch cliptype {
        case .intersection:
            switch fillrule {
            case .positive:  return ae.windCount2 > 0
            case .negative:  return ae.windCount2 < 0
            default:         return ae.windCount2 != 0
            }
        case .union:
            switch fillrule {
            case .positive:  return ae.windCount2 <= 0
            case .negative:  return ae.windCount2 >= 0
            default:         return ae.windCount2 == 0
            }
        case .difference:
            let result: Bool
            switch fillrule {
            case .positive:  result = ae.windCount2 <= 0
            case .negative:  result = ae.windCount2 >= 0
            default:         result = ae.windCount2 == 0
            }
            return (ClipperBase.getPolyType(ae) == .subject) == result
        case .xor:
            return true
        default:
            return false
        }
    }

    private func isContributingOpen(_ ae: Active) -> Bool {
        let isInSubj: Bool
        let isInClip: Bool
        switch fillrule {
        case .positive:
            isInSubj = ae.windCount > 0
            isInClip = ae.windCount2 > 0
        case .negative:
            isInSubj = ae.windCount < 0
            isInClip = ae.windCount2 < 0
        default:
            isInSubj = ae.windCount != 0
            isInClip = ae.windCount2 != 0
        }

        switch cliptype {
        case .intersection: return isInClip
        case .union:        return !isInSubj && !isInClip
        default:            return !isInClip
        }
    }

    // MARK: - Wind Counts

    private func setWindCountForClosedPathEdge(_ ae: Active) {
        var ae2 = ae.prevInAEL
        let pt = ClipperBase.getPolyType(ae)
        while ae2 != nil && (ClipperBase.getPolyType(ae2!) != pt || ClipperBase.isOpen(ae2!)) {
            ae2 = ae2!.prevInAEL
        }

        if ae2 == nil {
            ae.windCount = ae.windDx
            ae2 = actives
        } else if fillrule == .evenOdd {
            ae.windCount = ae.windDx
            ae.windCount2 = ae2!.windCount2
            ae2 = ae2!.nextInAEL
        } else {
            if ae2!.windCount * ae2!.windDx < 0 {
                if abs(ae2!.windCount) > 1 {
                    if ae2!.windDx * ae.windDx < 0 {
                        ae.windCount = ae2!.windCount
                    } else {
                        ae.windCount = ae2!.windCount + ae.windDx
                    }
                } else {
                    ae.windCount = ClipperBase.isOpen(ae) ? 1 : ae.windDx
                }
            } else if ae2!.windDx * ae.windDx < 0 {
                ae.windCount = ae2!.windCount
            } else {
                ae.windCount = ae2!.windCount + ae.windDx
            }
            ae.windCount2 = ae2!.windCount2
            ae2 = ae2!.nextInAEL
        }

        if fillrule == .evenOdd {
            while ae2 !== ae {
                if ClipperBase.getPolyType(ae2!) != pt && !ClipperBase.isOpen(ae2!) {
                    ae.windCount2 = ae.windCount2 == 0 ? 1 : 0
                }
                ae2 = ae2!.nextInAEL
            }
        } else {
            while ae2 !== ae {
                if ClipperBase.getPolyType(ae2!) != pt && !ClipperBase.isOpen(ae2!) {
                    ae.windCount2 += ae2!.windDx
                }
                ae2 = ae2!.nextInAEL
            }
        }
    }

    private func setWindCountForOpenPathEdge(_ ae: Active) {
        var ae2 = actives
        if fillrule == .evenOdd {
            var cnt1 = 0, cnt2 = 0
            while ae2 !== ae {
                if ClipperBase.getPolyType(ae2!) == .clip {
                    cnt2 += 1
                } else if !ClipperBase.isOpen(ae2!) {
                    cnt1 += 1
                }
                ae2 = ae2!.nextInAEL
            }
            ae.windCount = ClipperBase.isOdd(cnt1) ? 1 : 0
            ae.windCount2 = ClipperBase.isOdd(cnt2) ? 1 : 0
        } else {
            while ae2 !== ae {
                if ClipperBase.getPolyType(ae2!) == .clip {
                    ae.windCount2 += ae2!.windDx
                } else if !ClipperBase.isOpen(ae2!) {
                    ae.windCount += ae2!.windDx
                }
                ae2 = ae2!.nextInAEL
            }
        }
    }

    // MARK: - AEL Order

    private static func isValidAelOrder(_ resident: Active, _ newcomer: Active) -> Bool {
        if newcomer.curX != resident.curX {
            return newcomer.curX > resident.curX
        }

        let d = InternalClipper.crossProductSign(resident.top, newcomer.bot, newcomer.top)
        if d != 0 { return d < 0 }

        if !isMaxima(resident) && resident.top.y > newcomer.top.y {
            return InternalClipper.crossProductSign(newcomer.bot, resident.top, nextVertex(resident).pt) <= 0
        }

        if !isMaxima(newcomer) && newcomer.top.y > resident.top.y {
            return InternalClipper.crossProductSign(newcomer.bot, newcomer.top, nextVertex(newcomer).pt) >= 0
        }

        let y = newcomer.bot.y
        let newcomerIsLeft = newcomer.isLeftBound

        if resident.bot.y != y || resident.localMin.vertex.pt.y != y {
            return newcomer.isLeftBound
        }
        if resident.isLeftBound != newcomerIsLeft {
            return newcomerIsLeft
        }
        if InternalClipper.isCollinear(prevPrevVertex(resident).pt, resident.bot, resident.top) {
            return true
        }
        return (InternalClipper.crossProductSign(prevPrevVertex(resident).pt, newcomer.bot,
                                                  prevPrevVertex(newcomer).pt) > 0) == newcomerIsLeft
    }

    // MARK: - Insert Edges

    private func insertLeftEdge(_ ae: Active) {
        if actives == nil {
            ae.prevInAEL = nil
            ae.nextInAEL = nil
            actives = ae
        } else if !ClipperBase.isValidAelOrder(actives!, ae) {
            ae.prevInAEL = nil
            ae.nextInAEL = actives
            actives!.prevInAEL = ae
            actives = ae
        } else {
            var ae2: Active = actives!
            while ae2.nextInAEL != nil && ClipperBase.isValidAelOrder(ae2.nextInAEL!, ae) {
                ae2 = ae2.nextInAEL!
            }
            if ae2.joinWith == .right {
                ae2 = ae2.nextInAEL!
            }
            ae.nextInAEL = ae2.nextInAEL
            if ae2.nextInAEL != nil {
                ae2.nextInAEL!.prevInAEL = ae
            }
            ae.prevInAEL = ae2
            ae2.nextInAEL = ae
        }
    }

    private func insertRightEdge(_ ae: Active, _ ae2: Active) {
        ae2.nextInAEL = ae.nextInAEL
        if ae.nextInAEL != nil {
            ae.nextInAEL!.prevInAEL = ae2
        }
        ae2.prevInAEL = ae
        ae.nextInAEL = ae2
    }

    // MARK: - Insert Local Minima

    private func insertLocalMinimaIntoAEL(_ botY: Int64) {
        while hasLocMinAtY(botY) {
            let localMinima = popLocalMinima()
            var leftBound: Active?
            var rightBound: Active?

            if !localMinima.vertex.flags.intersection([.openStart]).isEmpty {
                leftBound = nil
            } else {
                let lb = Active()
                lb.bot = localMinima.vertex.pt
                lb.curX = localMinima.vertex.pt.x
                lb.windDx = -1
                lb.vertexTop = localMinima.vertex.prev
                lb.top = localMinima.vertex.prev!.pt
                lb.outrec = nil
                lb.localMin = localMinima
                ClipperBase.setDx(lb)
                leftBound = lb
            }

            if !localMinima.vertex.flags.intersection([.openEnd]).isEmpty {
                rightBound = nil
            } else {
                let rb = Active()
                rb.bot = localMinima.vertex.pt
                rb.curX = localMinima.vertex.pt.x
                rb.windDx = 1
                rb.vertexTop = localMinima.vertex.next
                rb.top = localMinima.vertex.next!.pt
                rb.outrec = nil
                rb.localMin = localMinima
                ClipperBase.setDx(rb)
                rightBound = rb
            }

            if leftBound != nil && rightBound != nil {
                if ClipperBase.isHorizontal(leftBound!) {
                    if ClipperBase.isHeadingRightHorz(leftBound!) {
                        swap(&leftBound, &rightBound)
                    }
                } else if ClipperBase.isHorizontal(rightBound!) {
                    if ClipperBase.isHeadingLeftHorz(rightBound!) {
                        swap(&leftBound, &rightBound)
                    }
                } else if leftBound!.dx < rightBound!.dx {
                    swap(&leftBound, &rightBound)
                }
            } else if leftBound == nil {
                leftBound = rightBound
                rightBound = nil
            }

            let contributing: Bool
            leftBound!.isLeftBound = true
            insertLeftEdge(leftBound!)

            if ClipperBase.isOpen(leftBound!) {
                setWindCountForOpenPathEdge(leftBound!)
                contributing = isContributingOpen(leftBound!)
            } else {
                setWindCountForClosedPathEdge(leftBound!)
                contributing = isContributingClosed(leftBound!)
            }

            if rightBound != nil {
                rightBound!.windCount = leftBound!.windCount
                rightBound!.windCount2 = leftBound!.windCount2
                insertRightEdge(leftBound!, rightBound!)

                if contributing {
                    addLocalMinPoly(leftBound!, rightBound!, leftBound!.bot, isNew: true)
                    if !ClipperBase.isHorizontal(leftBound!) {
                        checkJoinLeft(leftBound!, leftBound!.bot)
                    }
                }

                while rightBound!.nextInAEL != nil &&
                      ClipperBase.isValidAelOrder(rightBound!.nextInAEL!, rightBound!) {
                    intersectEdges(rightBound!, rightBound!.nextInAEL!, rightBound!.bot)
                    swapPositionsInAEL(rightBound!, rightBound!.nextInAEL!)
                }

                if ClipperBase.isHorizontal(rightBound!) {
                    pushHorz(rightBound!)
                } else {
                    checkJoinRight(rightBound!, rightBound!.bot)
                    scanlineSet.insert(rightBound!.top.y)
                }
            } else if contributing {
                startOpenPath(leftBound!, leftBound!.bot)
            }

            if ClipperBase.isHorizontal(leftBound!) {
                pushHorz(leftBound!)
            } else {
                scanlineSet.insert(leftBound!.top.y)
            }
        }
    }

    // MARK: - Horz

    private func pushHorz(_ ae: Active) {
        ae.nextInSEL = sel
        sel = ae
    }

    private func popHorz() -> Active? {
        let ae = sel
        if ae != nil {
            sel = sel!.nextInSEL
        }
        return ae
    }

    // MARK: - Add Local Min/Max Poly

    @discardableResult
    private func addLocalMinPoly(_ ae1: Active, _ ae2: Active, _ pt: Point64, isNew: Bool = false) -> OutPt {
        let outrec = newOutRec()
        ae1.outrec = outrec
        ae2.outrec = outrec

        if ClipperBase.isOpen(ae1) {
            outrec.owner = nil
            outrec.isOpen = true
            if ae1.windDx > 0 {
                ClipperBase.setSides(outrec, ae1, ae2)
            } else {
                ClipperBase.setSides(outrec, ae2, ae1)
            }
        } else {
            outrec.isOpen = false
            let prevHotEdge = ClipperBase.getPrevHotEdge(ae1)
            if prevHotEdge != nil {
                if usingPolytree {
                    ClipperBase.setOwner(outrec, prevHotEdge!.outrec!)
                }
                outrec.owner = prevHotEdge!.outrec
                if ClipperBase.outrecIsAscending(prevHotEdge!) == isNew {
                    ClipperBase.setSides(outrec, ae2, ae1)
                } else {
                    ClipperBase.setSides(outrec, ae1, ae2)
                }
            } else {
                outrec.owner = nil
                if isNew {
                    ClipperBase.setSides(outrec, ae1, ae2)
                } else {
                    ClipperBase.setSides(outrec, ae2, ae1)
                }
            }
        }

        let op = OutPt(pt: pt, outrec: outrec)
        outrec.pts = op
        return op
    }

    @discardableResult
    private func addLocalMaxPoly(_ ae1: Active, _ ae2: Active, _ pt: Point64) -> OutPt? {
        if ClipperBase.isJoined(ae1) { split(ae1, pt) }
        if ClipperBase.isJoined(ae2) { split(ae2, pt) }

        if ClipperBase.isFront(ae1) == ClipperBase.isFront(ae2) {
            if ClipperBase.isOpenEnd(ae1) {
                ClipperBase.swapFrontBackSides(ae1.outrec!)
            } else if ClipperBase.isOpenEnd(ae2) {
                ClipperBase.swapFrontBackSides(ae2.outrec!)
            } else {
                succeeded = false
                return nil
            }
        }

        let result = ClipperBase.addOutPt(ae1, pt)
        if ae1.outrec === ae2.outrec {
            let outrec = ae1.outrec!
            outrec.pts = result

            if usingPolytree {
                let e = ClipperBase.getPrevHotEdge(ae1)
                if e == nil {
                    outrec.owner = nil
                } else {
                    ClipperBase.setOwner(outrec, e!.outrec!)
                }
            }
            ClipperBase.uncoupleOutRec(ae1)
        } else if ClipperBase.isOpen(ae1) {
            if ae1.windDx < 0 {
                ClipperBase.joinOutrecPaths(ae1, ae2)
            } else {
                ClipperBase.joinOutrecPaths(ae2, ae1)
            }
        } else if ae1.outrec!.idx < ae2.outrec!.idx {
            ClipperBase.joinOutrecPaths(ae1, ae2)
        } else {
            ClipperBase.joinOutrecPaths(ae2, ae1)
        }

        return result
    }

    private static func joinOutrecPaths(_ ae1: Active, _ ae2: Active) {
        let p1Start = ae1.outrec!.pts!
        let p2Start = ae2.outrec!.pts!
        let p1End = p1Start.next!
        let p2End = p2Start.next!

        if isFront(ae1) {
            p2End.prev = p1Start
            p1Start.next = p2End
            p2Start.next = p1End
            p1End.prev = p2Start
            ae1.outrec!.pts = p2Start
            ae1.outrec!.frontEdge = ae2.outrec!.frontEdge
            if ae1.outrec!.frontEdge != nil {
                ae1.outrec!.frontEdge!.outrec = ae1.outrec
            }
        } else {
            p1End.prev = p2Start
            p2Start.next = p1End
            p1Start.next = p2End
            p2End.prev = p1Start
            ae1.outrec!.backEdge = ae2.outrec!.backEdge
            if ae1.outrec!.backEdge != nil {
                ae1.outrec!.backEdge!.outrec = ae1.outrec
            }
        }

        ae2.outrec!.frontEdge = nil
        ae2.outrec!.backEdge = nil
        ae2.outrec!.pts = nil
        setOwner(ae2.outrec!, ae1.outrec!)

        if isOpenEnd(ae1) {
            ae2.outrec!.pts = ae1.outrec!.pts
            ae1.outrec!.pts = nil
        }

        ae1.outrec = nil
        ae2.outrec = nil
    }

    private static func addOutPt(_ ae: Active, _ pt: Point64) -> OutPt {
        let outrec = ae.outrec!
        let toFront = isFront(ae)
        let opFront = outrec.pts!
        let opBack = opFront.next!

        if toFront && pt == opFront.pt {
            return opFront
        } else if !toFront && pt == opBack.pt {
            return opBack
        }

        let newOp = OutPt(pt: pt, outrec: outrec)
        opBack.prev = newOp
        newOp.prev = opFront
        newOp.next = opBack
        opFront.next = newOp
        if toFront {
            outrec.pts = newOp
        }
        return newOp
    }

    private func newOutRec() -> OutRec {
        let result = OutRec()
        result.idx = outrecList.count
        outrecList.append(result)
        return result
    }

    @discardableResult
    private func startOpenPath(_ ae: Active, _ pt: Point64) -> OutPt {
        let outrec = newOutRec()
        outrec.isOpen = true
        if ae.windDx > 0 {
            outrec.frontEdge = ae
            outrec.backEdge = nil
        } else {
            outrec.frontEdge = nil
            outrec.backEdge = ae
        }

        ae.outrec = outrec
        let op = OutPt(pt: pt, outrec: outrec)
        outrec.pts = op
        return op
    }

    // MARK: - Update Edge

    private func updateEdgeIntoAEL(_ ae: Active) {
        ae.bot = ae.top
        ae.vertexTop = ClipperBase.nextVertex(ae)
        ae.top = ae.vertexTop.pt
        ae.curX = ae.bot.x
        ClipperBase.setDx(ae)

        if ClipperBase.isJoined(ae) {
            split(ae, ae.bot)
        }

        if ClipperBase.isHorizontal(ae) {
            if !ClipperBase.isOpen(ae) {
                trimHorz(ae, preserveCollinear)
            }
            return
        }
        scanlineSet.insert(ae.top.y)

        checkJoinLeft(ae, ae.bot)
        checkJoinRight(ae, ae.bot, checkCurrX: true)
    }

    private static func findEdgeWithMatchingLocMin(_ e: Active) -> Active? {
        var result = e.nextInAEL
        while result != nil {
            if result!.localMin.vertex === e.localMin.vertex {
                return result
            }
            if !isHorizontal(result!) && e.bot != result!.bot {
                result = nil
            } else {
                result = result!.nextInAEL
            }
        }
        result = e.prevInAEL
        while result != nil {
            if result!.localMin.vertex === e.localMin.vertex {
                return result
            }
            if !isHorizontal(result!) && e.bot != result!.bot {
                return nil
            }
            result = result!.prevInAEL
        }
        return result
    }

    // MARK: - Intersect Edges

    private func intersectEdges(_ ae1: Active, _ ae2: Active, _ pt: Point64) {
        var ae1 = ae1
        var ae2 = ae2

        if hasOpenPaths && (ClipperBase.isOpen(ae1) || ClipperBase.isOpen(ae2)) {
            if ClipperBase.isOpen(ae1) && ClipperBase.isOpen(ae2) { return }
            if ClipperBase.isOpen(ae2) {
                swap(&ae1, &ae2)
            }
            if ClipperBase.isJoined(ae2) { split(ae2, pt) }

            if cliptype == .union {
                if !ClipperBase.isHotEdge(ae2) { return }
            } else if ae2.localMin.polytype == .subject {
                return
            }

            switch fillrule {
            case .positive: if ae2.windCount != 1 { return }
            case .negative: if ae2.windCount != -1 { return }
            default: if abs(ae2.windCount) != 1 { return }
            }

            if ClipperBase.isHotEdge(ae1) {
                ClipperBase.addOutPt(ae1, pt)
                if ClipperBase.isFront(ae1) {
                    ae1.outrec!.frontEdge = nil
                } else {
                    ae1.outrec!.backEdge = nil
                }
                ae1.outrec = nil
            } else if pt == ae1.localMin.vertex.pt && !ClipperBase.isOpenEnd(ae1.localMin.vertex) {
                let ae3 = ClipperBase.findEdgeWithMatchingLocMin(ae1)
                if ae3 != nil && ClipperBase.isHotEdge(ae3!) {
                    ae1.outrec = ae3!.outrec
                    if ae1.windDx > 0 {
                        ClipperBase.setSides(ae3!.outrec!, ae1, ae3!)
                    } else {
                        ClipperBase.setSides(ae3!.outrec!, ae3!, ae1)
                    }
                    return
                }
                startOpenPath(ae1, pt)
            } else {
                startOpenPath(ae1, pt)
            }
            return
        }

        // MANAGING CLOSED PATHS FROM HERE ON
        if ClipperBase.isJoined(ae1) { split(ae1, pt) }
        if ClipperBase.isJoined(ae2) { split(ae2, pt) }

        // UPDATE WINDING COUNTS
        let oldE1WindCount: Int
        let oldE2WindCount: Int

        if ae1.localMin.polytype == ae2.localMin.polytype {
            if fillrule == .evenOdd {
                let tmp = ae1.windCount
                ae1.windCount = ae2.windCount
                ae2.windCount = tmp
            } else {
                if ae1.windCount + ae2.windDx == 0 {
                    ae1.windCount = -ae1.windCount
                } else {
                    ae1.windCount += ae2.windDx
                }
                if ae2.windCount - ae1.windDx == 0 {
                    ae2.windCount = -ae2.windCount
                } else {
                    ae2.windCount -= ae1.windDx
                }
            }
        } else {
            if fillrule != .evenOdd {
                ae1.windCount2 += ae2.windDx
            } else {
                ae1.windCount2 = ae1.windCount2 == 0 ? 1 : 0
            }
            if fillrule != .evenOdd {
                ae2.windCount2 -= ae1.windDx
            } else {
                ae2.windCount2 = ae2.windCount2 == 0 ? 1 : 0
            }
        }

        switch fillrule {
        case .positive:
            oldE1WindCount = ae1.windCount
            oldE2WindCount = ae2.windCount
        case .negative:
            oldE1WindCount = -ae1.windCount
            oldE2WindCount = -ae2.windCount
        default:
            oldE1WindCount = abs(ae1.windCount)
            oldE2WindCount = abs(ae2.windCount)
        }

        let e1WindCountIs0or1 = oldE1WindCount == 0 || oldE1WindCount == 1
        let e2WindCountIs0or1 = oldE2WindCount == 0 || oldE2WindCount == 1

        if (!ClipperBase.isHotEdge(ae1) && !e1WindCountIs0or1) ||
           (!ClipperBase.isHotEdge(ae2) && !e2WindCountIs0or1) {
            return
        }

        // NOW PROCESS THE INTERSECTION
        if ClipperBase.isHotEdge(ae1) && ClipperBase.isHotEdge(ae2) {
            if (oldE1WindCount != 0 && oldE1WindCount != 1) ||
               (oldE2WindCount != 0 && oldE2WindCount != 1) ||
               (ae1.localMin.polytype != ae2.localMin.polytype && cliptype != .xor) {
                addLocalMaxPoly(ae1, ae2, pt)
            } else if ClipperBase.isFront(ae1) || ae1.outrec === ae2.outrec {
                addLocalMaxPoly(ae1, ae2, pt)
                addLocalMinPoly(ae1, ae2, pt)
            } else {
                ClipperBase.addOutPt(ae1, pt)
                ClipperBase.addOutPt(ae2, pt)
                ClipperBase.swapOutrecs(ae1, ae2)
            }
        } else if ClipperBase.isHotEdge(ae1) {
            ClipperBase.addOutPt(ae1, pt)
            ClipperBase.swapOutrecs(ae1, ae2)
        } else if ClipperBase.isHotEdge(ae2) {
            ClipperBase.addOutPt(ae2, pt)
            ClipperBase.swapOutrecs(ae1, ae2)
        } else {
            // neither edge is hot
            let e1Wc2: Int
            let e2Wc2: Int
            switch fillrule {
            case .positive:
                e1Wc2 = ae1.windCount2
                e2Wc2 = ae2.windCount2
            case .negative:
                e1Wc2 = -ae1.windCount2
                e2Wc2 = -ae2.windCount2
            default:
                e1Wc2 = abs(ae1.windCount2)
                e2Wc2 = abs(ae2.windCount2)
            }

            if !ClipperBase.isSamePolyType(ae1, ae2) {
                addLocalMinPoly(ae1, ae2, pt)
            } else if oldE1WindCount == 1 && oldE2WindCount == 1 {
                switch cliptype {
                case .union:
                    if e1Wc2 > 0 && e2Wc2 > 0 { return }
                    addLocalMinPoly(ae1, ae2, pt)
                case .difference:
                    if (ClipperBase.getPolyType(ae1) == .clip && e1Wc2 > 0 && e2Wc2 > 0) ||
                       (ClipperBase.getPolyType(ae1) == .subject && e1Wc2 <= 0 && e2Wc2 <= 0) {
                        addLocalMinPoly(ae1, ae2, pt)
                    }
                case .xor:
                    addLocalMinPoly(ae1, ae2, pt)
                default: // intersection
                    if e1Wc2 <= 0 || e2Wc2 <= 0 { return }
                    addLocalMinPoly(ae1, ae2, pt)
                }
            }
        }
    }

    // MARK: - AEL Management

    private func deleteFromAEL(_ ae: Active) {
        let prev = ae.prevInAEL
        let next = ae.nextInAEL
        if prev == nil && next == nil && actives !== ae {
            return
        }
        if prev != nil {
            prev!.nextInAEL = next
        } else {
            actives = next
        }
        if next != nil {
            next!.prevInAEL = prev
        }
    }

    private func adjustCurrXAndCopyToSEL(_ topY: Int64) {
        var ae = actives
        sel = ae
        while ae != nil {
            ae!.prevInSEL = ae!.prevInAEL
            ae!.nextInSEL = ae!.nextInAEL
            ae!.jump = ae!.nextInSEL
            ae!.curX = ClipperBase.topX(ae!, topY)
            ae = ae!.nextInAEL
        }
    }

    // MARK: - Execute

    final func executeInternal(_ ct: ClipType, _ fillRule: FillRule) throws {
        if ct == .noClip { return }
        fillrule = fillRule
        cliptype = ct
        reset()
        if scanlineSet.isEmpty { return }

        guard var y = scanlineSet.pollLast() else { return }
        while succeeded {
            insertLocalMinimaIntoAEL(y)
            while let ae = popHorz() {
                doHorizontal(ae)
            }
            if !horzSegList.isEmpty {
                convertHorzSegsToJoins()
                horzSegList.removeAll()
            }
            currentBotY = y
            guard let nextY = scanlineSet.pollLast() else { break }
            y = nextY
            doIntersections(y)
            doTopOfScanbeam(y)
            while let ae = popHorz() {
                doHorizontal(ae)
            }
        }

        if succeeded {
            processHorzJoins()
        }
    }

    // MARK: - Intersections

    private func doIntersections(_ topY: Int64) {
        if buildIntersectList(topY) {
            processIntersectList()
            disposeIntersectNodes()
        }
    }

    private func disposeIntersectNodes() {
        intersectList.removeAll()
    }

    private func addNewIntersectNode(_ ae1: Active, _ ae2: Active, _ topY: Int64) {
        var ip = Point64()
        if !InternalClipper.getLineIntersectPt(ae1.bot, ae1.top, ae2.bot, ae2.top, &ip) {
            ip = Point64(ae1.curX, topY)
        }

        if ip.y > currentBotY || ip.y < topY {
            let absDx1 = abs(ae1.dx)
            let absDx2 = abs(ae2.dx)
            if absDx1 > 100 && absDx2 > 100 {
                if absDx1 > absDx2 {
                    ip = InternalClipper.getClosestPtOnSegment(ip, ae1.bot, ae1.top)
                } else {
                    ip = InternalClipper.getClosestPtOnSegment(ip, ae2.bot, ae2.top)
                }
            } else if absDx1 > 100 {
                ip = InternalClipper.getClosestPtOnSegment(ip, ae1.bot, ae1.top)
            } else if absDx2 > 100 {
                ip = InternalClipper.getClosestPtOnSegment(ip, ae2.bot, ae2.top)
            } else {
                if ip.y < topY {
                    ip.y = topY
                } else {
                    ip.y = currentBotY
                }
                if absDx1 < absDx2 {
                    ip.x = ClipperBase.topX(ae1, ip.y)
                } else {
                    ip.x = ClipperBase.topX(ae2, ip.y)
                }
            }
        }
        let node = IntersectNode(pt: ip, edge1: ae1, edge2: ae2)
        intersectList.append(node)
    }

    private func extractFromSEL(_ ae: Active) -> Active? {
        let res = ae.nextInSEL
        if res != nil {
            res!.prevInSEL = ae.prevInSEL
        }
        ae.prevInSEL!.nextInSEL = res
        return res
    }

    private static func insert1Before2InSEL(_ ae1: Active, _ ae2: Active) {
        ae1.prevInSEL = ae2.prevInSEL
        if ae1.prevInSEL != nil {
            ae1.prevInSEL!.nextInSEL = ae1
        }
        ae1.nextInSEL = ae2
        ae2.prevInSEL = ae1
    }

    private func buildIntersectList(_ topY: Int64) -> Bool {
        guard actives != nil && actives!.nextInAEL != nil else { return false }

        adjustCurrXAndCopyToSEL(topY)

        var left: Active? = sel
        var prevBase: Active? = nil

        while left?.jump != nil {
            prevBase = nil
            while left != nil && left!.jump != nil {
                var currBase: Active = left!
                var right: Active? = left!.jump!
                var lEnd: Active? = right
                let rEnd: Active? = right!.jump
                left!.jump = rEnd
                while left !== lEnd && right !== rEnd {
                    if right!.curX < left!.curX {
                        var tmp: Active? = right!.prevInSEL
                        while true {
                            addNewIntersectNode(tmp!, right!, topY)
                            if left === tmp { break }
                            tmp = tmp!.prevInSEL
                        }

                        tmp = right
                        right = extractFromSEL(tmp!)
                        lEnd = right
                        ClipperBase.insert1Before2InSEL(tmp!, left!)
                        if left === currBase {
                            currBase = tmp!
                            currBase.jump = rEnd
                            if prevBase == nil {
                                sel = currBase
                            } else {
                                prevBase!.jump = currBase
                            }
                        }
                    } else {
                        left = left!.nextInSEL
                    }
                }

                prevBase = currBase
                left = rEnd
            }
            left = sel
        }

        return !intersectList.isEmpty
    }

    private func processIntersectList() {
        intersectList.sort { a, b in
            if a.pt.y == b.pt.y {
                if a.pt.x == b.pt.x { return false }
                return a.pt.x < b.pt.x
            }
            return a.pt.y > b.pt.y
        }

        for i in 0..<intersectList.count {
            if !ClipperBase.edgesAdjacentInAEL(intersectList[i]) {
                var j = i + 1
                while !ClipperBase.edgesAdjacentInAEL(intersectList[j]) {
                    j += 1
                }
                intersectList.swapAt(i, j)
            }

            let node = intersectList[i]
            intersectEdges(node.edge1, node.edge2, node.pt)
            swapPositionsInAEL(node.edge1, node.edge2)

            node.edge1.curX = node.pt.x
            node.edge2.curX = node.pt.x
            checkJoinLeft(node.edge2, node.pt, checkCurrX: true)
            checkJoinRight(node.edge1, node.pt, checkCurrX: true)
        }
    }

    private func swapPositionsInAEL(_ ae1: Active, _ ae2: Active) {
        let next = ae2.nextInAEL
        if next != nil { next!.prevInAEL = ae1 }
        let prev = ae1.prevInAEL
        if prev != nil { prev!.nextInAEL = ae2 }
        ae2.prevInAEL = prev
        ae2.nextInAEL = ae1
        ae1.prevInAEL = ae2
        ae1.nextInAEL = next
        if ae2.prevInAEL == nil { actives = ae2 }
    }

    // MARK: - Horizontal Direction

    private struct HorzDirection {
        let leftToRight: Bool
        let leftX: Int64
        let rightX: Int64
    }

    private static func resetHorzDirection(_ horz: Active, _ vertexMax: Vertex?) -> HorzDirection {
        if horz.bot.x == horz.top.x {
            let leftX = horz.curX
            let rightX = horz.curX
            var ae = horz.nextInAEL
            while ae != nil && ae!.vertexTop !== vertexMax {
                ae = ae!.nextInAEL
            }
            return HorzDirection(leftToRight: ae != nil, leftX: leftX, rightX: rightX)
        }

        if horz.curX < horz.top.x {
            return HorzDirection(leftToRight: true, leftX: horz.curX, rightX: horz.top.x)
        }
        return HorzDirection(leftToRight: false, leftX: horz.top.x, rightX: horz.curX)
    }

    private func trimHorz(_ horzEdge: Active, _ preserveCollinear: Bool) {
        var wasTrimmed = false
        var pt = ClipperBase.nextVertex(horzEdge).pt

        while pt.y == horzEdge.top.y {
            if preserveCollinear && (pt.x < horzEdge.top.x) != (horzEdge.bot.x < horzEdge.top.x) {
                break
            }
            horzEdge.vertexTop = ClipperBase.nextVertex(horzEdge)
            horzEdge.top = pt
            wasTrimmed = true
            if ClipperBase.isMaxima(horzEdge) { break }
            pt = ClipperBase.nextVertex(horzEdge).pt
        }
        if wasTrimmed {
            ClipperBase.setDx(horzEdge)
        }
    }

    private func addToHorzSegList(_ op: OutPt) {
        if op.outrec.isOpen { return }
        horzSegList.append(HorzSegment(op: op))
    }

    private func getLastOp(_ hotEdge: Active) -> OutPt {
        let outrec = hotEdge.outrec!
        return hotEdge === outrec.frontEdge ? outrec.pts! : outrec.pts!.next
    }

    // MARK: - DoHorizontal

    private func doHorizontal(_ horz: Active) {
        let horzIsOpen = ClipperBase.isOpen(horz)
        let Y = horz.bot.y

        let vertexMax: Vertex? = horzIsOpen ?
            ClipperBase.getCurrYMaximaVertex_Open(horz) :
            ClipperBase.getCurrYMaximaVertex(horz)

        var direction = ClipperBase.resetHorzDirection(horz, vertexMax)
        var isLeftToRight = direction.leftToRight
        var rightX = direction.rightX
        var leftX = direction.leftX

        if ClipperBase.isHotEdge(horz) {
            let op = ClipperBase.addOutPt(horz, Point64(horz.curX, Y))
            addToHorzSegList(op)
        }
        let currOutrec = horz.outrec

        while true {
            var ae: Active? = isLeftToRight ? horz.nextInAEL : horz.prevInAEL

            while ae != nil {
                if ae!.vertexTop === vertexMax {
                    if ClipperBase.isHotEdge(horz) && ClipperBase.isJoined(ae!) {
                        split(ae!, ae!.top)
                    }

                    if ClipperBase.isHotEdge(horz) {
                        while horz.vertexTop !== vertexMax {
                            ClipperBase.addOutPt(horz, horz.top)
                            updateEdgeIntoAEL(horz)
                        }
                        if isLeftToRight {
                            addLocalMaxPoly(horz, ae!, horz.top)
                        } else {
                            addLocalMaxPoly(ae!, horz, horz.top)
                        }
                    }
                    deleteFromAEL(ae!)
                    deleteFromAEL(horz)
                    return
                }

                if vertexMax !== horz.vertexTop || ClipperBase.isOpenEnd(horz) {
                    if (isLeftToRight && ae!.curX > rightX) || (!isLeftToRight && ae!.curX < leftX) {
                        break
                    }

                    if ae!.curX == horz.top.x && !ClipperBase.isHorizontal(ae!) {
                        let pt = ClipperBase.nextVertex(horz).pt

                        if ClipperBase.isOpen(ae!) && !ClipperBase.isSamePolyType(ae!, horz) && !ClipperBase.isHotEdge(ae!) {
                            if (isLeftToRight && ClipperBase.topX(ae!, pt.y) > pt.x) ||
                               (!isLeftToRight && ClipperBase.topX(ae!, pt.y) < pt.x) {
                                break
                            }
                        } else if (isLeftToRight && ClipperBase.topX(ae!, pt.y) >= pt.x) ||
                                  (!isLeftToRight && ClipperBase.topX(ae!, pt.y) <= pt.x) {
                            break
                        }
                    }
                }

                let pt = Point64(ae!.curX, Y)

                if isLeftToRight {
                    intersectEdges(horz, ae!, pt)
                    swapPositionsInAEL(horz, ae!)
                    horz.curX = ae!.curX
                    ae = horz.nextInAEL
                } else {
                    intersectEdges(ae!, horz, pt)
                    swapPositionsInAEL(ae!, horz)
                    horz.curX = ae!.curX
                    ae = horz.prevInAEL
                }

                if ClipperBase.isHotEdge(horz) && horz.outrec !== currOutrec {
                    addToHorzSegList(getLastOp(horz))
                }
            }

            if horzIsOpen && ClipperBase.isOpenEnd(horz) {
                if ClipperBase.isHotEdge(horz) {
                    ClipperBase.addOutPt(horz, horz.top)
                    if ClipperBase.isFront(horz) {
                        horz.outrec!.frontEdge = nil
                    } else {
                        horz.outrec!.backEdge = nil
                    }
                    horz.outrec = nil
                }
                deleteFromAEL(horz)
                return
            }

            if ClipperBase.nextVertex(horz).pt.y != horz.top.y {
                break
            }

            if ClipperBase.isHotEdge(horz) {
                ClipperBase.addOutPt(horz, horz.top)
            }

            updateEdgeIntoAEL(horz)

            direction = ClipperBase.resetHorzDirection(horz, vertexMax)
            isLeftToRight = direction.leftToRight
            rightX = direction.rightX
            leftX = direction.leftX
        }

        if ClipperBase.isHotEdge(horz) {
            let op = ClipperBase.addOutPt(horz, horz.top)
            addToHorzSegList(op)
        }
        updateEdgeIntoAEL(horz)
    }

    // MARK: - DoTopOfScanbeam

    private func doTopOfScanbeam(_ y: Int64) {
        sel = nil
        var ae = actives
        while ae != nil {
            if ae!.top.y == y {
                ae!.curX = ae!.top.x
                if ClipperBase.isMaxima(ae!) {
                    ae = doMaxima(ae!)
                    continue
                }

                if ClipperBase.isHotEdge(ae!) {
                    ClipperBase.addOutPt(ae!, ae!.top)
                }
                updateEdgeIntoAEL(ae!)
                if ClipperBase.isHorizontal(ae!) {
                    pushHorz(ae!)
                }
            } else {
                ae!.curX = ClipperBase.topX(ae!, y)
            }
            ae = ae!.nextInAEL
        }
    }

    // MARK: - DoMaxima

    private func doMaxima(_ ae: Active) -> Active? {
        let prevE = ae.prevInAEL
        var nextE = ae.nextInAEL

        if ClipperBase.isOpenEnd(ae) {
            if ClipperBase.isHotEdge(ae) {
                ClipperBase.addOutPt(ae, ae.top)
            }
            if !ClipperBase.isHorizontal(ae) {
                if ClipperBase.isHotEdge(ae) {
                    if ClipperBase.isFront(ae) {
                        ae.outrec!.frontEdge = nil
                    } else {
                        ae.outrec!.backEdge = nil
                    }
                    ae.outrec = nil
                }
                deleteFromAEL(ae)
            }
            return nextE
        }

        guard let maxPair = ClipperBase.getMaximaPair(ae) else {
            return nextE
        }

        if ClipperBase.isJoined(ae) { split(ae, ae.top) }
        if ClipperBase.isJoined(maxPair) { split(maxPair, maxPair.top) }

        while nextE !== maxPair {
            intersectEdges(ae, nextE!, ae.top)
            swapPositionsInAEL(ae, nextE!)
            nextE = ae.nextInAEL
        }

        if ClipperBase.isOpen(ae) {
            if ClipperBase.isHotEdge(ae) {
                addLocalMaxPoly(ae, maxPair, ae.top)
            }
            deleteFromAEL(maxPair)
            deleteFromAEL(ae)
            return prevE != nil ? prevE!.nextInAEL : actives
        }

        if ClipperBase.isHotEdge(ae) {
            addLocalMaxPoly(ae, maxPair, ae.top)
        }

        deleteFromAEL(ae)
        deleteFromAEL(maxPair)
        return prevE != nil ? prevE!.nextInAEL : actives
    }

    // MARK: - Join/Split

    private static func isJoined(_ e: Active) -> Bool {
        return e.joinWith != .none
    }

    private func split(_ e: Active, _ currPt: Point64) {
        if e.joinWith == .right {
            e.joinWith = .none
            e.nextInAEL!.joinWith = .none
            addLocalMinPoly(e, e.nextInAEL!, currPt, isNew: true)
        } else {
            e.joinWith = .none
            e.prevInAEL!.joinWith = .none
            addLocalMinPoly(e.prevInAEL!, e, currPt, isNew: true)
        }
    }

    private func checkJoinLeft(_ e: Active, _ pt: Point64, checkCurrX: Bool = false) {
        guard let prev = e.prevInAEL,
              ClipperBase.isHotEdge(e), ClipperBase.isHotEdge(prev),
              !ClipperBase.isHorizontal(e), !ClipperBase.isHorizontal(prev),
              !ClipperBase.isOpen(e), !ClipperBase.isOpen(prev) else {
            return
        }

        if (pt.y < e.top.y + 2 || pt.y < prev.top.y + 2) &&
           (e.bot.y > pt.y || prev.bot.y > pt.y) {
            return
        }

        if checkCurrX {
            if perpendicDistFromLineSqrd(pt, prev.bot, prev.top) > 0.25 { return }
        } else if e.curX != prev.curX {
            return
        }
        if !InternalClipper.isCollinear(e.top, pt, prev.top) { return }

        if e.outrec!.idx == prev.outrec!.idx {
            addLocalMaxPoly(prev, e, pt)
        } else if e.outrec!.idx < prev.outrec!.idx {
            ClipperBase.joinOutrecPaths(e, prev)
        } else {
            ClipperBase.joinOutrecPaths(prev, e)
        }
        prev.joinWith = .right
        e.joinWith = .left
    }

    private func checkJoinRight(_ e: Active, _ pt: Point64, checkCurrX: Bool = false) {
        guard let next = e.nextInAEL,
              ClipperBase.isHotEdge(e), ClipperBase.isHotEdge(next),
              !ClipperBase.isHorizontal(e), !ClipperBase.isHorizontal(next),
              !ClipperBase.isOpen(e), !ClipperBase.isOpen(next) else {
            return
        }

        if (pt.y < e.top.y + 2 || pt.y < next.top.y + 2) &&
           (e.bot.y > pt.y || next.bot.y > pt.y) {
            return
        }

        if checkCurrX {
            if perpendicDistFromLineSqrd(pt, next.bot, next.top) > 0.25 { return }
        } else if e.curX != next.curX {
            return
        }
        if !InternalClipper.isCollinear(e.top, pt, next.top) { return }

        if e.outrec!.idx == next.outrec!.idx {
            addLocalMaxPoly(e, next, pt)
        } else if e.outrec!.idx < next.outrec!.idx {
            ClipperBase.joinOutrecPaths(e, next)
        } else {
            ClipperBase.joinOutrecPaths(next, e)
        }
        e.joinWith = .right
        next.joinWith = .left
    }

    // MARK: - perpendicDistFromLineSqrd helper

    private func perpendicDistFromLineSqrd(_ pt: Point64, _ line1: Point64, _ line2: Point64) -> Double {
        let a = Double(pt.x - line1.x)
        let b = Double(pt.y - line1.y)
        let c = Double(line2.x - line1.x)
        let d = Double(line2.y - line1.y)
        if c == 0 && d == 0 { return 0 }
        return Clipper.sqr(a * d - c * b) / (c * c + d * d)
    }

    // MARK: - Horz Segments

    private static func fixOutRecPts(_ outrec: OutRec) {
        var op: OutPt = outrec.pts!
        repeat {
            op.outrec = outrec
            op = op.next
        } while op !== outrec.pts
    }

    private static func setHorzSegHeadingForward(_ hs: HorzSegment, _ opP: OutPt, _ opN: OutPt) -> Bool {
        if opP.pt.x == opN.pt.x { return false }
        if opP.pt.x < opN.pt.x {
            hs.leftOp = opP
            hs.rightOp = opN
            hs.leftToRight = true
        } else {
            hs.leftOp = opN
            hs.rightOp = opP
            hs.leftToRight = false
        }
        return true
    }

    private static func updateHorzSegment(_ hs: HorzSegment) -> Bool {
        let op = hs.leftOp!
        guard let outrec = getRealOutRec(op.outrec) else { return false }
        let outrecHasEdges = outrec.frontEdge != nil
        let currY = op.pt.y
        var opP: OutPt = op
        var opN: OutPt = op
        if outrecHasEdges {
            let opA = outrec.pts!
            let opZ = opA.next!
            while opP !== opZ && opP.prev.pt.y == currY { opP = opP.prev }
            while opN !== opA && opN.next.pt.y == currY { opN = opN.next }
        } else {
            while opP.prev !== opN && opP.prev.pt.y == currY { opP = opP.prev }
            while opN.next !== opP && opN.next.pt.y == currY { opN = opN.next }
        }
        let result = setHorzSegHeadingForward(hs, opP, opN) && hs.leftOp!.horz == nil

        if result {
            hs.leftOp!.horz = hs
        } else {
            hs.rightOp = nil
        }
        return result
    }

    private static func duplicateOp(_ op: OutPt, insertAfter: Bool) -> OutPt {
        let result = OutPt(pt: op.pt, outrec: op.outrec)
        if insertAfter {
            result.next = op.next
            result.next.prev = result
            result.prev = op
            op.next = result
        } else {
            result.prev = op.prev
            result.prev.next = result
            result.next = op
            op.prev = result
        }
        return result
    }

    private func horzSegSort(_ hs1: HorzSegment?, _ hs2: HorzSegment?) -> Bool {
        if hs1 == nil || hs2 == nil { return false }
        if hs1!.rightOp == nil {
            return hs2!.rightOp != nil ? false : false
        } else if hs2!.rightOp == nil {
            return true
        } else {
            return hs1!.leftOp!.pt.x < hs2!.leftOp!.pt.x
        }
    }

    private func convertHorzSegsToJoins() {
        var k = 0
        for hs in horzSegList {
            if ClipperBase.updateHorzSegment(hs) { k += 1 }
        }
        if k < 2 { return }

        horzSegList.sort { a, b in
            if a.rightOp == nil && b.rightOp == nil { return false }
            if a.rightOp == nil { return false }
            if b.rightOp == nil { return true }
            return a.leftOp!.pt.x < b.leftOp!.pt.x
        }

        for i in 0..<(k - 1) {
            let hs1 = horzSegList[i]
            for j in (i + 1)..<k {
                let hs2 = horzSegList[j]
                if hs2.leftOp!.pt.x >= hs1.rightOp!.pt.x ||
                   hs2.leftToRight == hs1.leftToRight ||
                   hs2.rightOp!.pt.x <= hs1.leftOp!.pt.x {
                    continue
                }
                let currY = hs1.leftOp!.pt.y
                if hs1.leftToRight {
                    while hs1.leftOp!.next.pt.y == currY && hs1.leftOp!.next.pt.x <= hs2.leftOp!.pt.x {
                        hs1.leftOp = hs1.leftOp!.next
                    }
                    while hs2.leftOp!.prev.pt.y == currY && hs2.leftOp!.prev.pt.x <= hs1.leftOp!.pt.x {
                        hs2.leftOp = hs2.leftOp!.prev
                    }
                    let join = HorzJoin(
                        ltor: ClipperBase.duplicateOp(hs1.leftOp!, insertAfter: true),
                        rtol: ClipperBase.duplicateOp(hs2.leftOp!, insertAfter: false)
                    )
                    horzJoinList.append(join)
                } else {
                    while hs1.leftOp!.prev.pt.y == currY && hs1.leftOp!.prev.pt.x <= hs2.leftOp!.pt.x {
                        hs1.leftOp = hs1.leftOp!.prev
                    }
                    while hs2.leftOp!.next.pt.y == currY && hs2.leftOp!.next.pt.x <= hs1.leftOp!.pt.x {
                        hs2.leftOp = hs2.leftOp!.next
                    }
                    let join = HorzJoin(
                        ltor: ClipperBase.duplicateOp(hs2.leftOp!, insertAfter: true),
                        rtol: ClipperBase.duplicateOp(hs1.leftOp!, insertAfter: false)
                    )
                    horzJoinList.append(join)
                }
            }
        }
    }

    // MARK: - Clean Path / Point In Polygon

    private static func getCleanPath(_ op: OutPt) -> Path64 {
        var result: Path64 = []
        var op2: OutPt = op
        while op2.next !== op &&
              ((op2.pt.x == op2.next.pt.x && op2.pt.x == op2.prev.pt.x) ||
               (op2.pt.y == op2.next.pt.y && op2.pt.y == op2.prev.pt.y)) {
            op2 = op2.next
        }
        result.append(op2.pt)
        var prevOp = op2
        op2 = op2.next
        while op2 !== op {
            if (op2.pt.x != op2.next.pt.x || op2.pt.x != prevOp.pt.x) &&
               (op2.pt.y != op2.next.pt.y || op2.pt.y != prevOp.pt.y) {
                result.append(op2.pt)
                prevOp = op2
            }
            op2 = op2.next
        }
        return result
    }

    private static func pointInOpPolygon(_ pt: Point64, _ op: OutPt) -> PointInPolygonResult {
        if op === op.next || op.prev === op.next {
            return .isOutside
        }
        var op2: OutPt = op
        let opStart: OutPt = op
        repeat {
            if op2.pt.y != pt.y { break }
            op2 = op2.next
        } while op2 !== opStart
        if op2.pt.y == pt.y { return .isOutside }

        var isAbove = op2.pt.y < pt.y
        let startingAbove = isAbove
        var val = 0

        let startOp = op2
        op2 = op2.next
        while op2 !== startOp {
            if isAbove {
                while op2 !== startOp && op2.pt.y < pt.y { op2 = op2.next }
            } else {
                while op2 !== startOp && op2.pt.y > pt.y { op2 = op2.next }
            }
            if op2 === startOp { break }

            if op2.pt.y == pt.y {
                if op2.pt.x == pt.x ||
                   (op2.pt.y == op2.prev.pt.y && (pt.x < op2.prev.pt.x) != (pt.x < op2.pt.x)) {
                    return .isOn
                }
                op2 = op2.next
                if op2 === startOp { break }
                continue
            }

            if op2.pt.x <= pt.x || op2.prev.pt.x <= pt.x {
                if op2.prev.pt.x < pt.x && op2.pt.x < pt.x {
                    val = 1 - val
                } else {
                    let d = InternalClipper.crossProductSign(op2.prev.pt, op2.pt, pt)
                    if d == 0 { return .isOn }
                    if (d < 0) == isAbove { val = 1 - val }
                }
            }
            isAbove = !isAbove
            op2 = op2.next
        }

        if isAbove != startingAbove {
            let d = InternalClipper.crossProductSign(op2.prev.pt, op2.pt, pt)
            if d == 0 { return .isOn }
            if (d < 0) == isAbove { val = 1 - val }
        }

        return val == 0 ? .isOutside : .isInside
    }

    private static func path1InsidePath2(_ op1: OutPt, _ op2: OutPt) -> Bool {
        var pip = PointInPolygonResult.isOn
        var op: OutPt = op1
        repeat {
            switch pointInOpPolygon(op.pt, op2) {
            case .isOutside:
                if pip == .isOutside { return false }
                pip = .isOutside
            case .isInside:
                if pip == .isInside { return true }
                pip = .isInside
            default:
                break
            }
            op = op.next
        } while op !== op1
        return InternalClipper.path2ContainsPath1(getCleanPath(op1), getCleanPath(op2))
    }

    // MARK: - Move Splits

    private func moveSplits(_ fromOr: OutRec, _ toOr: OutRec) {
        guard let splits = fromOr.splits else { return }
        if toOr.splits == nil { toOr.splits = [] }
        for i in splits {
            if i != toOr.idx { toOr.splits!.append(i) }
        }
        fromOr.splits = nil
    }

    // MARK: - Process Horz Joins

    private func processHorzJoins() {
        for j in horzJoinList {
            let or1 = ClipperBase.getRealOutRec(j.op1!.outrec)!
            var or2 = ClipperBase.getRealOutRec(j.op2!.outrec)!

            let op1b = j.op1!.next!
            let op2b = j.op2!.prev!
            j.op1!.next = j.op2
            j.op2!.prev = j.op1
            op1b.prev = op2b
            op2b.next = op1b

            if or1 === or2 {
                or2 = newOutRec()
                or2.pts = op1b
                ClipperBase.fixOutRecPts(or2)

                if or1.pts!.outrec === or2 {
                    or1.pts = j.op1
                    or1.pts!.outrec = or1
                }

                if usingPolytree {
                    if ClipperBase.path1InsidePath2(or1.pts!, or2.pts!) {
                        let temp = or2.pts
                        or2.pts = or1.pts
                        or1.pts = temp
                        ClipperBase.fixOutRecPts(or1)
                        ClipperBase.fixOutRecPts(or2)
                        or2.owner = or1
                    } else if ClipperBase.path1InsidePath2(or2.pts!, or1.pts!) {
                        or2.owner = or1
                    } else {
                        or2.owner = or1.owner
                    }

                    if or1.splits == nil { or1.splits = [] }
                    or1.splits!.append(or2.idx)
                } else {
                    or2.owner = or1
                }
            } else {
                or2.pts = nil
                if usingPolytree {
                    ClipperBase.setOwner(or2, or1)
                    moveSplits(or2, or1)
                } else {
                    or2.owner = or1
                }
            }
        }
    }

    // MARK: - Validation Helpers

    private static func ptsReallyClose(_ pt1: Point64, _ pt2: Point64) -> Bool {
        return abs(pt1.x - pt2.x) < 2 && abs(pt1.y - pt2.y) < 2
    }

    private static func isVerySmallTriangle(_ op: OutPt) -> Bool {
        return op.next.next === op.prev &&
               (ptsReallyClose(op.prev.pt, op.next.pt) ||
                ptsReallyClose(op.pt, op.next.pt) ||
                ptsReallyClose(op.pt, op.prev.pt))
    }

    private static func isValidClosedPath(_ op: OutPt?) -> Bool {
        return op != nil && op!.next !== op && (op!.next !== op!.prev || !isVerySmallTriangle(op!))
    }

    private static func disposeOutPt(_ op: OutPt) -> OutPt? {
        let result: OutPt? = op.next === op ? nil : op.next
        op.prev.next = op.next
        op.next.prev = op.prev
        return result
    }

    // MARK: - Clean Collinear

    private func cleanCollinear(_ outrec: OutRec) {
        guard let realOutrec = ClipperBase.getRealOutRec(outrec) else { return }
        let or = realOutrec
        if or.isOpen { return }

        if !ClipperBase.isValidClosedPath(or.pts) {
            or.pts = nil
            return
        }

        let startOp = or.pts!
        var op2: OutPt = startOp
        var currentStartOp = startOp
        while true {
            if InternalClipper.isCollinear(op2.prev.pt, op2.pt, op2.next.pt) &&
               (op2.pt == op2.prev.pt || op2.pt == op2.next.pt ||
                !getPreserveCollinear ||
                InternalClipper.dotProduct(op2.prev.pt, op2.pt, op2.next.pt) < 0) {
                if op2 === or.pts {
                    or.pts = op2.prev
                }
                op2 = ClipperBase.disposeOutPt(op2)!
                if !ClipperBase.isValidClosedPath(op2) {
                    or.pts = nil
                    return
                }
                currentStartOp = op2
                continue
            }
            op2 = op2.next
            if op2 === currentStartOp { break }
        }
        fixSelfIntersects(or)
    }

    // MARK: - Split Op

    private func doSplitOp(_ outrec: OutRec, _ splitOp: OutPt) {
        let prevOp = splitOp.prev!
        let nextNextOp = splitOp.next.next!
        outrec.pts = prevOp

        var ip = Point64()
        InternalClipper.getLineIntersectPt(prevOp.pt, splitOp.pt, splitOp.next.pt, nextNextOp.pt, &ip)

        let area1 = ClipperBase.area(prevOp)
        let absArea1 = abs(area1)

        if absArea1 < 2 {
            outrec.pts = nil
            return
        }

        let area2 = ClipperBase.areaTriangle(ip, splitOp.pt, splitOp.next.pt)
        let absArea2 = abs(area2)

        if ip == prevOp.pt || ip == nextNextOp.pt {
            nextNextOp.prev = prevOp
            prevOp.next = nextNextOp
        } else {
            let newOp2 = OutPt(pt: ip, outrec: outrec)
            newOp2.prev = prevOp
            newOp2.next = nextNextOp
            nextNextOp.prev = newOp2
            prevOp.next = newOp2
        }

        if absArea2 <= 1 || (!(absArea2 > absArea1) && ((area2 > 0) != (area1 > 0))) {
            return
        }

        let newOutRec = self.newOutRec()
        newOutRec.owner = outrec.owner
        splitOp.outrec = newOutRec
        splitOp.next.outrec = newOutRec

        let newOp = OutPt(pt: ip, outrec: newOutRec)
        newOp.prev = splitOp.next
        newOp.next = splitOp
        newOutRec.pts = newOp
        splitOp.prev = newOp
        splitOp.next.next = newOp

        if !usingPolytree { return }

        if ClipperBase.path1InsidePath2(prevOp, newOp) {
            if newOutRec.splits == nil { newOutRec.splits = [] }
            newOutRec.splits!.append(outrec.idx)
        } else {
            if outrec.splits == nil { outrec.splits = [] }
            outrec.splits!.append(newOutRec.idx)
        }
    }

    private func fixSelfIntersects(_ outrec: OutRec) {
        var op2: OutPt = outrec.pts!
        while true {
            if op2.prev === op2.next.next { break }
            if InternalClipper.segsIntersect(op2.prev.pt, op2.pt, op2.next.pt, op2.next.next.pt) {
                doSplitOp(outrec, op2)
                if outrec.pts == nil { return }
                op2 = outrec.pts!
                continue
            }
            op2 = op2.next
            if op2 === outrec.pts { break }
        }
    }

    // MARK: - Build Path

    static func buildPath(_ op: OutPt?, reverse: Bool, isOpen: Bool, path: inout Path64) -> Bool {
        guard let op = op, op.next !== op, (isOpen || op.next !== op.prev) else {
            return false
        }
        path.removeAll()

        var lastPt: Point64
        var op2: OutPt
        var startOp = op
        if reverse {
            lastPt = startOp.pt
            op2 = startOp.prev
        } else {
            startOp = startOp.next
            lastPt = startOp.pt
            op2 = startOp.next
        }
        path.append(lastPt)

        while op2 !== startOp {
            if op2.pt != lastPt {
                lastPt = op2.pt
                path.append(lastPt)
            }
            if reverse {
                op2 = op2.prev
            } else {
                op2 = op2.next
            }
        }

        if path.count == 3 && !isOpen && isVerySmallTriangle(op2) {
            return false
        }
        return true
    }

    // MARK: - Build Paths

    @discardableResult
    func buildPaths(_ solutionClosed: inout Paths64, _ solutionOpen: inout Paths64) -> Bool {
        solutionClosed.removeAll()
        solutionOpen.removeAll()
        solutionClosed.reserveCapacity(outrecList.count)
        solutionOpen.reserveCapacity(outrecList.count)

        var i = 0
        while i < outrecList.count {
            let outrec = outrecList[i]
            i += 1
            if outrec.pts == nil { continue }

            var path: Path64 = []
            if outrec.isOpen {
                if ClipperBase.buildPath(outrec.pts, reverse: getReverseSolution, isOpen: true, path: &path) {
                    solutionOpen.append(path)
                }
            } else {
                cleanCollinear(outrec)
                if ClipperBase.buildPath(outrec.pts, reverse: getReverseSolution, isOpen: false, path: &path) {
                    solutionClosed.append(path)
                }
            }
        }
        return true
    }

    // MARK: - Check Bounds

    private func checkBounds(_ outrec: OutRec) -> Bool {
        if outrec.pts == nil { return false }
        if !outrec.bounds.isEmpty { return true }
        cleanCollinear(outrec)
        if outrec.pts == nil || !ClipperBase.buildPath(outrec.pts, reverse: getReverseSolution, isOpen: false, path: &outrec.path) {
            return false
        }
        outrec.bounds = InternalClipper.getBounds(outrec.path)
        return true
    }

    private func checkSplitOwner(_ outrec: OutRec, _ splits: [Int]) -> Bool {
        for i in 0..<splits.count {
            var split = outrecList[splits[i]]
            if split.pts == nil && split.splits != nil && checkSplitOwner(outrec, split.splits!) {
                return true
            }
            guard let realSplit = ClipperBase.getRealOutRec(split) else { continue }
            split = realSplit
            if split === outrec || split.recursiveSplit === outrec { continue }
            split.recursiveSplit = outrec
            if split.splits != nil && checkSplitOwner(outrec, split.splits!) {
                return true
            }
            if !checkBounds(split) || !split.bounds.contains(outrec.bounds) ||
               !ClipperBase.path1InsidePath2(outrec.pts!, split.pts!) {
                continue
            }
            if !ClipperBase.isValidOwner(outrec, split) {
                split.owner = outrec.owner
            }
            outrec.owner = split
            return true
        }
        return false
    }

    private func recursiveCheckOwners(_ outrec: OutRec, _ polypath: PolyPathBase) {
        if outrec.polypath != nil || outrec.bounds.isEmpty { return }

        while outrec.owner != nil {
            if outrec.owner!.splits != nil && checkSplitOwner(outrec, outrec.owner!.splits!) {
                break
            }
            if outrec.owner!.pts != nil && checkBounds(outrec.owner!) &&
               ClipperBase.path1InsidePath2(outrec.pts!, outrec.owner!.pts!) {
                break
            }
            outrec.owner = outrec.owner!.owner
        }

        if outrec.owner != nil {
            if outrec.owner!.polypath == nil {
                recursiveCheckOwners(outrec.owner!, polypath)
            }
            outrec.polypath = outrec.owner!.polypath!.addChild(outrec.path)
        } else {
            outrec.polypath = polypath.addChild(outrec.path)
        }
    }

    // MARK: - Build Tree

    func buildTree(_ polytree: PolyPathBase, _ solutionOpen: inout Paths64) {
        polytree.clear()
        solutionOpen.removeAll()
        if hasOpenPaths {
            solutionOpen.reserveCapacity(outrecList.count)
        }

        var i = 0
        while i < outrecList.count {
            let outrec = outrecList[i]
            i += 1
            if outrec.pts == nil { continue }

            if outrec.isOpen {
                var openPath: Path64 = []
                if ClipperBase.buildPath(outrec.pts, reverse: getReverseSolution, isOpen: true, path: &openPath) {
                    solutionOpen.append(openPath)
                }
                continue
            }
            if checkBounds(outrec) {
                recursiveCheckOwners(outrec, polytree)
            }
        }
    }

    // MARK: - Get Bounds

    public final func getBounds() -> Rect64 {
        var bounds = Rect64.invalid
        for t in vertexList {
            var v: Vertex = t
            repeat {
                if v.pt.x < bounds.left { bounds.left = v.pt.x }
                if v.pt.x > bounds.right { bounds.right = v.pt.x }
                if v.pt.y < bounds.top { bounds.top = v.pt.y }
                if v.pt.y > bounds.bottom { bounds.bottom = v.pt.y }
                v = v.next!
            } while v !== t
        }
        return bounds.isEmpty ? Rect64(0, 0, 0, 0) : bounds
    }
}
