import SwiftUI
import UMLApplication
import UMLDomain

/// Inspector panel for editing a selected `UMLClassifier` (identity, QuickEdit, attributes, operations, enum literals).
public struct ClassifierInspectorView: View {
    @Bindable public var workspaceVM: WorkspaceViewModel
    public let classifier: UMLClassifier
    public let nodeView: DiagramNodeView?

    @State private var draft: UMLClassifier
    @State private var newAttrVisibility: UMLVisibility = .private
    @State private var newAttrName: String = ""
    @State private var newAttrType: String = UMLDataTypeCatalog.orderedCommonTypes.first ?? "String"
    @State private var quickAttributeInput: String = ""
    @State private var quickOperationInput: String = ""
    @State private var newEnumLiteral: String = ""
    @State private var parseError: String?
    @FocusState private var isEditingField: Bool

    private let colorPalette: [String] = [
        "#3B82F6", "#8B5CF6", "#10B981", "#F59E0B", "#EF4444", "#06B6D4", "#EC4899", "#64748B"
    ]

    public init(workspaceVM: WorkspaceViewModel, classifier: UMLClassifier, nodeView: DiagramNodeView?) {
        self.workspaceVM = workspaceVM
        self.classifier = classifier
        self.nodeView = nodeView
        self._draft = State(initialValue: classifier)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                identitySection
                if let nodeView {
                    appearanceSection(nodeView: nodeView)
                }
                if draft.kind == .enumeration {
                    enumLiteralsSection
                } else {
                    attributesSection
                    operationsSection
                }
                actionsSection
            }
            .padding(14)
        }
        .onChange(of: classifier) { _, updated in
            draft = updated
        }
        .onChange(of: isEditingField) { _, focused in
            if !focused {
                commitDraft()
            }
        }
        .onDisappear {
            commitDraft()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var identitySection: some View {
        GroupBox("Clasificador UML") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Nombre", text: $draft.name)
                    .textFieldStyle(.roundedBorder)
                    .focused($isEditingField)
                    .onSubmit { commitDraft() }

                Picker("Tipo", selection: $draft.kind) {
                    ForEach(UMLClassifierKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .onChange(of: draft.kind) { _, newKind in
                    draft.stereotype = newKind.defaultStereotype
                    draft.isAbstract = (newKind == .abstractClass || newKind == .interface)
                    commitDraft(actionName: "Cambiar tipo a \(newKind.rawValue)")
                }

                HStack {
                    TextField("Estereotipo (ej. entity, service)", text: Binding(
                        get: { draft.stereotype ?? "" },
                        set: { draft.stereotype = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .focused($isEditingField)
                    .onSubmit { commitDraft() }
                }

                TextField("Paquete (ej. Domain.Sales)", text: Binding(
                    get: { draft.packageName ?? "" },
                    set: { draft.packageName = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .focused($isEditingField)
                .onSubmit { commitDraft() }

                Toggle("Es Abstracto (cursiva)", isOn: $draft.isAbstract)
                    .onChange(of: draft.isAbstract) { _, _ in commitDraft() }
            }
            .padding(6)
        }
    }

    @ViewBuilder
    private func appearanceSection(nodeView: DiagramNodeView) -> some View {
        GroupBox("Vista en Diagrama") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Color:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(colorPalette, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: nodeView.headerColorHex == hex ? 2 : 0)
                            )
                            .onTapGesture {
                                var updated = nodeView
                                updated.headerColorHex = hex
                                workspaceVM.updateNodePresentation(updated)
                            }
                    }
                }

                Toggle("Mostrar Estereotipo", isOn: Binding(
                    get: { nodeView.showStereotype },
                    set: { val in
                        var updated = nodeView
                        updated.showStereotype = val
                        workspaceVM.updateNodePresentation(updated)
                    }
                ))
                Toggle("Mostrar Atributos", isOn: Binding(
                    get: { nodeView.showAttributes },
                    set: { val in
                        var updated = nodeView
                        updated.showAttributes = val
                        workspaceVM.updateNodePresentation(updated)
                    }
                ))
                Toggle("Mostrar Métodos", isOn: Binding(
                    get: { nodeView.showOperations },
                    set: { val in
                        var updated = nodeView
                        updated.showOperations = val
                        workspaceVM.updateNodePresentation(updated)
                    }
                ))
            }
            .padding(6)
        }
    }

    @ViewBuilder
    private var attributesSection: some View {
        let typeOptions = UMLDataTypeCatalog.attributeTypes(including: workspaceVM.project.model.classifiers)

        GroupBox("Atributos (\(draft.attributes.count))") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Picker("", selection: $newAttrVisibility) {
                        ForEach(UMLVisibility.allCases, id: \.self) { vis in
                            Text(vis.rawValue).tag(vis)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 48)

                    TextField("Nombre del atributo", text: $newAttrName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addStructuredAttribute() }

                    Picker("", selection: $newAttrType) {
                        ForEach(typeOptions, id: \.self) { typeName in
                            Text(typeName).tag(typeName)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 96)

                    Button {
                        addStructuredAttribute()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .disabled(newAttrName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                HStack {
                    TextField("QuickEdit: - saldo: Decimal = 0", text: $quickAttributeInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                        .onSubmit { addQuickAttribute() }

                    Button {
                        addQuickAttribute()
                    } label: {
                        Image(systemName: "bolt.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Agregar usando expresión QuickEdit")
                    .disabled(quickAttributeInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let parseError {
                    Text(parseError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                ForEach($draft.attributes) { $attr in
                    let rowTypes = UMLDataTypeCatalog.attributeTypes(
                        including: workspaceVM.project.model.classifiers,
                        currentType: attr.typeName
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Picker("", selection: $attr.visibility) {
                                ForEach(UMLVisibility.allCases, id: \.self) { vis in
                                    Text(vis.rawValue).tag(vis)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 48)
                            .onChange(of: attr.visibility) { _, _ in commitDraft() }

                            TextField("nombre", text: $attr.name)
                                .textFieldStyle(.roundedBorder)
                                .focused($isEditingField)
                                .onSubmit { commitDraft() }

                            Text(":")
                            Picker("", selection: $attr.typeName) {
                                ForEach(rowTypes, id: \.self) { typeName in
                                    Text(typeName).tag(typeName)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 96)
                            .onChange(of: attr.typeName) { _, _ in
                                commitDraft(actionName: "Cambiar tipo de \(attr.name)")
                            }

                            Button(role: .destructive) {
                                draft.attributes.removeAll { $0.id == attr.id }
                                commitDraft(actionName: "Eliminar atributo")
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }

                        HStack(spacing: 8) {
                            TextField("Valor defecto", text: Binding(
                                get: { attr.defaultValue ?? "" },
                                set: { attr.defaultValue = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .focused($isEditingField)
                            .onSubmit { commitDraft() }

                            Toggle("Static", isOn: $attr.isStatic)
                                .toggleStyle(.checkbox)
                                .font(.caption2)
                                .onChange(of: attr.isStatic) { _, _ in commitDraft() }

                            Toggle("RO", isOn: $attr.isReadOnly)
                                .toggleStyle(.checkbox)
                                .font(.caption2)
                                .onChange(of: attr.isReadOnly) { _, _ in commitDraft() }
                        }
                    }
                    .padding(6)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(6)
        }
    }

    @ViewBuilder
    private var operationsSection: some View {
        GroupBox("Métodos / Operaciones (\(draft.operations.count))") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("QuickEdit: + calcular(x: Int): Bool", text: $quickOperationInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                        .onSubmit { addQuickOperation() }

                    Button {
                        addQuickOperation()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .disabled(quickOperationInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                ForEach($draft.operations) { $op in
                    let returnTypes = UMLDataTypeCatalog.returnTypes(
                        including: workspaceVM.project.model.classifiers,
                        currentType: op.returnType
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Picker("", selection: $op.visibility) {
                                ForEach(UMLVisibility.allCases, id: \.self) { vis in
                                    Text(vis.rawValue).tag(vis)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 48)
                            .onChange(of: op.visibility) { _, _ in commitDraft() }

                            TextField("método", text: $op.name)
                                .textFieldStyle(.roundedBorder)
                                .focused($isEditingField)
                                .onSubmit { commitDraft() }

                            Text("->")
                            Picker("", selection: Binding(
                                get: { op.returnType ?? "Void" },
                                set: { op.returnType = $0 }
                            )) {
                                ForEach(returnTypes, id: \.self) { typeName in
                                    Text(typeName).tag(typeName)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 88)
                            .onChange(of: op.returnType) { _, _ in commitDraft() }

                            Button(role: .destructive) {
                                draft.operations.removeAll { $0.id == op.id }
                                commitDraft(actionName: "Eliminar método")
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }

                        // Parameters editor
                        if !op.parameters.isEmpty {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach($op.parameters) { $param in
                                    let paramTypes = UMLDataTypeCatalog.attributeTypes(
                                        including: workspaceVM.project.model.classifiers,
                                        currentType: param.typeName
                                    )
                                    HStack(spacing: 4) {
                                        Text("param:")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        TextField("nombre", text: $param.name)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.caption)
                                            .focused($isEditingField)
                                            .onSubmit { commitDraft() }
                                        Picker("", selection: $param.typeName) {
                                            ForEach(paramTypes, id: \.self) { typeName in
                                                Text(typeName).tag(typeName)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(width: 88)
                                        .onChange(of: param.typeName) { _, _ in commitDraft() }
                                        Button {
                                            op.parameters.removeAll { $0.id == param.id }
                                            commitDraft()
                                        } label: {
                                            Image(systemName: "minus.circle")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                            .padding(.leading, 8)
                        }

                        HStack(spacing: 10) {
                            Button("+ Parámetro") {
                                op.parameters.append(UMLParameter(name: "arg\(op.parameters.count + 1)", typeName: "String"))
                                commitDraft()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)

                            Spacer()

                            Toggle("Static", isOn: $op.isStatic)
                                .toggleStyle(.checkbox)
                                .font(.caption2)
                                .onChange(of: op.isStatic) { _, _ in commitDraft() }

                            Toggle("Abstract", isOn: $op.isAbstract)
                                .toggleStyle(.checkbox)
                                .font(.caption2)
                                .onChange(of: op.isAbstract) { _, _ in commitDraft() }
                        }
                    }
                    .padding(6)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(6)
        }
    }

    @ViewBuilder
    private var enumLiteralsSection: some View {
        GroupBox("Literales de Enumeración (\(draft.enumLiterals.count))") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Nuevo literal (ej. PAID)", text: $newEnumLiteral)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addEnumLiteral() }
                    Button {
                        addEnumLiteral()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                }

                ForEach(Array(draft.enumLiterals.enumerated()), id: \.offset) { idx, literal in
                    HStack {
                        Text(literal)
                            .font(.system(.caption, design: .monospaced))
                        Spacer()
                        Button(role: .destructive) {
                            draft.enumLiterals.remove(at: idx)
                            commitDraft(actionName: "Eliminar literal")
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(6)
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        VStack(spacing: 8) {
            if workspaceVM.activeDiagram?.contains(classifierID: classifier.id) == true {
                Button("Quitar solo de este Diagrama") {
                    workspaceVM.removeClassifierFromActiveDiagram(classifier.id)
                }
                .frame(maxWidth: .infinity)
            } else {
                Button("Insertar en Diagrama Activo") {
                    workspaceVM.addExistingClassifierToActiveDiagram(classifier.id)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }

            Button("Eliminar del Modelo", role: .destructive) {
                workspaceVM.deleteClassifierFromModel(classifier.id)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    private func addStructuredAttribute() {
        let trimmed = newAttrName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let attr = UMLAttribute(
            visibility: newAttrVisibility,
            name: trimmed,
            typeName: newAttrType
        )
        draft.attributes.append(attr)
        newAttrName = ""
        parseError = nil
        commitDraft(actionName: "Agregar atributo \(attr.name)")
    }

    private func addQuickAttribute() {
        let trimmed = quickAttributeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let attr = QuickEditParser.parseAttribute(trimmed) {
            draft.attributes.append(attr)
            quickAttributeInput = ""
            parseError = nil
            commitDraft(actionName: "Agregar atributo \(attr.name)")
        } else {
            parseError = "Formato inválido. Ejemplo: - monto: Decimal = 0"
        }
    }

    private func addQuickOperation() {
        let trimmed = quickOperationInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let op = QuickEditParser.parseOperation(trimmed) {
            draft.operations.append(op)
            quickOperationInput = ""
            parseError = nil
            commitDraft(actionName: "Agregar método \(op.name)")
        } else {
            parseError = "Formato inválido. Ejemplo: + validar(id: Int): Bool"
        }
    }

    private func addEnumLiteral() {
        let clean = newEnumLiteral.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        draft.enumLiterals.append(clean)
        newEnumLiteral = ""
        commitDraft(actionName: "Agregar literal \(clean)")
    }

    private func commitDraft(actionName: String? = nil) {
        workspaceVM.updateClassifier(draft, actionName: actionName)
    }
}
