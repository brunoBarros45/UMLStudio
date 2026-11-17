import CoreGraphics
import Foundation
import UMLDomain

/// Arranges diagram nodes in a clean multi-column grid respecting node dimensions.
public struct GridLayoutStrategy: LayoutStrategyPort {
    public let strategyName: String = "Grilla Ordenada"
    private let columns: Int
    private let horizontalSpacing: CGFloat
    private let verticalSpacing: CGFloat

    public init(columns: Int = 3, horizontalSpacing: CGFloat = 110, verticalSpacing: CGFloat = 90) {
        self.columns = max(1, columns)
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func layout(nodes: [DiagramNodeView], model: UMLModel, startOrigin: CGPoint) -> [UUID: CGPoint] {
        guard !nodes.isEmpty else { return [:] }
        var positions: [UUID: CGPoint] = [:]

        let columnCount = min(columns, max(1, Int(ceil(sqrt(Double(nodes.count))))))
        var rowY = startOrigin.y
        var index = 0

        while index < nodes.count {
            let rowSlice = Array(nodes[index..<min(index + columnCount, nodes.count)])
            var currentX = startOrigin.x
            var maxRowHeight: CGFloat = 0

            for node in rowSlice {
                let size = sizeForNode(node, model: model)
                positions[node.id] = CGPoint(x: snap(currentX), y: snap(rowY))
                currentX += size.width + horizontalSpacing
                maxRowHeight = max(maxRowHeight, size.height)
            }

            rowY += maxRowHeight + verticalSpacing
            index += columnCount
        }

        return positions
    }

    private func sizeForNode(_ node: DiagramNodeView, model: UMLModel) -> CGSize {
        if let classifier = model.classifier(for: node.classifierID) {
            return node.estimatedSize(for: classifier)
        }
        return CGSize(width: node.width, height: node.minHeight)
    }

    private func snap(_ value: CGFloat) -> CGFloat {
        (value / 16).rounded() * 16
    }
}

/// Arranges nodes into architectural tiers: interfaces & superclasses at the top,
/// domain classes in the middle, and composed/dependent classes below.
public struct HierarchicalLayoutStrategy: LayoutStrategyPort {
    public let strategyName: String = "Jerárquico UML"
    private let horizontalSpacing: CGFloat
    private let verticalSpacing: CGFloat

    public init(horizontalSpacing: CGFloat = 110, verticalSpacing: CGFloat = 100) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func layout(nodes: [DiagramNodeView], model: UMLModel, startOrigin: CGPoint) -> [UUID: CGPoint] {
        guard !nodes.isEmpty else { return [:] }

        // Compute topological depth based on generalization/realization/composition
        var levelByClassifier: [UUID: Int] = [:]
        for node in nodes {
            levelByClassifier[node.classifierID] = 0
        }

        // Interfaces and enums default to tier 0; subclasses/implementors move down below their parents
        for _ in 0..<nodes.count {
            for rel in model.relationships {
                switch rel.kind {
                case .generalization, .realization:
                    // source inherits/implements target => source belongs below target
                    if let targetLevel = levelByClassifier[rel.target.classifierID] {
                        let current = levelByClassifier[rel.source.classifierID] ?? 0
                        levelByClassifier[rel.source.classifierID] = max(current, targetLevel + 1)
                    }
                case .composition, .aggregation:
                    // source is whole, target is part => part belongs below whole
                    if let sourceLevel = levelByClassifier[rel.source.classifierID] {
                        let current = levelByClassifier[rel.target.classifierID] ?? 0
                        levelByClassifier[rel.target.classifierID] = max(current, sourceLevel + 1)
                    }
                case .association, .directedAssociation, .dependency:
                    break
                }
            }
        }

        let grouped = Dictionary(grouping: nodes) { node in
            levelByClassifier[node.classifierID] ?? 0
        }
        let sortedLevels = grouped.keys.sorted()

        var positions: [UUID: CGPoint] = [:]
        var currentY = startOrigin.y

        for level in sortedLevels {
            let tierNodes = (grouped[level] ?? []).sorted { a, b in
                let nameA = model.classifier(for: a.classifierID)?.name ?? ""
                let nameB = model.classifier(for: b.classifierID)?.name ?? ""
                return nameA < nameB
            }

            var currentX = startOrigin.x
            var maxTierHeight: CGFloat = 0

            for node in tierNodes {
                let size = model.classifier(for: node.classifierID).map { node.estimatedSize(for: $0) }
                    ?? CGSize(width: node.width, height: node.minHeight)
                positions[node.id] = CGPoint(x: snap(currentX), y: snap(currentY))
                currentX += size.width + horizontalSpacing
                maxTierHeight = max(maxTierHeight, size.height)
            }

            currentY += maxTierHeight + verticalSpacing
        }

        return positions
    }

    private func snap(_ value: CGFloat) -> CGFloat {
        (value / 16).rounded() * 16
    }
}
