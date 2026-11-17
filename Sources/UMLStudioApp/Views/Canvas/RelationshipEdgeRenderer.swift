import SwiftUI
import UMLApplication
import UMLDomain

/// Vector layer rendering all UML 2.5 relationship edges, arrowheads, multiplicity badges, and role labels.
public struct RelationshipEdgeCanvasLayer: View {
    public let diagram: UMLDiagram
    public let model: UMLModel
    public let selectedRelationshipID: UUID?
    public let liveNodePositions: [UUID: CGPoint]
    public let pendingConnection: PendingConnection?
    public let canvasBackground: Color

    public init(
        diagram: UMLDiagram,
        model: UMLModel,
        selectedRelationshipID: UUID?,
        liveNodePositions: [UUID: CGPoint] = [:],
        pendingConnection: PendingConnection? = nil,
        canvasBackground: Color = Color(nsColor: .windowBackgroundColor)
    ) {
        self.diagram = diagram
        self.model = model
        self.selectedRelationshipID = selectedRelationshipID
        self.liveNodePositions = liveNodePositions
        self.pendingConnection = pendingConnection
        self.canvasBackground = canvasBackground
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for edge in diagram.edges {
                    guard let relationship = model.relationship(for: edge.relationshipID),
                          let points = polyline(for: edge, relationship: relationship) else {
                        continue
                    }

                    let isSelected = relationship.id == selectedRelationshipID
                    let strokeColor = isSelected ? Color.accentColor : Color.primary.opacity(0.85)
                    let lineWidth: CGFloat = isSelected ? 2.4 : 1.5

                    var path = Path()
                    path.addLines(points)

                    if relationship.kind.isDashed {
                        context.stroke(
                            path,
                            with: .color(strokeColor),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round, dash: [6, 4])
                        )
                    } else {
                        context.stroke(
                            path,
                            with: .color(strokeColor),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                    }

                    drawMarkers(
                        context: &context,
                        kind: relationship.kind,
                        points: points,
                        strokeColor: strokeColor,
                        lineWidth: lineWidth
                    )
                }

                if let pending = pendingConnection {
                    var previewPath = Path()
                    previewPath.move(to: pending.sourcePoint)
                    previewPath.addLine(to: pending.currentPoint)
                    context.stroke(
                        previewPath,
                        with: .color(Color.accentColor),
                        style: StrokeStyle(lineWidth: 2, dash: [5, 4])
                    )
                }
            }
            .allowsHitTesting(false)

            // Crisp SwiftUI text badges for relationship names, roles, and multiplicities
            ForEach(diagram.edges) { edge in
                if let relationship = model.relationship(for: edge.relationshipID),
                   let points = polyline(for: edge, relationship: relationship),
                   points.count >= 2 {
                    edgeLabelsOverlay(relationship: relationship, points: points, isSelected: relationship.id == selectedRelationshipID)
                }
            }
        }
    }

    private func polyline(for edge: DiagramEdgeView, relationship: UMLRelationship) -> [CGPoint]? {
        guard let sourceNode = diagram.node(forClassifier: relationship.source.classifierID),
              let targetNode = diagram.node(forClassifier: relationship.target.classifierID),
              let sourceClassifier = model.classifier(for: sourceNode.classifierID),
              let targetClassifier = model.classifier(for: targetNode.classifierID) else {
            return nil
        }

        var effectiveSourceNode = sourceNode
        if let overridePos = liveNodePositions[sourceNode.id] {
            effectiveSourceNode.position = overridePos
        }
        var effectiveTargetNode = targetNode
        if let overridePos = liveNodePositions[targetNode.id] {
            effectiveTargetNode.position = overridePos
        }

        let sourceRect = effectiveSourceNode.boundingBox(for: sourceClassifier)
        let targetRect = effectiveTargetNode.boundingBox(for: targetClassifier)
        let isSelfLoop = relationship.source.classifierID == relationship.target.classifierID

        return EdgePathCalculator.computePathPoints(
            routingStyle: edge.routingStyle,
            sourceRect: sourceRect,
            targetRect: targetRect,
            waypoints: edge.waypoints,
            isSelfLoop: isSelfLoop
        )
    }

    private func drawMarkers(
        context: inout GraphicsContext,
        kind: UMLRelationshipKind,
        points: [CGPoint],
        strokeColor: Color,
        lineWidth: CGFloat
    ) {
        guard points.count >= 2 else { return }
        let start = points[0]
        let afterStart = points[1]
        let beforeEnd = points[points.count - 2]
        let end = points[points.count - 1]

        let endAngle = atan2(end.y - beforeEnd.y, end.x - beforeEnd.x)
        let startAngle = atan2(start.y - afterStart.y, start.x - afterStart.x)

        switch kind {
        case .association:
            break
        case .directedAssociation, .dependency:
            drawOpenArrow(context: &context, tip: end, angle: endAngle, color: strokeColor, lineWidth: lineWidth)
        case .generalization, .realization:
            drawHollowTriangle(context: &context, tip: end, angle: endAngle, strokeColor: strokeColor, lineWidth: lineWidth)
        case .aggregation:
            drawDiamond(context: &context, tip: start, angle: startAngle, filled: false, strokeColor: strokeColor, lineWidth: lineWidth)
        case .composition:
            drawDiamond(context: &context, tip: start, angle: startAngle, filled: true, strokeColor: strokeColor, lineWidth: lineWidth)
        }
    }

    private func drawOpenArrow(
        context: inout GraphicsContext,
        tip: CGPoint,
        angle: CGFloat,
        color: Color,
        lineWidth: CGFloat
    ) {
        let len: CGFloat = 12
        let spread: CGFloat = 0.45
        let p1 = CGPoint(x: tip.x - len * cos(angle - spread), y: tip.y - len * sin(angle - spread))
        let p2 = CGPoint(x: tip.x - len * cos(angle + spread), y: tip.y - len * sin(angle + spread))

        var path = Path()
        path.move(to: p1)
        path.addLine(to: tip)
        path.addLine(to: p2)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }

    private func drawHollowTriangle(
        context: inout GraphicsContext,
        tip: CGPoint,
        angle: CGFloat,
        strokeColor: Color,
        lineWidth: CGFloat
    ) {
        let len: CGFloat = 15
        let spread: CGFloat = 0.46
        let p1 = CGPoint(x: tip.x - len * cos(angle - spread), y: tip.y - len * sin(angle - spread))
        let p2 = CGPoint(x: tip.x - len * cos(angle + spread), y: tip.y - len * sin(angle + spread))

        var path = Path()
        path.move(to: tip)
        path.addLine(to: p1)
        path.addLine(to: p2)
        path.closeSubpath()

        context.fill(path, with: .color(canvasBackground))
        context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
    }

    private func drawDiamond(
        context: inout GraphicsContext,
        tip: CGPoint,
        angle: CGFloat,
        filled: Bool,
        strokeColor: Color,
        lineWidth: CGFloat
    ) {
        let halfLen: CGFloat = 9.5
        let halfWidth: CGFloat = 5.5
        // Diamond extends inward along the line (away from `tip`, which points toward the source box)
        let dirX = -cos(angle)
        let dirY = -sin(angle)
        let perpX = -dirY
        let perpY = dirX

        let pMid1 = CGPoint(
            x: tip.x + dirX * halfLen + perpX * halfWidth,
            y: tip.y + dirY * halfLen + perpY * halfWidth
        )
        let pFar = CGPoint(
            x: tip.x + dirX * (halfLen * 2),
            y: tip.y + dirY * (halfLen * 2)
        )
        let pMid2 = CGPoint(
            x: tip.x + dirX * halfLen - perpX * halfWidth,
            y: tip.y + dirY * halfLen - perpY * halfWidth
        )

        var path = Path()
        path.move(to: tip)
        path.addLine(to: pMid1)
        path.addLine(to: pFar)
        path.addLine(to: pMid2)
        path.closeSubpath()

        context.fill(path, with: .color(filled ? strokeColor : canvasBackground))
        context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
    }

    @ViewBuilder
    private func edgeLabelsOverlay(relationship: UMLRelationship, points: [CGPoint], isSelected: Bool) -> some View {
        let mid = EdgePathCalculator.polylineMidpoint(points)
        let sourceLabelPos = endpointLabelPosition(from: points[0], toward: points[1], distance: 26)
        let targetLabelPos = endpointLabelPosition(
            from: points[points.count - 1],
            toward: points[points.count - 2],
            distance: 26
        )

        ZStack {
            if let name = relationship.name, !name.isEmpty {
                Text(name)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(canvasBackground.opacity(0.92))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.25), lineWidth: 0.8)
                    )
                    .position(mid)
            }

            if let sourceText = formattedEndLabel(relationship.source) {
                Text(sourceText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(canvasBackground.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .position(sourceLabelPos)
            }

            if let targetText = formattedEndLabel(relationship.target) {
                Text(targetText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(canvasBackground.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .position(targetLabelPos)
            }
        }
        .allowsHitTesting(false)
    }

    private func formattedEndLabel(_ end: UMLRelationshipEnd) -> String? {
        let parts = [end.multiplicity, end.roleName].compactMap { val -> String? in
            guard let val, !val.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return val
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func endpointLabelPosition(from edgePt: CGPoint, toward nextPt: CGPoint, distance: CGFloat) -> CGPoint {
        let dx = nextPt.x - edgePt.x
        let dy = nextPt.y - edgePt.y
        let len = max(1, hypot(dx, dy))
        let ux = dx / len
        let uy = dy / len
        let perpX = -uy * 13
        let perpY = ux * 13
        return CGPoint(
            x: edgePt.x + ux * distance + perpX,
            y: edgePt.y + uy * distance + perpY
        )
    }
}
