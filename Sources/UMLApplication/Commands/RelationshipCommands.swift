import Foundation
import UMLDomain

/// Creates a semantic relationship in `UMLModel` and adds its edge presentation
/// to every diagram where both endpoints are currently displayed.
public struct CreateRelationshipCommand: ProjectCommand {
    public let commandName: String
    private let relationship: UMLRelationship
    private let routingStyle: EdgeRoutingStyle
    private var createdEdgesByDiagram: [(diagramID: UUID, edge: DiagramEdgeView)] = []

    public init(relationship: UMLRelationship, routingStyle: EdgeRoutingStyle = .orthogonal) {
        self.relationship = relationship
        self.routingStyle = routingStyle
        self.commandName = "Crear \(relationship.kind.displayName)"
    }

    public mutating func execute(on project: inout UMLProject) {
        project.model.upsertRelationship(relationship)
        createdEdgesByDiagram = []

        for index in project.diagrams.indices {
            let diagram = project.diagrams[index]
            let hasSource = diagram.contains(classifierID: relationship.source.classifierID)
            let hasTarget = diagram.contains(classifierID: relationship.target.classifierID)
            let alreadyHasEdge = diagram.edges.contains { $0.relationshipID == relationship.id }

            if hasSource && hasTarget && !alreadyHasEdge {
                let edge = DiagramEdgeView(relationshipID: relationship.id, routingStyle: routingStyle)
                project.diagrams[index].edges.append(edge)
                createdEdgesByDiagram.append((diagram.id, edge))
            }
        }
    }

    public mutating func undo(on project: inout UMLProject) {
        for (diagramID, edge) in createdEdgesByDiagram {
            if let index = project.diagrams.firstIndex(where: { $0.id == diagramID }) {
                project.diagrams[index].edges.removeAll { $0.id == edge.id }
            }
        }
        project.model.relationships.removeAll { $0.id == relationship.id }
    }
}

/// Updates a relationship's semantic properties and optionally its visual routing style in the active diagram.
public struct UpdateRelationshipCommand: ProjectCommand {
    public let commandName: String
    private let oldRelationship: UMLRelationship
    private let newRelationship: UMLRelationship
    private let diagramID: UUID?
    private let oldRoutingStyle: EdgeRoutingStyle?
    private let newRoutingStyle: EdgeRoutingStyle?

    public init(
        oldRelationship: UMLRelationship,
        newRelationship: UMLRelationship,
        diagramID: UUID? = nil,
        oldRoutingStyle: EdgeRoutingStyle? = nil,
        newRoutingStyle: EdgeRoutingStyle? = nil
    ) {
        self.oldRelationship = oldRelationship
        self.newRelationship = newRelationship
        self.diagramID = diagramID
        self.oldRoutingStyle = oldRoutingStyle
        self.newRoutingStyle = newRoutingStyle
        self.commandName = "Editar Relación"
    }

    public mutating func execute(on project: inout UMLProject) {
        project.model.upsertRelationship(newRelationship)
        applyRoutingStyle(newRoutingStyle, on: &project)
    }

    public mutating func undo(on project: inout UMLProject) {
        project.model.upsertRelationship(oldRelationship)
        applyRoutingStyle(oldRoutingStyle, on: &project)
    }

    private func applyRoutingStyle(_ style: EdgeRoutingStyle?, on project: inout UMLProject) {
        guard let style, let diagramID,
              let dIdx = project.diagrams.firstIndex(where: { $0.id == diagramID }),
              let eIdx = project.diagrams[dIdx].edges.firstIndex(where: { $0.relationshipID == newRelationship.id }) else {
            return
        }
        project.diagrams[dIdx].edges[eIdx].routingStyle = style
    }
}

/// Deletes a relationship from `UMLModel` and removes all its edge presentations across diagrams.
public struct DeleteRelationshipCommand: ProjectCommand {
    public let commandName: String
    private let relationshipID: UUID
    private var deletedRelationship: UMLRelationship?
    private var removedEdgesByDiagram: [(diagramID: UUID, edge: DiagramEdgeView)] = []

    public init(relationshipID: UUID) {
        self.relationshipID = relationshipID
        self.commandName = "Eliminar Relación"
    }

    public mutating func execute(on project: inout UMLProject) {
        guard let relationship = project.model.relationship(for: relationshipID) else { return }
        deletedRelationship = relationship
        removedEdgesByDiagram = []

        for index in project.diagrams.indices {
            let matching = project.diagrams[index].edges.filter { $0.relationshipID == relationshipID }
            for edge in matching {
                removedEdgesByDiagram.append((project.diagrams[index].id, edge))
            }
            project.diagrams[index].edges.removeAll { $0.relationshipID == relationshipID }
        }

        project.model.relationships.removeAll { $0.id == relationshipID }
    }

    public mutating func undo(on project: inout UMLProject) {
        guard let deletedRelationship else { return }
        project.model.upsertRelationship(deletedRelationship)
        for (diagramID, edge) in removedEdgesByDiagram {
            if let index = project.diagrams.firstIndex(where: { $0.id == diagramID }),
               !project.diagrams[index].edges.contains(where: { $0.id == edge.id }) {
                project.diagrams[index].edges.append(edge)
            }
        }
    }
}
