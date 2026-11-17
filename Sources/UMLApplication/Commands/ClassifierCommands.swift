import CoreGraphics
import Foundation
import UMLDomain

/// Adds a new classifier to `UMLModel` and places a corresponding node view in the target diagram.
public struct AddClassifierCommand: ProjectCommand {
    public let commandName: String
    private let classifier: UMLClassifier
    private let diagramID: UUID?
    private let nodeView: DiagramNodeView?

    public init(
        classifier: UMLClassifier,
        diagramID: UUID? = nil,
        position: CGPoint = CGPoint(x: 160, y: 160),
        headerColorHex: String? = nil
    ) {
        self.classifier = classifier
        self.diagramID = diagramID
        self.commandName = "Agregar \(classifier.kind.rawValue) \(classifier.name)"
        if diagramID != nil {
            self.nodeView = DiagramNodeView(
                classifierID: classifier.id,
                position: position,
                headerColorHex: headerColorHex ?? classifier.kind.defaultHeaderHex
            )
        } else {
            self.nodeView = nil
        }
    }

    public mutating func execute(on project: inout UMLProject) {
        project.model.upsertClassifier(classifier)
        if let diagramID,
           let nodeView,
           let diagramIndex = project.diagrams.firstIndex(where: { $0.id == diagramID }),
           !project.diagrams[diagramIndex].contains(classifierID: classifier.id) {
            project.diagrams[diagramIndex].nodes.append(nodeView)
        }
    }

    public mutating func undo(on project: inout UMLProject) {
        if let diagramID,
           let nodeView,
           let diagramIndex = project.diagrams.firstIndex(where: { $0.id == diagramID }) {
            project.diagrams[diagramIndex].nodes.removeAll { $0.id == nodeView.id }
        }
        project.model.classifiers.removeAll { $0.id == classifier.id }
    }
}

/// Updates an existing classifier's semantic data in `UMLModel`, propagating automatically across all diagrams.
public struct UpdateClassifierCommand: ProjectCommand {
    public let commandName: String
    private let oldClassifier: UMLClassifier
    private let newClassifier: UMLClassifier

    public init(oldClassifier: UMLClassifier, newClassifier: UMLClassifier, actionName: String? = nil) {
        self.oldClassifier = oldClassifier
        self.newClassifier = newClassifier
        self.commandName = actionName ?? "Editar \(newClassifier.name)"
    }

    public mutating func execute(on project: inout UMLProject) {
        project.model.upsertClassifier(newClassifier)
    }

    public mutating func undo(on project: inout UMLProject) {
        project.model.upsertClassifier(oldClassifier)
    }
}

/// Permanently deletes a classifier from `UMLModel` along with its relationships and all diagram representations.
/// Captures removed elements so `undo` restores everything identically.
public struct DeleteClassifierFromModelCommand: ProjectCommand {
    public let commandName: String
    private let classifierID: UUID
    private var deletedClassifier: UMLClassifier?
    private var deletedRelationships: [UMLRelationship] = []
    private var removedNodesByDiagram: [(diagramID: UUID, node: DiagramNodeView)] = []
    private var removedEdgesByDiagram: [(diagramID: UUID, edge: DiagramEdgeView)] = []

    public init(classifierID: UUID, classifierName: String = "Clasificador") {
        self.classifierID = classifierID
        self.commandName = "Eliminar \(classifierName) del Modelo"
    }

    public mutating func execute(on project: inout UMLProject) {
        guard let classifier = project.model.classifier(for: classifierID) else { return }
        deletedClassifier = classifier
        deletedRelationships = project.model.relationships(involving: classifierID)
        let deletedRelationshipIDs = Set(deletedRelationships.map(\.id))

        removedNodesByDiagram = []
        removedEdgesByDiagram = []

        for index in project.diagrams.indices {
            let diagramID = project.diagrams[index].id
            let matchingNodes = project.diagrams[index].nodes.filter { $0.classifierID == classifierID }
            for node in matchingNodes {
                removedNodesByDiagram.append((diagramID, node))
            }
            let matchingEdges = project.diagrams[index].edges.filter { deletedRelationshipIDs.contains($0.relationshipID) }
            for edge in matchingEdges {
                removedEdgesByDiagram.append((diagramID, edge))
            }

            project.diagrams[index].nodes.removeAll { $0.classifierID == classifierID }
            project.diagrams[index].edges.removeAll { deletedRelationshipIDs.contains($0.relationshipID) }
        }

        project.model.relationships.removeAll { deletedRelationshipIDs.contains($0.id) }
        project.model.classifiers.removeAll { $0.id == classifierID }
    }

    public mutating func undo(on project: inout UMLProject) {
        guard let deletedClassifier else { return }
        project.model.upsertClassifier(deletedClassifier)
        for relationship in deletedRelationships {
            project.model.upsertRelationship(relationship)
        }
        for (diagramID, node) in removedNodesByDiagram {
            if let index = project.diagrams.firstIndex(where: { $0.id == diagramID }),
               !project.diagrams[index].nodes.contains(where: { $0.id == node.id }) {
                project.diagrams[index].nodes.append(node)
            }
        }
        for (diagramID, edge) in removedEdgesByDiagram {
            if let index = project.diagrams.firstIndex(where: { $0.id == diagramID }),
               !project.diagrams[index].edges.contains(where: { $0.id == edge.id }) {
                project.diagrams[index].edges.append(edge)
            }
        }
    }
}

/// Removes a classifier's visual node ONLY from the specified diagram while keeping it in `UMLModel`.
/// Demonstrates Gaphor's separation between semantic model and visual diagrams.
public struct RemoveNodeFromDiagramCommand: ProjectCommand {
    public let commandName: String
    private let classifierID: UUID
    private let diagramID: UUID
    private var removedNode: DiagramNodeView?
    private var removedEdges: [DiagramEdgeView] = []

    public init(classifierID: UUID, diagramID: UUID, classifierName: String = "Nodo") {
        self.classifierID = classifierID
        self.diagramID = diagramID
        self.commandName = "Quitar \(classifierName) del Diagrama"
    }

    public mutating func execute(on project: inout UMLProject) {
        guard let diagramIndex = project.diagrams.firstIndex(where: { $0.id == diagramID }),
              let node = project.diagrams[diagramIndex].nodes.first(where: { $0.classifierID == classifierID }) else {
            return
        }

        removedNode = node
        let relatedIDs = Set(project.model.relationships(involving: classifierID).map(\.id))
        removedEdges = project.diagrams[diagramIndex].edges.filter { relatedIDs.contains($0.relationshipID) }

        project.diagrams[diagramIndex].nodes.removeAll { $0.id == node.id }
        project.diagrams[diagramIndex].edges.removeAll { relatedIDs.contains($0.relationshipID) }
    }

    public mutating func undo(on project: inout UMLProject) {
        guard let removedNode,
              let diagramIndex = project.diagrams.firstIndex(where: { $0.id == diagramID }) else {
            return
        }
        if !project.diagrams[diagramIndex].nodes.contains(where: { $0.id == removedNode.id }) {
            project.diagrams[diagramIndex].nodes.append(removedNode)
        }
        for edge in removedEdges {
            if !project.diagrams[diagramIndex].edges.contains(where: { $0.id == edge.id }) {
                project.diagrams[diagramIndex].edges.append(edge)
            }
        }
    }
}

/// Places an already-existing semantic classifier from `UMLModel` onto a diagram,
/// automatically rendering edges for relationships whose other end is already visible in that diagram.
public struct AddExistingClassifierToDiagramCommand: ProjectCommand {
    public let commandName: String
    private let classifierID: UUID
    private let diagramID: UUID
    private let nodeView: DiagramNodeView
    private var createdEdges: [DiagramEdgeView] = []

    public init(
        classifierID: UUID,
        diagramID: UUID,
        position: CGPoint,
        headerColorHex: String? = nil,
        classifierName: String = "Clasificador"
    ) {
        self.classifierID = classifierID
        self.diagramID = diagramID
        self.nodeView = DiagramNodeView(
            classifierID: classifierID,
            position: position,
            headerColorHex: headerColorHex
        )
        self.commandName = "Mostrar \(classifierName) en Diagrama"
    }

    public mutating func execute(on project: inout UMLProject) {
        guard let diagramIndex = project.diagrams.firstIndex(where: { $0.id == diagramID }),
              !project.diagrams[diagramIndex].contains(classifierID: classifierID),
              project.model.classifier(for: classifierID) != nil else {
            return
        }

        project.diagrams[diagramIndex].nodes.append(nodeView)

        let existingClassifierIDs = Set(project.diagrams[diagramIndex].nodes.map(\.classifierID))
        let existingEdgeRelIDs = Set(project.diagrams[diagramIndex].edges.map(\.relationshipID))

        createdEdges = []
        for relationship in project.model.relationships(involving: classifierID) {
            let bothVisible = existingClassifierIDs.contains(relationship.source.classifierID)
                && existingClassifierIDs.contains(relationship.target.classifierID)
            if bothVisible && !existingEdgeRelIDs.contains(relationship.id) {
                let edge = DiagramEdgeView(relationshipID: relationship.id)
                createdEdges.append(edge)
                project.diagrams[diagramIndex].edges.append(edge)
            }
        }
    }

    public mutating func undo(on project: inout UMLProject) {
        guard let diagramIndex = project.diagrams.firstIndex(where: { $0.id == diagramID }) else { return }
        let createdEdgeIDs = Set(createdEdges.map(\.id))
        project.diagrams[diagramIndex].edges.removeAll { createdEdgeIDs.contains($0.id) }
        project.diagrams[diagramIndex].nodes.removeAll { $0.id == nodeView.id }
    }
}
