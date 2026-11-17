import CoreGraphics
import Foundation

/// Routing strategy identifier for rendering a UML relationship edge.
public enum EdgeRoutingStyle: String, Codable, CaseIterable, Sendable, Hashable {
    case straight = "Straight"
    case orthogonal = "Orthogonal"

    public var displayName: String {
        switch self {
        case .straight: return "Recta"
        case .orthogonal: return "Ortogonal"
        }
    }
}

/// Visual presentation of a `UMLRelationship` inside a `UMLDiagram`.
public struct DiagramEdgeView: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var relationshipID: UUID
    public var routingStyle: EdgeRoutingStyle
    public var waypoints: [CGPoint]

    public init(
        id: UUID = UUID(),
        relationshipID: UUID,
        routingStyle: EdgeRoutingStyle = .orthogonal,
        waypoints: [CGPoint] = []
    ) {
        self.id = id
        self.relationshipID = relationshipID
        self.routingStyle = routingStyle
        self.waypoints = waypoints
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(relationshipID)
        hasher.combine(routingStyle)
        for point in waypoints {
            hasher.combine(point.x)
            hasher.combine(point.y)
        }
    }
}
