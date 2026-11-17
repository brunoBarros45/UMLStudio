import CoreGraphics
import Foundation

/// Visual presentation of a `UMLClassifier` within a single `UMLDiagram`.
/// Multiple diagrams can reference the same `classifierID` at different positions and visibility settings.
public struct DiagramNodeView: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var classifierID: UUID
    public var position: CGPoint
    public var width: CGFloat
    public var minHeight: CGFloat
    public var headerColorHex: String?
    public var showAttributes: Bool
    public var showOperations: Bool
    public var showStereotype: Bool

    public init(
        id: UUID = UUID(),
        classifierID: UUID,
        position: CGPoint,
        width: CGFloat = 236,
        minHeight: CGFloat = 96,
        headerColorHex: String? = nil,
        showAttributes: Bool = true,
        showOperations: Bool = true,
        showStereotype: Bool = true
    ) {
        self.id = id
        self.classifierID = classifierID
        self.position = position
        self.width = width
        self.minHeight = minHeight
        self.headerColorHex = headerColorHex
        self.showAttributes = showAttributes
        self.showOperations = showOperations
        self.showStereotype = showStereotype
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(classifierID)
        hasher.combine(position.x)
        hasher.combine(position.y)
        hasher.combine(width)
        hasher.combine(minHeight)
        hasher.combine(headerColorHex)
        hasher.combine(showAttributes)
        hasher.combine(showOperations)
        hasher.combine(showStereotype)
    }

    /// Computes a deterministic bounding rectangle in canvas coordinates for a given classifier.
    /// `position` represents the top-left corner of the classifier box.
    public func boundingBox(for classifier: UMLClassifier) -> CGRect {
        let size = estimatedSize(for: classifier)
        return CGRect(origin: position, size: size)
    }

    public func estimatedSize(for classifier: UMLClassifier) -> CGSize {
        let headerBase: CGFloat = 34
        let stereotypeHeight: CGFloat = (showStereotype && classifier.effectiveStereotype != nil) ? 16 : 0
        let packageHeight: CGFloat = (classifier.packageName?.isEmpty == false) ? 14 : 0
        let headerHeight = headerBase + stereotypeHeight + packageHeight

        let lineHeight: CGFloat = 19
        let compartmentPadding: CGFloat = 14

        var attributesHeight: CGFloat = 0
        if showAttributes {
            let count = classifier.kind == .enumeration ? classifier.enumLiterals.count : classifier.attributes.count
            attributesHeight = max(24, CGFloat(count) * lineHeight + compartmentPadding)
        }

        var operationsHeight: CGFloat = 0
        if showOperations && classifier.kind != .enumeration {
            operationsHeight = max(24, CGFloat(classifier.operations.count) * lineHeight + compartmentPadding)
        }

        let computedWidth = max(width, estimatedRequiredWidth(for: classifier))
        let computedHeight = max(minHeight, headerHeight + attributesHeight + operationsHeight)
        return CGSize(width: computedWidth, height: computedHeight)
    }

    private func estimatedRequiredWidth(for classifier: UMLClassifier) -> CGFloat {
        let titleChars = classifier.name.count + 4
        let attrChars = classifier.kind == .enumeration
            ? (classifier.enumLiterals.map(\.count).max() ?? 0)
            : (classifier.attributes.map { $0.formattedUML.count }.max() ?? 0)
        let opChars = classifier.operations.map { $0.formattedUML.count }.max() ?? 0
        let maxChars = max(titleChars, attrChars, opChars)
        let approxCharWidth: CGFloat = 7.0
        return min(380, max(width, CGFloat(maxChars) * approxCharWidth + 32))
    }
}
