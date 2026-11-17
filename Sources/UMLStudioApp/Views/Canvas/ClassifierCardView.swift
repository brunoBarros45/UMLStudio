import SwiftUI
import UMLDomain

/// Pure visual UML 2.5 classifier box shared by both the interactive canvas and PNG/PDF exporter.
public struct ClassifierCardView: View {
    public let classifier: UMLClassifier
    public let node: DiagramNodeView
    public let isSelected: Bool
    public let isHovered: Bool
    public let showPorts: Bool
    public let isPrintMode: Bool

    public var onQuickEdit: (() -> Void)?
    public var onPortDragChanged: ((CGPoint, CGPoint) -> Void)?
    public var onPortDragEnded: ((CGPoint) -> Void)?

    public init(
        classifier: UMLClassifier,
        node: DiagramNodeView,
        isSelected: Bool,
        isHovered: Bool,
        showPorts: Bool = true,
        isPrintMode: Bool = false,
        onQuickEdit: (() -> Void)? = nil,
        onPortDragChanged: ((CGPoint, CGPoint) -> Void)? = nil,
        onPortDragEnded: ((CGPoint) -> Void)? = nil
    ) {
        self.classifier = classifier
        self.node = node
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.showPorts = showPorts
        self.isPrintMode = isPrintMode
        self.onQuickEdit = onQuickEdit
        self.onPortDragChanged = onPortDragChanged
        self.onPortDragEnded = onPortDragEnded
    }

    public var body: some View {
        let size = node.estimatedSize(for: classifier)
        let accent = Color(hex: node.headerColorHex ?? classifier.kind.defaultHeaderHex)
        let cardBackground = isPrintMode ? Color.white : Color(nsColor: .controlBackgroundColor)
        let primaryText = isPrintMode ? Color.black : Color.primary
        let secondaryText = isPrintMode ? Color.gray : Color.secondary

        ZStack {
            VStack(spacing: 0) {
                headerSection(accent: accent, primaryText: primaryText, secondaryText: secondaryText)

                if node.showAttributes {
                    Divider()
                    attributesCompartment(primaryText: primaryText)
                }

                if node.showOperations && classifier.kind != .enumeration {
                    Divider()
                    operationsCompartment(primaryText: primaryText)
                }

                Spacer(minLength: 0)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.accentColor : (isPrintMode ? Color.black.opacity(0.65) : Color.primary.opacity(0.28)),
                        lineWidth: isSelected ? 2.2 : 1.1
                    )
            )
            .shadow(
                color: isPrintMode ? .clear : Color.black.opacity(isSelected ? 0.20 : 0.10),
                radius: isSelected ? 10 : 4,
                x: 0,
                y: 2
            )

            if (isSelected || isHovered) && !isPrintMode, let onQuickEdit {
                Button {
                    onQuickEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accent)
                        .padding(4)
                        .background(cardBackground.opacity(0.9))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("QuickEdit (agregar atributos o métodos)")
                .position(x: size.width - 16, y: 18)
            }

            if showPorts && (isSelected || isHovered) && !isPrintMode {
                portHandlesLayer(size: size)
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func headerSection(accent: Color, primaryText: Color, secondaryText: Color) -> some View {
        let hasStereotype = node.showStereotype && classifier.effectiveStereotype != nil
        let hasPackage = classifier.packageName?.isEmpty == false
        let headerHeight: CGFloat = 34 + (hasStereotype ? 16 : 0) + (hasPackage ? 14 : 0)

        VStack(spacing: 1) {
            if hasStereotype, let stereotype = classifier.effectiveStereotype {
                Text("«\(stereotype)»")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(accent)
                    .lineLimit(1)
            }

            Text(classifier.name)
                .font(.system(size: 13.5, weight: .bold))
                .italic(classifier.isAbstract)
                .foregroundStyle(primaryText)
                .lineLimit(1)

            if hasPackage, let pkg = classifier.packageName {
                Text("from \(pkg)")
                    .font(.system(size: 9.5))
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: headerHeight)
        .background(accent.opacity(isPrintMode ? 0.08 : 0.14))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(accent)
                .frame(height: 3.5)
        }
    }

    @ViewBuilder
    private func attributesCompartment(primaryText: Color) -> some View {
        let count = classifier.kind == .enumeration ? classifier.enumLiterals.count : classifier.attributes.count
        let compartmentHeight = max(24, CGFloat(count) * 19 + 14)

        VStack(alignment: .leading, spacing: 0) {
            if classifier.kind == .enumeration {
                ForEach(Array(classifier.enumLiterals.enumerated()), id: \.offset) { _, literal in
                    Text(literal)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 19)
                }
            } else {
                ForEach(classifier.attributes) { attr in
                    Text(attr.formattedUML)
                        .font(.system(size: 11.5, design: .monospaced))
                        .underline(attr.isStatic)
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 19)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: compartmentHeight, alignment: .top)
    }

    @ViewBuilder
    private func operationsCompartment(primaryText: Color) -> some View {
        let compartmentHeight = max(24, CGFloat(classifier.operations.count) * 19 + 14)

        VStack(alignment: .leading, spacing: 0) {
            ForEach(classifier.operations) { op in
                Text(op.formattedUML)
                    .font(.system(size: 11.5, design: .monospaced))
                    .italic(op.isAbstract)
                    .underline(op.isStatic)
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 19)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: compartmentHeight, alignment: .top)
    }

    @ViewBuilder
    private func portHandlesLayer(size: CGSize) -> some View {
        let anchors: [CGPoint] = [
            CGPoint(x: size.width / 2, y: 0),
            CGPoint(x: size.width, y: size.height / 2),
            CGPoint(x: size.width / 2, y: size.height),
            CGPoint(x: 0, y: size.height / 2)
        ]

        ForEach(Array(anchors.enumerated()), id: \.offset) { _, localAnchor in
            ZStack {
                Color.clear
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            }
            .contentShape(Rectangle())
            .position(x: localAnchor.x, y: localAnchor.y)
            .highPriorityGesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named("UMLDiagramCanvas"))
                    .onChanged { value in
                        let globalStart = CGPoint(
                            x: node.position.x + localAnchor.x,
                            y: node.position.y + localAnchor.y
                        )
                        onPortDragChanged?(globalStart, value.location)
                    }
                    .onEnded { value in
                        onPortDragEnded?(value.location)
                    }
            )
        }
    }
}
