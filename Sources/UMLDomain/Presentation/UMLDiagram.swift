import CoreGraphics
import Foundation

/// Visual diagram viewport displaying a subset of elements from `UMLModel`.
public struct UMLDiagram: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var nodes: [DiagramNodeView]
    public var edges: [DiagramEdgeView]
    public var zoomScale: CGFloat
    public var showGrid: Bool
    public var snapToGrid: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        nodes: [DiagramNodeView] = [],
        edges: [DiagramEdgeView] = [],
        zoomScale: CGFloat = 1.0,
        showGrid: Bool = true,
        snapToGrid: Bool = false
    ) {
        self.id = id
        self.name = name
        self.nodes = nodes
        self.edges = edges
        self.zoomScale = zoomScale
        self.showGrid = showGrid
        self.snapToGrid = snapToGrid
    }

    public func node(forClassifier classifierID: UUID) -> DiagramNodeView? {
        nodes.first { $0.classifierID == classifierID }
    }

    public func contains(classifierID: UUID) -> Bool {
        nodes.contains { $0.classifierID == classifierID }
    }

    public func edge(forRelationship relationshipID: UUID) -> DiagramEdgeView? {
        edges.first { $0.relationshipID == relationshipID }
    }
}
