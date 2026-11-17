import CoreGraphics
import Foundation
import Observation
import UMLDomain

public enum CanvasTool: Equatable, Hashable, Sendable {
    case select
    case pan
    case addClassifier(UMLClassifierKind)
    case connect(UMLRelationshipKind)

    public var displayName: String {
        switch self {
        case .select: return "Seleccionar"
        case .pan: return "Mover Lienzo"
        case .addClassifier(let kind): return "Nueva \(kind.rawValue)"
        case .connect(let kind): return "Conectar (\(kind.displayName))"
        }
    }

    public var isConnectionTool: Bool {
        if case .connect = self { return true }
        return false
    }
}

public struct PendingConnection: Equatable {
    public let sourceClassifierID: UUID
    public let sourcePoint: CGPoint
    public var currentPoint: CGPoint
    public let relationshipKind: UMLRelationshipKind
}

/// Segregated ViewModel managing ephemeral canvas interactions (active tool, drag state,
/// live connection preview, pan offset, and modal triggers) separately from semantic state.
@Observable
@MainActor
public final class CanvasInteractionViewModel {
    public var activeTool: CanvasTool = .select
    public var panOffset: CGSize = .zero
    public var accumulatedPan: CGSize = .zero

    public var draggedNodeID: UUID?
    public var dragTranslation: CGSize = .zero

    public var pendingConnection: PendingConnection?
    public var hoveredClassifierID: UUID?

    public var isShowingMermaidSheet: Bool = false
    public var quickEditClassifierID: UUID?

    public init() {}

    public func snapPoint(_ point: CGPoint, enabled: Bool, gridSize: CGFloat = 16) -> CGPoint {
        guard enabled else { return point }
        return CGPoint(
            x: (point.x / gridSize).rounded() * gridSize,
            y: (point.y / gridSize).rounded() * gridSize
        )
    }

    public func resetTransientInteractions() {
        draggedNodeID = nil
        dragTranslation = .zero
        pendingConnection = nil
    }
}
