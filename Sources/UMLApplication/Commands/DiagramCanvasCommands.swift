import CoreGraphics
import Foundation
import UMLDomain

/// Moves a diagram node to a new canvas position with undo support.
public struct MoveNodeCommand: ProjectCommand {
    public let commandName: String = "Mover Nodo"
    private let diagramID: UUID
    private let nodeID: UUID
    private let fromPosition: CGPoint
    private let toPosition: CGPoint

    public init(diagramID: UUID, nodeID: UUID, fromPosition: CGPoint, toPosition: CGPoint) {
        self.diagramID = diagramID
        self.nodeID = nodeID
        self.fromPosition = fromPosition
        self.toPosition = toPosition
    }

    public mutating func execute(on project: inout UMLProject) {
        setPosition(toPosition, on: &project)
    }

    public mutating func undo(on project: inout UMLProject) {
        setPosition(fromPosition, on: &project)
    }

    private func setPosition(_ position: CGPoint, on project: inout UMLProject) {
        guard let dIdx = project.diagrams.firstIndex(where: { $0.id == diagramID }),
              let nIdx = project.diagrams[dIdx].nodes.firstIndex(where: { $0.id == nodeID }) else {
            return
        }
        project.diagrams[dIdx].nodes[nIdx].position = position
    }
}

/// Updates visual presentation options for a node (e.g., header color or compartment visibility).
public struct UpdateNodePresentationCommand: ProjectCommand {
    public let commandName: String = "Actualizar Apariencia del Nodo"
    private let diagramID: UUID
    private let oldNode: DiagramNodeView
    private let newNode: DiagramNodeView

    public init(diagramID: UUID, oldNode: DiagramNodeView, newNode: DiagramNodeView) {
        self.diagramID = diagramID
        self.oldNode = oldNode
        self.newNode = newNode
    }

    public mutating func execute(on project: inout UMLProject) {
        applyNode(newNode, on: &project)
    }

    public mutating func undo(on project: inout UMLProject) {
        applyNode(oldNode, on: &project)
    }

    private func applyNode(_ node: DiagramNodeView, on project: inout UMLProject) {
        guard let dIdx = project.diagrams.firstIndex(where: { $0.id == diagramID }),
              let nIdx = project.diagrams[dIdx].nodes.firstIndex(where: { $0.id == node.id }) else {
            return
        }
        project.diagrams[dIdx].nodes[nIdx] = node
    }
}

/// Applies a `LayoutStrategyPort` to reposition all nodes in a diagram while storing prior positions for undo.
public struct ApplyLayoutCommand: ProjectCommand {
    public let commandName: String
    private let diagramID: UUID
    private let strategy: any LayoutStrategyPort
    private let startOrigin: CGPoint
    private var previousPositions: [UUID: CGPoint] = [:]
    private var computedPositions: [UUID: CGPoint] = [:]

    public init(
        diagramID: UUID,
        strategy: any LayoutStrategyPort,
        startOrigin: CGPoint = CGPoint(x: 80, y: 80)
    ) {
        self.diagramID = diagramID
        self.strategy = strategy
        self.startOrigin = startOrigin
        self.commandName = "Auto-Layout (\(strategy.strategyName))"
    }

    public mutating func execute(on project: inout UMLProject) {
        guard let dIdx = project.diagrams.firstIndex(where: { $0.id == diagramID }) else { return }

        if previousPositions.isEmpty {
            for node in project.diagrams[dIdx].nodes {
                previousPositions[node.id] = node.position
            }
            computedPositions = strategy.layout(
                nodes: project.diagrams[dIdx].nodes,
                model: project.model,
                startOrigin: startOrigin
            )
        }

        for nIdx in project.diagrams[dIdx].nodes.indices {
            let nodeID = project.diagrams[dIdx].nodes[nIdx].id
            if let pos = computedPositions[nodeID] {
                project.diagrams[dIdx].nodes[nIdx].position = pos
            }
        }
    }

    public mutating func undo(on project: inout UMLProject) {
        guard let dIdx = project.diagrams.firstIndex(where: { $0.id == diagramID }) else { return }
        for nIdx in project.diagrams[dIdx].nodes.indices {
            let nodeID = project.diagrams[dIdx].nodes[nIdx].id
            if let pos = previousPositions[nodeID] {
                project.diagrams[dIdx].nodes[nIdx].position = pos
            }
        }
    }
}
