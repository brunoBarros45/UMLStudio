import SwiftUI
import UMLDomain

/// Inspector panel for editing a selected `UMLRelationship` (kind, routing, swap ends, roles, multiplicities).
public struct RelationshipInspectorView: View {
    @Bindable public var workspaceVM: WorkspaceViewModel
    public let relationship: UMLRelationship
    public let edgeView: DiagramEdgeView?

    @State private var draft: UMLRelationship
    @State private var routingStyle: EdgeRoutingStyle
    @FocusState private var isEditingText: Bool

    private let multiplicityPresets = ["", "1", "0..1", "0..*", "1..*", "*"]

    public init(workspaceVM: WorkspaceViewModel, relationship: UMLRelationship, edgeView: DiagramEdgeView?) {
        self.workspaceVM = workspaceVM
        self.relationship = relationship
        self.edgeView = edgeView
        self._draft = State(initialValue: relationship)
        self._routingStyle = State(initialValue: edgeView?.routingStyle ?? .orthogonal)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                generalSection
                endEditorSection(title: "Extremo Origen (Source)", end: $draft.source)
                endEditorSection(title: "Extremo Destino (Target)", end: $draft.target)

                Button("Invertir Dirección (Swap Ends)") {
                    workspaceVM.swapRelationshipEnds(relationship.id)
                }
                .frame(maxWidth: .infinity)

                Button("Eliminar Relación", role: .destructive) {
                    workspaceVM.deleteRelationship(relationship.id)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(14)
        }
        .onChange(of: relationship) { _, updated in
            draft = updated
        }
        .onChange(of: edgeView?.routingStyle) { _, updatedStyle in
            if let updatedStyle {
                routingStyle = updatedStyle
            }
        }
        .onChange(of: isEditingText) { _, focused in
            if !focused {
                commitChanges()
            }
        }
        .onDisappear {
            commitChanges()
        }
    }

    @ViewBuilder
    private var generalSection: some View {
        GroupBox("Relación UML 2.5") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Tipo de Relación", selection: $draft.kind) {
                    ForEach(UMLRelationshipKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .onChange(of: draft.kind) { _, _ in commitChanges() }

                Picker("Estilo de Trazado", selection: $routingStyle) {
                    ForEach(EdgeRoutingStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: routingStyle) { _, _ in commitChanges() }

                TextField("Nombre de relación (opcional)", text: Binding(
                    get: { draft.name ?? "" },
                    set: { draft.name = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .focused($isEditingText)
                .onSubmit { commitChanges() }
            }
            .padding(6)
        }
    }

    @ViewBuilder
    private func endEditorSection(title: String, end: Binding<UMLRelationshipEnd>) -> some View {
        let endpointName = workspaceVM.project.model.classifier(for: end.wrappedValue.classifierID)?.name ?? "Desconocido"
        GroupBox("\(title): \(endpointName)") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Rol (ej. items, owner)", text: Binding(
                    get: { end.wrappedValue.roleName ?? "" },
                    set: { end.wrappedValue.roleName = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .focused($isEditingText)
                .onSubmit { commitChanges() }

                HStack {
                    TextField("Multiplicidad (ej. 1..*)", text: Binding(
                        get: { end.wrappedValue.multiplicity ?? "" },
                        set: { end.wrappedValue.multiplicity = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .focused($isEditingText)
                    .onSubmit { commitChanges() }

                    Menu("Preset") {
                        ForEach(multiplicityPresets, id: \.self) { preset in
                            Button(preset.isEmpty ? "Ninguna" : preset) {
                                end.wrappedValue.multiplicity = preset.isEmpty ? nil : preset
                                commitChanges()
                            }
                        }
                    }
                    .fixedSize()
                }
            }
            .padding(6)
        }
    }

    private func commitChanges() {
        workspaceVM.updateRelationship(draft, routingStyle: routingStyle)
    }
}
