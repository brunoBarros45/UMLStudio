import AppKit
import Foundation
import Observation
import UMLApplication
import UMLDomain
import UMLInfrastructure
import UniformTypeIdentifiers

/// Segregated ViewModel responsible for project lifecycle, command execution (Undo/Redo),
/// diagram management, file persistence, and Mermaid integration.
@Observable
@MainActor
public final class WorkspaceViewModel {
    public private(set) var project: UMLProject
    public var activeDiagramID: UUID
    public var selectedClassifierID: UUID?
    public var selectedRelationshipID: UUID?
    public private(set) var currentFileURL: URL?
    public var alertMessage: String?
    public var statusText: String = "Listo"

    // Reactive mirror properties updated on command execution/undo/redo
    public private(set) var canUndo: Bool = false
    public private(set) var canRedo: Bool = false
    public private(set) var undoActionName: String?
    public private(set) var redoActionName: String?

    private let repository: any ProjectRepositoryPort
    private let mermaidCodec: any DiagramTextCodecPort
    private let historyManager: CommandHistoryManager

    public init(
        initialProject: UMLProject = UMLProject(
            name: "Mi Proyecto UML",
            model: UMLModel(),
            diagrams: [UMLDiagram(name: "Diagrama de Clases", snapToGrid: false)]
        ),
        repository: any ProjectRepositoryPort = JSONProjectRepository(),
        mermaidCodec: any DiagramTextCodecPort = MermaidClassDiagramCodec(),
        historyManager: CommandHistoryManager = CommandHistoryManager()
    ) {
        self.project = initialProject
        self.activeDiagramID = initialProject.diagrams.first?.id ?? UUID()
        self.repository = repository
        self.mermaidCodec = mermaidCodec
        self.historyManager = historyManager
        syncHistoryState()
    }

    // MARK: - Computed Lookups

    public var activeDiagram: UMLDiagram? {
        project.diagram(for: activeDiagramID) ?? project.diagrams.first
    }

    public var activeDiagramIndex: Int? {
        project.diagrams.firstIndex(where: { $0.id == activeDiagramID })
    }

    public var selectedClassifier: UMLClassifier? {
        guard let selectedClassifierID else { return nil }
        return project.model.classifier(for: selectedClassifierID)
    }

    public var selectedNodeView: DiagramNodeView? {
        guard let selectedClassifierID else { return nil }
        return activeDiagram?.node(forClassifier: selectedClassifierID)
    }

    public var selectedRelationship: UMLRelationship? {
        guard let selectedRelationshipID else { return nil }
        return project.model.relationship(for: selectedRelationshipID)
    }

    public var selectedEdgeView: DiagramEdgeView? {
        guard let selectedRelationshipID else { return nil }
        return activeDiagram?.edge(forRelationship: selectedRelationshipID)
    }

    // MARK: - Selection

    public func selectClassifier(_ id: UUID?) {
        selectedClassifierID = id
        if id != nil {
            selectedRelationshipID = nil
        }
    }

    public func selectRelationship(_ id: UUID?) {
        selectedRelationshipID = id
        if id != nil {
            selectedClassifierID = nil
        }
    }

    public func clearSelection() {
        selectedClassifierID = nil
        selectedRelationshipID = nil
    }

    // MARK: - Command Dispatch & Undo/Redo

    public func run(_ command: any ProjectCommand) {
        historyManager.execute(command, on: &project)
        syncHistoryState()
        statusText = command.commandName
    }

    public func undo() {
        guard historyManager.undo(on: &project) else { return }
        syncHistoryState()
        validateSelections()
        statusText = "Deshacer aplicado"
    }

    public func redo() {
        guard historyManager.redo(on: &project) else { return }
        syncHistoryState()
        validateSelections()
        statusText = "Rehacer aplicado"
    }

    private func syncHistoryState() {
        canUndo = historyManager.canUndo
        canRedo = historyManager.canRedo
        undoActionName = historyManager.undoActionName
        redoActionName = historyManager.redoActionName
    }

    private func validateSelections() {
        if let cid = selectedClassifierID, project.model.classifier(for: cid) == nil {
            selectedClassifierID = nil
        }
        if let rid = selectedRelationshipID, project.model.relationship(for: rid) == nil {
            selectedRelationshipID = nil
        }
        if project.diagram(for: activeDiagramID) == nil, let first = project.diagrams.first {
            activeDiagramID = first.id
        }
    }

    // MARK: - Classifier & Node Actions

    public func addClassifier(kind: UMLClassifierKind, at position: CGPoint) {
        let classifier = UMLClassifierFactory.makeClassifier(
            kind: kind,
            existingCount: project.model.classifiers.count
        )
        run(AddClassifierCommand(
            classifier: classifier,
            diagramID: activeDiagramID,
            position: position,
            headerColorHex: kind.defaultHeaderHex
        ))
        selectClassifier(classifier.id)
    }

    public func updateClassifier(_ updated: UMLClassifier, actionName: String? = nil) {
        guard let current = project.model.classifier(for: updated.id) else { return }
        guard current != updated else { return }
        run(UpdateClassifierCommand(oldClassifier: current, newClassifier: updated, actionName: actionName))
    }

    public func addQuickEditAttribute(to classifierID: UUID, expression: String) -> Bool {
        guard var classifier = project.model.classifier(for: classifierID),
              let attr = QuickEditParser.parseAttribute(expression) else {
            return false
        }
        classifier.attributes.append(attr)
        updateClassifier(classifier, actionName: "Agregar atributo \(attr.name)")
        return true
    }

    public func addQuickEditOperation(to classifierID: UUID, expression: String) -> Bool {
        guard var classifier = project.model.classifier(for: classifierID),
              let op = QuickEditParser.parseOperation(expression) else {
            return false
        }
        classifier.operations.append(op)
        updateClassifier(classifier, actionName: "Agregar método \(op.name)")
        return true
    }

    public func deleteClassifierFromModel(_ classifierID: UUID) {
        let name = project.model.classifier(for: classifierID)?.name ?? "Clasificador"
        run(DeleteClassifierFromModelCommand(classifierID: classifierID, classifierName: name))
        if selectedClassifierID == classifierID {
            selectedClassifierID = nil
        }
        validateSelections()
    }

    public func removeClassifierFromActiveDiagram(_ classifierID: UUID) {
        let name = project.model.classifier(for: classifierID)?.name ?? "Nodo"
        run(RemoveNodeFromDiagramCommand(classifierID: classifierID, diagramID: activeDiagramID, classifierName: name))
        if selectedClassifierID == classifierID {
            selectedClassifierID = nil
        }
    }

    public func addExistingClassifierToActiveDiagram(_ classifierID: UUID, at position: CGPoint? = nil) {
        guard let classifier = project.model.classifier(for: classifierID),
              let diagram = activeDiagram,
              !diagram.contains(classifierID: classifierID) else {
            return
        }
        let offset = CGFloat((diagram.nodes.count % 5) * 40)
        let targetPos = position ?? CGPoint(x: 128 + offset, y: 128 + offset)
        run(AddExistingClassifierToDiagramCommand(
            classifierID: classifierID,
            diagramID: activeDiagramID,
            position: targetPos,
            headerColorHex: classifier.kind.defaultHeaderHex,
            classifierName: classifier.name
        ))
        selectClassifier(classifierID)
    }

    public func commitNodeMove(nodeID: UUID, from: CGPoint, to: CGPoint) {
        guard hypot(to.x - from.x, to.y - from.y) > 0.5 else { return }
        run(MoveNodeCommand(diagramID: activeDiagramID, nodeID: nodeID, fromPosition: from, toPosition: to))
    }

    public func updateNodePresentation(_ updatedNode: DiagramNodeView) {
        guard let currentNode = activeDiagram?.nodes.first(where: { $0.id == updatedNode.id }),
              currentNode != updatedNode else {
            return
        }
        run(UpdateNodePresentationCommand(diagramID: activeDiagramID, oldNode: currentNode, newNode: updatedNode))
    }

    // MARK: - Relationship Actions

    public func createRelationship(kind: UMLRelationshipKind, sourceClassifierID: UUID, targetClassifierID: UUID) {
        let relationship = UMLRelationship(
            kind: kind,
            source: UMLRelationshipEnd(classifierID: sourceClassifierID),
            target: UMLRelationshipEnd(classifierID: targetClassifierID)
        )
        run(CreateRelationshipCommand(relationship: relationship, routingStyle: .orthogonal))
        selectRelationship(relationship.id)
    }

    public func updateRelationship(_ updated: UMLRelationship, routingStyle: EdgeRoutingStyle? = nil) {
        guard let current = project.model.relationship(for: updated.id) else { return }
        let currentStyle = activeDiagram?.edge(forRelationship: updated.id)?.routingStyle
        if current == updated && (routingStyle == nil || routingStyle == currentStyle) {
            return
        }
        run(UpdateRelationshipCommand(
            oldRelationship: current,
            newRelationship: updated,
            diagramID: activeDiagramID,
            oldRoutingStyle: currentStyle,
            newRoutingStyle: routingStyle
        ))
    }

    public func swapRelationshipEnds(_ relationshipID: UUID) {
        guard var rel = project.model.relationship(for: relationshipID) else { return }
        let oldSource = rel.source
        rel.source = rel.target
        rel.target = oldSource
        updateRelationship(rel)
    }

    public func deleteRelationship(_ relationshipID: UUID) {
        run(DeleteRelationshipCommand(relationshipID: relationshipID))
        if selectedRelationshipID == relationshipID {
            selectedRelationshipID = nil
        }
    }

    // MARK: - Diagram Viewport & Layout

    public func createNewDiagram(name: String? = nil) {
        let diagramName = name ?? "Diagrama \(project.diagrams.count + 1)"
        let diagram = UMLDiagram(name: diagramName)
        project.diagrams.append(diagram)
        activeDiagramID = diagram.id
        clearSelection()
        statusText = "Diagrama creado: \(diagramName)"
    }

    public func renameDiagram(id: UUID, newName: String) {
        guard let idx = project.diagrams.firstIndex(where: { $0.id == id }),
              !newName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        project.diagrams[idx].name = newName
    }

    public func deleteDiagram(id: UUID) {
        guard project.diagrams.count > 1 else { return }
        project.diagrams.removeAll { $0.id == id }
        if activeDiagramID == id, let first = project.diagrams.first {
            activeDiagramID = first.id
            clearSelection()
        }
    }

    public func applyLayout(strategy: any LayoutStrategyPort) {
        run(ApplyLayoutCommand(diagramID: activeDiagramID, strategy: strategy))
    }

    public func setZoomScale(_ scale: CGFloat) {
        guard let idx = activeDiagramIndex else { return }
        project.diagrams[idx].zoomScale = min(2.5, max(0.3, scale))
    }

    public func toggleGrid() {
        guard let idx = activeDiagramIndex else { return }
        project.diagrams[idx].showGrid.toggle()
    }

    public func toggleSnapToGrid() {
        guard let idx = activeDiagramIndex else { return }
        project.diagrams[idx].snapToGrid.toggle()
    }

    public func updateProjectName(_ newName: String) {
        project.name = newName
    }

    // MARK: - Mermaid Codec

    public func exportActiveDiagramToMermaid() -> String {
        mermaidCodec.export(project: project, diagramID: activeDiagramID)
    }

    public func exportFullModelToMermaid() -> String {
        mermaidCodec.export(project: project, diagramID: nil)
    }

    public func importMermaid(_ code: String, intoNewDiagram: Bool) throws {
        let targetID = intoNewDiagram ? nil : activeDiagramID
        try mermaidCodec.importCode(code, into: &project, diagramID: targetID)
        historyManager.clear()
        syncHistoryState()
        if intoNewDiagram, let last = project.diagrams.last {
            activeDiagramID = last.id
        }
        clearSelection()
        statusText = "Código Mermaid importado correctamente"
    }

    // MARK: - Project Lifecycle & File Panels (.umlproj)

    public func newBlankProject() {
        let blankDiagram = UMLDiagram(name: "Diagrama de Clases", snapToGrid: false)
        project = UMLProject(name: "Mi Proyecto UML", model: UMLModel(), diagrams: [blankDiagram])
        activeDiagramID = blankDiagram.id
        currentFileURL = nil
        historyManager.clear()
        syncHistoryState()
        clearSelection()
        statusText = "Nuevo proyecto creado"
    }

    public func loadSampleProject() {
        let sample = SampleProjectFactory.makeEcommerceSample()
        project = sample
        activeDiagramID = sample.diagrams.first?.id ?? UUID()
        currentFileURL = nil
        historyManager.clear()
        syncHistoryState()
        clearSelection()
        statusText = "Proyecto de ejemplo cargado"
    }

    public func openProjectWithPanel() {
        let panel = NSOpenPanel()
        panel.title = "Abrir proyecto UML (.umlproj)"
        var types: [UTType] = [.json]
        if let umlType = UTType(filenameExtension: "umlproj") {
            types.insert(umlType, at: 0)
        }
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let loaded = try repository.load(from: url)
            project = loaded
            activeDiagramID = loaded.diagrams.first?.id ?? UUID()
            currentFileURL = url
            historyManager.clear()
            syncHistoryState()
            clearSelection()
            statusText = "Abierto: \(url.lastPathComponent)"
        } catch {
            alertMessage = "No se pudo abrir el archivo: \(error.localizedDescription)"
        }
    }

    public func saveProject() {
        if let currentFileURL {
            saveProject(to: currentFileURL)
        } else {
            saveProjectAsWithPanel()
        }
    }

    public func saveProjectAsWithPanel() {
        let panel = NSSavePanel()
        panel.title = "Guardar proyecto UML (.umlproj)"
        panel.nameFieldStringValue = sanitizedFilename(project.name) + ".umlproj"
        panel.allowsOtherFileTypes = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, var url = panel.url else { return }
        if url.pathExtension.isEmpty {
            url = url.appendingPathExtension("umlproj")
        }
        saveProject(to: url)
    }

    private func saveProject(to url: URL) {
        do {
            try repository.save(project, to: url)
            currentFileURL = url
            statusText = "Guardado en \(url.lastPathComponent)"
        } catch {
            alertMessage = "No se pudo guardar el proyecto: \(error.localizedDescription)"
        }
    }

    // MARK: - Visual Export (PNG & PDF)

    public func exportPNGWithPanel() {
        guard let diagram = activeDiagram else { return }
        let panel = NSSavePanel()
        panel.title = "Exportar diagrama como PNG"
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = sanitizedFilename(diagram.name) + ".png"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try DiagramImageExporter.exportPNG(diagram: diagram, model: project.model, to: url)
            statusText = "PNG exportado: \(url.lastPathComponent)"
        } catch {
            alertMessage = "Error al exportar PNG: \(error.localizedDescription)"
        }
    }

    public func exportPDFWithPanel() {
        guard let diagram = activeDiagram else { return }
        let panel = NSSavePanel()
        panel.title = "Exportar diagrama como PDF vectorial"
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = sanitizedFilename(diagram.name) + ".pdf"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try DiagramImageExporter.exportPDF(diagram: diagram, model: project.model, to: url)
            statusText = "PDF exportado: \(url.lastPathComponent)"
        } catch {
            alertMessage = "Error al exportar PDF: \(error.localizedDescription)"
        }
    }

    private func sanitizedFilename(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let clean = raw.components(separatedBy: invalid).joined(separator: "_")
        return clean.isEmpty ? "DiagramaUML" : clean
    }
}
