import SwiftUI
import UMLDomain

/// Left sidebar providing Gaphor-style Model Repository browsing, Diagram switching, and UML Toolbox.
public struct ModelExplorerSidebar: View {
    @Bindable public var workspaceVM: WorkspaceViewModel
    @Bindable public var interactionVM: CanvasInteractionViewModel

    @State private var newDiagramName: String = ""
    @State private var isCreatingDiagram: Bool = false

    public init(workspaceVM: WorkspaceViewModel, interactionVM: CanvasInteractionViewModel) {
        self.workspaceVM = workspaceVM
        self.interactionVM = interactionVM
    }

    public var body: some View {
        List {
            diagramsSection
            toolboxSection
            classifiersModelSection
            relationshipsModelSection
        }
        .listStyle(.sidebar)
        .frame(minWidth: 245)
        .sheet(isPresented: $isCreatingDiagram) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Nuevo Diagrama de Clases")
                    .font(.headline)
                Text("Compartirá las entidades del modelo actual (estilo Gaphor).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Nombre del diagrama", text: $newDiagramName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancelar") { isCreatingDiagram = false }
                    Button("Crear") {
                        workspaceVM.createNewDiagram(name: newDiagramName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : newDiagramName)
                        newDiagramName = ""
                        isCreatingDiagram = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 340)
        }
    }

    // MARK: - Diagrams

    @ViewBuilder
    private var diagramsSection: some View {
        Section {
            ForEach(workspaceVM.project.diagrams) { diagram in
                HStack {
                    Image(systemName: "rectangle.3.group")
                        .foregroundStyle(diagram.id == workspaceVM.activeDiagramID ? Color.accentColor : Color.secondary)
                    Text(diagram.name)
                        .fontWeight(diagram.id == workspaceVM.activeDiagramID ? .semibold : .regular)
                    Spacer()
                    Text("\(diagram.nodes.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    workspaceVM.activeDiagramID = diagram.id
                    workspaceVM.clearSelection()
                    interactionVM.resetTransientInteractions()
                }
                .contextMenu {
                    if workspaceVM.project.diagrams.count > 1 {
                        Button("Eliminar Diagrama", role: .destructive) {
                            workspaceVM.deleteDiagram(id: diagram.id)
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Diagramas")
                Spacer()
                Button {
                    newDiagramName = "Diagrama \(workspaceVM.project.diagrams.count + 1)"
                    isCreatingDiagram = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Crear un nuevo diagrama sobre el mismo modelo")
            }
        }
    }

    // MARK: - Toolbox

    @ViewBuilder
    private var toolboxSection: some View {
        Section("Paleta UML 2.5") {
            ForEach(UMLClassifierKind.allCases, id: \.self) { kind in
                let isSelected = interactionVM.activeTool == .addClassifier(kind)
                Button {
                    interactionVM.activeTool = .addClassifier(kind)
                } label: {
                    HStack {
                        Image(systemName: kind.systemImageName)
                            .foregroundStyle(Color(hex: kind.defaultHeaderHex))
                            .frame(width: 18)
                        Text(kind.rawValue)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Divider()

            ForEach(UMLRelationshipKind.allCases, id: \.self) { relKind in
                let isSelected = interactionVM.activeTool == .connect(relKind)
                Button {
                    interactionVM.activeTool = .connect(relKind)
                } label: {
                    HStack {
                        Image(systemName: relKind.systemImageName)
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .frame(width: 18)
                        Text(relKind.displayName)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Model Classifiers

    @ViewBuilder
    private var classifiersModelSection: some View {
        let activeDiagram = workspaceVM.activeDiagram
        Section("Modelo Semántico (\(workspaceVM.project.model.classifiers.count))") {
            ForEach(workspaceVM.project.model.classifiers) { classifier in
                let isOnActiveDiagram = activeDiagram?.contains(classifierID: classifier.id) ?? false
                HStack(spacing: 6) {
                    Image(systemName: classifier.kind.systemImageName)
                        .foregroundStyle(Color(hex: classifier.kind.defaultHeaderHex))
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(classifier.name)
                            .font(.subheadline)
                            .fontWeight(workspaceVM.selectedClassifierID == classifier.id ? .semibold : .regular)
                        Text("\(classifier.attributes.count) attr · \(classifier.operations.count) mét")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isOnActiveDiagram {
                        Image(systemName: "eye.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .help("Visible en el diagrama activo")
                    } else {
                        Button("+ Vista") {
                            workspaceVM.addExistingClassifierToActiveDiagram(classifier.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .help("Agregar esta entidad del modelo al diagrama activo")
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    workspaceVM.selectClassifier(classifier.id)
                }
                .contextMenu {
                    if !isOnActiveDiagram {
                        Button("Agregar al Diagrama Activo") {
                            workspaceVM.addExistingClassifierToActiveDiagram(classifier.id)
                        }
                    } else {
                        Button("Quitar del Diagrama Activo") {
                            workspaceVM.removeClassifierFromActiveDiagram(classifier.id)
                        }
                    }
                    Divider()
                    Button("Eliminar del Modelo", role: .destructive) {
                        workspaceVM.deleteClassifierFromModel(classifier.id)
                    }
                }
            }
        }
    }

    // MARK: - Model Relationships

    @ViewBuilder
    private var relationshipsModelSection: some View {
        Section("Relaciones (\(workspaceVM.project.model.relationships.count))") {
            ForEach(workspaceVM.project.model.relationships) { rel in
                let sourceName = workspaceVM.project.model.classifier(for: rel.source.classifierID)?.name ?? "?"
                let targetName = workspaceVM.project.model.classifier(for: rel.target.classifierID)?.name ?? "?"
                HStack(spacing: 6) {
                    Image(systemName: rel.kind.systemImageName)
                        .font(.caption)
                        .foregroundStyle(workspaceVM.selectedRelationshipID == rel.id ? Color.accentColor : Color.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(sourceName) → \(targetName)")
                            .font(.caption)
                            .fontWeight(workspaceVM.selectedRelationshipID == rel.id ? .semibold : .regular)
                            .lineLimit(1)
                        Text(rel.kind.displayName + (rel.name.map { " (\($0))" } ?? ""))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    workspaceVM.selectRelationship(rel.id)
                }
            }
        }
    }
}
