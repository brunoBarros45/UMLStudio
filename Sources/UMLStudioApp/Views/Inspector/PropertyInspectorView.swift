import SwiftUI
import UMLDomain

/// Right-hand inspector routing to Classifier, Relationship, or Diagram properties.
public struct PropertyInspectorView: View {
    @Bindable public var workspaceVM: WorkspaceViewModel

    public init(workspaceVM: WorkspaceViewModel) {
        self.workspaceVM = workspaceVM
    }

    public var body: some View {
        Group {
            if let classifier = workspaceVM.selectedClassifier {
                ClassifierInspectorView(
                    workspaceVM: workspaceVM,
                    classifier: classifier,
                    nodeView: workspaceVM.selectedNodeView
                )
            } else if let relationship = workspaceVM.selectedRelationship {
                RelationshipInspectorView(
                    workspaceVM: workspaceVM,
                    relationship: relationship,
                    edgeView: workspaceVM.selectedEdgeView
                )
            } else {
                diagramInspector
            }
        }
        .frame(minWidth: 290, idealWidth: 315)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var diagramInspector: some View {
        let diagram = workspaceVM.activeDiagram
        let hiddenClassifiers = workspaceVM.project.model.classifiers.filter {
            !(diagram?.contains(classifierID: $0.id) ?? false)
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Proyecto y Diagrama Activo") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Nombre del Proyecto", text: Binding(
                            get: { workspaceVM.project.name },
                            set: { workspaceVM.updateProjectName($0) }
                        ))
                        .textFieldStyle(.roundedBorder)

                        if let diagram {
                            TextField("Nombre del Diagrama", text: Binding(
                                get: { diagram.name },
                                set: { workspaceVM.renameDiagram(id: diagram.id, newName: $0) }
                            ))
                            .textFieldStyle(.roundedBorder)

                            Toggle("Mostrar Grilla", isOn: Binding(
                                get: { diagram.showGrid },
                                set: { _ in workspaceVM.toggleGrid() }
                            ))
                            Toggle("Ajustar a Grilla (16pt)", isOn: Binding(
                                get: { diagram.snapToGrid },
                                set: { _ in workspaceVM.toggleSnapToGrid() }
                            ))
                        }
                    }
                    .padding(6)
                }

                GroupBox("Estadísticas del Modelo") {
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("Clasificadores en Modelo", value: "\(workspaceVM.project.model.classifiers.count)")
                        LabeledContent("Relaciones en Modelo", value: "\(workspaceVM.project.model.relationships.count)")
                        LabeledContent("Nodos en este Diagrama", value: "\(diagram?.nodes.count ?? 0)")
                    }
                    .font(.caption)
                    .padding(6)
                }

                if !hiddenClassifiers.isEmpty {
                    GroupBox("Disponibles en el Modelo") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Estas entidades existen en el modelo pero no están en este diagrama:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            ForEach(hiddenClassifiers) { cls in
                                HStack {
                                    Image(systemName: cls.kind.systemImageName)
                                        .foregroundStyle(Color(hex: cls.kind.defaultHeaderHex))
                                    Text(cls.name)
                                        .font(.caption)
                                    Spacer()
                                    Button("Agregar") {
                                        workspaceVM.addExistingClassifierToActiveDiagram(cls.id)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                            }
                        }
                        .padding(6)
                    }
                }
            }
            .padding(14)
        }
    }
}
