import SwiftUI
import UMLApplication
import UMLDomain

/// StarUML-inspired QuickEdit popover opened by double-clicking any classifier on the canvas
/// or tapping its edit button. Includes ordered data-type selectors for creating and modifying attributes.
public struct QuickEditPopoverView: View {
    @Bindable public var workspaceVM: WorkspaceViewModel
    public let classifier: UMLClassifier
    public let onDismiss: () -> Void

    @State private var headerText: String
    @State private var newAttrVisibility: UMLVisibility = .private
    @State private var newAttrName: String = ""
    @State private var newAttrType: String = UMLDataTypeCatalog.orderedCommonTypes.first ?? "String"
    @State private var newOperationText: String = ""
    @State private var newLiteralText: String = ""
    @State private var errorText: String?

    public init(workspaceVM: WorkspaceViewModel, classifier: UMLClassifier, onDismiss: @escaping () -> Void) {
        self.workspaceVM = workspaceVM
        self.classifier = classifier
        self.onDismiss = onDismiss

        if let stereo = classifier.stereotype, !stereo.isEmpty {
            self._headerText = State(initialValue: "<<\(stereo)>> \(classifier.name)")
        } else {
            self._headerText = State(initialValue: classifier.name)
        }
    }

    private var currentClassifier: UMLClassifier {
        workspaceVM.project.model.classifier(for: classifier.id) ?? classifier
    }

    public var body: some View {
        let typeOptions = UMLDataTypeCatalog.attributeTypes(including: workspaceVM.project.model.classifiers)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: currentClassifier.kind.systemImageName)
                    .foregroundStyle(Color(hex: currentClassifier.kind.defaultHeaderHex))
                Text("QuickEdit — \(currentClassifier.kind.rawValue)")
                    .font(.headline)
                Spacer()
                Button("Listo") {
                    commitHeader()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Encabezado (opcional `<<estereotipo>> Nombre`)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Nombre", text: $headerText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { commitHeader() }
            }

            if currentClassifier.kind == .enumeration {
                HStack {
                    TextField("Agregar literal (ej. COMPLETED)", text: $newLiteralText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                        .onSubmit { addLiteral() }
                    Button("Agregar") { addLiteral() }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Agregar Atributo")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Picker("", selection: $newAttrVisibility) {
                            ForEach(UMLVisibility.allCases, id: \.self) { vis in
                                Text(vis.rawValue).tag(vis)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 48)

                        TextField("nombre", text: $newAttrName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                            .onSubmit { addStructuredAttribute() }

                        Picker("", selection: $newAttrType) {
                            ForEach(typeOptions, id: \.self) { typeName in
                                Text(typeName).tag(typeName)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 112)

                        Button("+ Attr") {
                            addStructuredAttribute()
                        }
                        .disabled(newAttrName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if !currentClassifier.attributes.isEmpty {
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(currentClassifier.attributes) { attr in
                                    attributeRow(attr)
                                }
                            }
                        }
                        .frame(maxHeight: 130)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Agregar Método (`+|-|#|~ metodo(arg: Tipo): Retorno`)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("+ guardar(force: Bool = false): Void", text: $newOperationText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                            .onSubmit { addOperation() }
                        Button("+ Mét") { addOperation() }
                    }
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(width: 430)
        .onDisappear {
            commitHeader()
        }
    }

    @ViewBuilder
    private func attributeRow(_ attr: UMLAttribute) -> some View {
        let rowTypes = UMLDataTypeCatalog.attributeTypes(
            including: workspaceVM.project.model.classifiers,
            currentType: attr.typeName
        )

        HStack(spacing: 6) {
            Text(attr.visibility.rawValue)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(attr.name)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)

            Spacer()

            Picker("", selection: Binding(
                get: { attr.typeName },
                set: { newType in
                    updateAttributeType(attributeID: attr.id, newType: newType)
                }
            )) {
                ForEach(rowTypes, id: \.self) { typeName in
                    Text(typeName).tag(typeName)
                }
            }
            .labelsHidden()
            .frame(width: 118)

            Button(role: .destructive) {
                deleteAttribute(attributeID: attr.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func commitHeader() {
        let parsed = QuickEditParser.parseClassifierHeader(headerText)
        guard !parsed.name.isEmpty else { return }
        var updated = currentClassifier
        updated.name = parsed.name
        if let stereo = parsed.stereotype {
            updated.stereotype = stereo
        } else if headerText.contains("<<") == false && updated.kind == .class {
            updated.stereotype = nil
        }
        workspaceVM.updateClassifier(updated, actionName: "Renombrar \(updated.name)")
    }

    private func addStructuredAttribute() {
        let cleanName = newAttrName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        var updated = currentClassifier
        let attr = UMLAttribute(
            visibility: newAttrVisibility,
            name: cleanName,
            typeName: newAttrType
        )
        updated.attributes.append(attr)
        workspaceVM.updateClassifier(updated, actionName: "Agregar atributo \(cleanName)")
        newAttrName = ""
        errorText = nil
    }

    private func updateAttributeType(attributeID: UUID, newType: String) {
        var updated = currentClassifier
        guard let idx = updated.attributes.firstIndex(where: { $0.id == attributeID }) else { return }
        updated.attributes[idx].typeName = newType
        workspaceVM.updateClassifier(updated, actionName: "Cambiar tipo de \(updated.attributes[idx].name)")
    }

    private func deleteAttribute(attributeID: UUID) {
        var updated = currentClassifier
        updated.attributes.removeAll { $0.id == attributeID }
        workspaceVM.updateClassifier(updated, actionName: "Eliminar atributo")
    }

    private func addOperation() {
        if workspaceVM.addQuickEditOperation(to: classifier.id, expression: newOperationText) {
            newOperationText = ""
            errorText = nil
        } else {
            errorText = "No se pudo interpretar el método."
        }
    }

    private func addLiteral() {
        let clean = newLiteralText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        var updated = currentClassifier
        updated.enumLiterals.append(clean)
        workspaceVM.updateClassifier(updated, actionName: "Agregar literal \(clean)")
        newLiteralText = ""
    }
}
