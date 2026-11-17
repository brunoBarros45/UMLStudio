import SwiftUI
import UMLApplication
import UMLDomain

/// Interactive 2D vector canvas with free simultaneous X/Y movement and panning,
/// zoom gestures, click-and-hold node dragging, connection port dragging, and edge hit-testing.
public struct DiagramCanvasView: View {
    @Bindable public var workspaceVM: WorkspaceViewModel
    @Bindable public var interactionVM: CanvasInteractionViewModel

    @State private var baseMagnification: CGFloat = 1.0
    @State private var pendingClickSourceID: UUID?
    @State private var lastTapInfo: (id: UUID, time: Date)?

    private let canvasSize = CGSize(width: 3600, height: 2600)

    public init(workspaceVM: WorkspaceViewModel, interactionVM: CanvasInteractionViewModel) {
        self.workspaceVM = workspaceVM
        self.interactionVM = interactionVM
    }

    public var body: some View {
        let diagram = workspaceVM.activeDiagram ?? UMLDiagram(name: "Diagrama")
        let zoom = diagram.zoomScale

        GeometryReader { viewportGeo in
            ZStack(alignment: .topLeading) {
                canvasContent(diagram: diagram)
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .coordinateSpace(name: "UMLDiagramCanvas")
                    .scaleEffect(zoom, anchor: .topLeading)
                    .offset(interactionVM.panOffset)
            }
            .frame(width: viewportGeo.size.width, height: viewportGeo.size.height, alignment: .topLeading)
            .background(Color(nsColor: .textBackgroundColor))
            .clipped()
            .contentShape(Rectangle())
            .coordinateSpace(name: "ViewportSpace")
        }
        .gesture(magnificationGesture)
        .overlay(alignment: .bottomLeading) {
            bottomStatusHUD(diagram: diagram)
        }
        .overlay(alignment: .top) {
            if case .connect(let kind) = interactionVM.activeTool {
                connectionModeBanner(kind: kind)
            } else if case .addClassifier(let kind) = interactionVM.activeTool {
                placementModeBanner(kind: kind)
            }
        }
        .onAppear {
            baseMagnification = diagram.zoomScale
        }
        .popover(item: quickEditClassifierBinding) { classifier in
            QuickEditPopoverView(workspaceVM: workspaceVM, classifier: classifier) {
                interactionVM.quickEditClassifierID = nil
            }
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                workspaceVM.setZoomScale(baseMagnification * value)
            }
            .onEnded { _ in
                baseMagnification = workspaceVM.activeDiagram?.zoomScale ?? 1.0
            }
    }

    private var quickEditClassifierBinding: Binding<UMLClassifier?> {
        Binding(
            get: {
                interactionVM.quickEditClassifierID.flatMap { workspaceVM.project.model.classifier(for: $0) }
            },
            set: { updated in
                if updated == nil {
                    interactionVM.quickEditClassifierID = nil
                }
            }
        )
    }

    @ViewBuilder
    private func canvasContent(diagram: UMLDiagram) -> some View {
        ZStack(alignment: .topLeading) {
            canvasBackgroundLayer(diagram: diagram)

            RelationshipEdgeCanvasLayer(
                diagram: diagram,
                model: workspaceVM.project.model,
                selectedRelationshipID: workspaceVM.selectedRelationshipID,
                liveNodePositions: liveNodePositionOverrides(diagram: diagram),
                pendingConnection: interactionVM.pendingConnection,
                canvasBackground: Color(nsColor: .textBackgroundColor)
            )

            nodesLayer(diagram: diagram)
        }
    }

    @ViewBuilder
    private func nodesLayer(diagram: UMLDiagram) -> some View {
        ForEach(diagram.nodes) { node in
            if let classifier = workspaceVM.project.model.classifier(for: node.classifierID) {
                nodeCardView(node: node, classifier: classifier, diagram: diagram)
            }
        }
    }

    @ViewBuilder
    private func nodeCardView(node: DiagramNodeView, classifier: UMLClassifier, diagram: UMLDiagram) -> some View {
        let effectiveNode = effectiveNodeView(node)
        let box = effectiveNode.boundingBox(for: classifier)
        let selected = workspaceVM.selectedClassifierID == classifier.id || pendingClickSourceID == classifier.id
        let hovered = interactionVM.hoveredClassifierID == classifier.id
        let showPorts = interactionVM.activeTool == .select || interactionVM.activeTool.isConnectionTool

        ClassifierCardView(
            classifier: classifier,
            node: effectiveNode,
            isSelected: selected,
            isHovered: hovered,
            showPorts: showPorts,
            onQuickEdit: {
                workspaceVM.selectClassifier(classifier.id)
                interactionVM.quickEditClassifierID = classifier.id
            },
            onPortDragChanged: { startPoint, currentPoint in
                beginPortDrag(from: classifier.id, startPoint: startPoint, currentPoint: currentPoint)
            },
            onPortDragEnded: { dropPoint in
                completePendingConnection(at: dropPoint, diagram: diagram)
            }
        )
        .frame(width: box.width, height: box.height)
        .contentShape(Rectangle())
        .onHover { isHovering in
            interactionVM.hoveredClassifierID = isHovering ? classifier.id : nil
        }
        .gesture(nodeInteractionGesture(for: node, classifier: classifier, diagram: diagram))
        .contextMenu {
            nodeContextMenu(classifier: classifier)
        }
        .position(
            x: effectiveNode.position.x + box.width / 2,
            y: effectiveNode.position.y + box.height / 2
        )
    }

    private func beginPortDrag(from classifierID: UUID, startPoint: CGPoint, currentPoint: CGPoint) {
        let kind: UMLRelationshipKind
        if case .connect(let selectedKind) = interactionVM.activeTool {
            kind = selectedKind
        } else {
            kind = .directedAssociation
        }
        interactionVM.pendingConnection = PendingConnection(
            sourceClassifierID: classifierID,
            sourcePoint: startPoint,
            currentPoint: currentPoint,
            relationshipKind: kind
        )
    }

    // MARK: - Sublayers & Gestures

    @ViewBuilder
    private func canvasBackgroundLayer(diagram: UMLDiagram) -> some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .textBackgroundColor)

            if diagram.showGrid {
                Canvas { context, size in
                    let step: CGFloat = 16
                    let majorStep: CGFloat = 80
                    var minorPath = Path()
                    var majorPath = Path()

                    var x: CGFloat = 0
                    while x <= size.width {
                        if Int(x) % Int(majorStep) == 0 {
                            majorPath.move(to: CGPoint(x: x, y: 0))
                            majorPath.addLine(to: CGPoint(x: x, y: size.height))
                        } else {
                            minorPath.move(to: CGPoint(x: x, y: 0))
                            minorPath.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        x += step
                    }

                    var y: CGFloat = 0
                    while y <= size.height {
                        if Int(y) % Int(majorStep) == 0 {
                            majorPath.move(to: CGPoint(x: 0, y: y))
                            majorPath.addLine(to: CGPoint(x: size.width, y: y))
                        } else {
                            minorPath.move(to: CGPoint(x: 0, y: y))
                            minorPath.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        y += step
                    }

                    context.stroke(minorPath, with: .color(Color.primary.opacity(0.035)), lineWidth: 0.7)
                    context.stroke(majorPath, with: .color(Color.primary.opacity(0.075)), lineWidth: 0.9)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(backgroundInteractionGesture(diagram: diagram))
    }

    /// Unified background tap + free 2D X/Y pan gesture measured in stationary `ViewportSpace`.
    private func backgroundInteractionGesture(diagram: UMLDiagram) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("ViewportSpace"))
            .onChanged { value in
                let dist = hypot(value.translation.width, value.translation.height)
                guard dist >= 3 else { return }
                if interactionVM.activeTool == .pan || interactionVM.activeTool == .select {
                    interactionVM.panOffset = CGSize(
                        width: interactionVM.accumulatedPan.width + value.translation.width,
                        height: interactionVM.accumulatedPan.height + value.translation.height
                    )
                }
            }
            .onEnded { value in
                let dist = hypot(value.translation.width, value.translation.height)
                if dist < 3 {
                    let zoom = max(0.1, diagram.zoomScale)
                    let canvasPoint = CGPoint(
                        x: (value.startLocation.x - interactionVM.panOffset.width) / zoom,
                        y: (value.startLocation.y - interactionVM.panOffset.height) / zoom
                    )
                    handleBackgroundTap(at: canvasPoint, diagram: diagram)
                } else if interactionVM.activeTool == .pan || interactionVM.activeTool == .select {
                    interactionVM.accumulatedPan = interactionVM.panOffset
                }
            }
    }

    /// Unified click + free 2-axis X/Y click-and-hold drag gesture attached strictly to node bounds.
    private func nodeInteractionGesture(
        for node: DiagramNodeView,
        classifier: UMLClassifier,
        diagram: UMLDiagram
    ) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("UMLDiagramCanvas"))
            .onChanged { value in
                if case .connect = interactionVM.activeTool {
                    return
                }
                if workspaceVM.selectedClassifierID != classifier.id {
                    workspaceVM.selectClassifier(classifier.id)
                }
                let dist = hypot(value.translation.width, value.translation.height)
                if dist >= 2 || interactionVM.draggedNodeID == node.id {
                    interactionVM.draggedNodeID = node.id
                    interactionVM.dragTranslation = value.translation
                }
            }
            .onEnded { value in
                let dist = hypot(value.translation.width, value.translation.height)
                if dist < 3 && interactionVM.draggedNodeID == nil {
                    handleNodeTap(classifierID: classifier.id)
                    return
                }

                guard interactionVM.draggedNodeID == node.id else {
                    interactionVM.draggedNodeID = nil
                    interactionVM.dragTranslation = .zero
                    return
                }

                let rawTarget = CGPoint(
                    x: max(8, node.position.x + value.translation.width),
                    y: max(8, node.position.y + value.translation.height)
                )
                let finalPos = interactionVM.snapPoint(rawTarget, enabled: diagram.snapToGrid)
                interactionVM.draggedNodeID = nil
                interactionVM.dragTranslation = .zero
                workspaceVM.commitNodeMove(nodeID: node.id, from: node.position, to: finalPos)
            }
    }

    private func handleNodeTap(classifierID: UUID) {
        if case .connect(let kind) = interactionVM.activeTool {
            if let sourceID = pendingClickSourceID {
                workspaceVM.createRelationship(kind: kind, sourceClassifierID: sourceID, targetClassifierID: classifierID)
                pendingClickSourceID = nil
                interactionVM.activeTool = .select
            } else {
                pendingClickSourceID = classifierID
                workspaceVM.selectClassifier(classifierID)
            }
            return
        }

        pendingClickSourceID = nil
        workspaceVM.selectClassifier(classifierID)

        let now = Date()
        if let last = lastTapInfo,
           last.id == classifierID,
           now.timeIntervalSince(last.time) < 0.35 {
            lastTapInfo = nil
            interactionVM.quickEditClassifierID = classifierID
        } else {
            lastTapInfo = (classifierID, now)
        }
    }

    private func handleBackgroundTap(at point: CGPoint, diagram: UMLDiagram) {
        pendingClickSourceID = nil

        switch interactionVM.activeTool {
        case .addClassifier(let kind):
            let snapped = interactionVM.snapPoint(point, enabled: diagram.snapToGrid)
            workspaceVM.addClassifier(kind: kind, at: snapped)
            interactionVM.activeTool = .select

        case .select, .pan, .connect:
            if let hitRelID = hitTestRelationship(at: point, diagram: diagram) {
                workspaceVM.selectRelationship(hitRelID)
            } else {
                workspaceVM.clearSelection()
            }
        }
    }

    private func completePendingConnection(at dropPoint: CGPoint, diagram: UMLDiagram) {
        defer { interactionVM.pendingConnection = nil }
        guard let pending = interactionVM.pendingConnection else { return }

        for node in diagram.nodes {
            guard let classifier = workspaceVM.project.model.classifier(for: node.classifierID) else { continue }
            let box = node.boundingBox(for: classifier).insetBy(dx: -8, dy: -8)
            if box.contains(dropPoint) {
                workspaceVM.createRelationship(
                    kind: pending.relationshipKind,
                    sourceClassifierID: pending.sourceClassifierID,
                    targetClassifierID: node.classifierID
                )
                if interactionVM.activeTool.isConnectionTool {
                    interactionVM.activeTool = .select
                }
                return
            }
        }
    }

    private func hitTestRelationship(at point: CGPoint, diagram: UMLDiagram) -> UUID? {
        var bestID: UUID?
        var bestDist: CGFloat = 11.0

        for edge in diagram.edges {
            guard let rel = workspaceVM.project.model.relationship(for: edge.relationshipID),
                  let sourceNode = diagram.node(forClassifier: rel.source.classifierID),
                  let targetNode = diagram.node(forClassifier: rel.target.classifierID),
                  let sourceCls = workspaceVM.project.model.classifier(for: sourceNode.classifierID),
                  let targetCls = workspaceVM.project.model.classifier(for: targetNode.classifierID) else {
                continue
            }

            let pts = EdgePathCalculator.computePathPoints(
                routingStyle: edge.routingStyle,
                sourceRect: sourceNode.boundingBox(for: sourceCls),
                targetRect: targetNode.boundingBox(for: targetCls),
                waypoints: edge.waypoints,
                isSelfLoop: rel.source.classifierID == rel.target.classifierID
            )
            let d = EdgePathCalculator.distanceFromPoint(point, toPolyline: pts)
            if d < bestDist {
                bestDist = d
                bestID = rel.id
            }
        }
        return bestID
    }

    private func effectiveNodeView(_ node: DiagramNodeView) -> DiagramNodeView {
        guard interactionVM.draggedNodeID == node.id else { return node }
        var moved = node
        moved.position = CGPoint(
            x: max(8, node.position.x + interactionVM.dragTranslation.width),
            y: max(8, node.position.y + interactionVM.dragTranslation.height)
        )
        return moved
    }

    private func liveNodePositionOverrides(diagram: UMLDiagram) -> [UUID: CGPoint] {
        guard let draggedID = interactionVM.draggedNodeID,
              let node = diagram.nodes.first(where: { $0.id == draggedID }) else {
            return [:]
        }
        let moved = effectiveNodeView(node)
        return [draggedID: moved.position]
    }

    @ViewBuilder
    private func nodeContextMenu(classifier: UMLClassifier) -> some View {
        Button("QuickEdit (Atributos / Métodos)...") {
            workspaceVM.selectClassifier(classifier.id)
            interactionVM.quickEditClassifierID = classifier.id
        }
        Menu("Conectar hacia otra entidad...") {
            ForEach(UMLRelationshipKind.allCases, id: \.self) { kind in
                Button(kind.displayName) {
                    pendingClickSourceID = classifier.id
                    interactionVM.activeTool = .connect(kind)
                }
            }
        }
        Divider()
        Button("Quitar solo de este Diagrama") {
            workspaceVM.removeClassifierFromActiveDiagram(classifier.id)
        }
        Button("Eliminar del Modelo Completo", role: .destructive) {
            workspaceVM.deleteClassifierFromModel(classifier.id)
        }
    }

    @ViewBuilder
    private func placementModeBanner(kind: UMLClassifierKind) -> some View {
        HStack(spacing: 10) {
            Image(systemName: kind.systemImageName)
            Text("Hacé clic en el lienzo donde quieras ubicar **\(kind.rawValue)**")
            Button("Cancelar") {
                interactionVM.activeTool = .select
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(radius: 4)
        .padding(.top, 12)
    }

    @ViewBuilder
    private func connectionModeBanner(kind: UMLRelationshipKind) -> some View {
        HStack(spacing: 10) {
            Image(systemName: kind.systemImageName)
            if let sourceID = pendingClickSourceID,
               let sourceName = workspaceVM.project.model.classifier(for: sourceID)?.name {
                Text("Origen: **\(sourceName)** — Seleccioná la entidad destino para **\(kind.displayName)**")
            } else {
                Text("Modo **\(kind.displayName)**: Hacé clic en origen y luego destino (o arrastrá desde un puerto)")
            }
            Button("Cancelar") {
                pendingClickSourceID = nil
                interactionVM.activeTool = .select
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(radius: 4)
        .padding(.top, 12)
    }

    @ViewBuilder
    private func bottomStatusHUD(diagram: UMLDiagram) -> some View {
        HStack(spacing: 12) {
            if diagram.nodes.isEmpty {
                Text("Lienzo vacío: usá '+ Agregar Entidad' o la paleta izquierda para crear clases")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(workspaceVM.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 12)

            Button {
                workspaceVM.setZoomScale(diagram.zoomScale - 0.1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)

            Text("\(Int((diagram.zoomScale * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .frame(width: 40)

            Button {
                workspaceVM.setZoomScale(diagram.zoomScale + 0.1)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)

            Button("100%") {
                workspaceVM.setZoomScale(1.0)
                interactionVM.panOffset = .zero
                interactionVM.accumulatedPan = .zero
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
        .padding(12)
    }
}
