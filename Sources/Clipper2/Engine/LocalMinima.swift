final class LocalMinima {
    var vertex: ClipperBase.Vertex!
    var polytype: PathType = .subject
    var isOpen: Bool = false

    init() {}

    init(vertex: ClipperBase.Vertex, polytype: PathType, isOpen: Bool = false) {
        self.vertex = vertex
        self.polytype = polytype
        self.isOpen = isOpen
    }
}
