import Foundation
import UMLDomain

/// Factory encapsulating creation of standard UML 2.5 classifiers cleanly without placeholder members.
public enum UMLClassifierFactory {
    public static func makeClassifier(
        kind: UMLClassifierKind,
        name: String? = nil,
        existingCount: Int = 0
    ) -> UMLClassifier {
        let indexSuffix = existingCount + 1
        switch kind {
        case .class:
            return UMLClassifier(
                kind: .class,
                name: name ?? "Clase\(indexSuffix)",
                stereotype: nil,
                isAbstract: false,
                attributes: [],
                operations: []
            )
        case .abstractClass:
            return UMLClassifier(
                kind: .abstractClass,
                name: name ?? "ClaseAbstracta\(indexSuffix)",
                stereotype: "abstract",
                isAbstract: true,
                attributes: [],
                operations: []
            )
        case .interface:
            return UMLClassifier(
                kind: .interface,
                name: name ?? "Interfaz\(indexSuffix)",
                stereotype: "interface",
                isAbstract: true,
                attributes: [],
                operations: []
            )
        case .enumeration:
            return UMLClassifier(
                kind: .enumeration,
                name: name ?? "Enum\(indexSuffix)",
                stereotype: "enumeration",
                isAbstract: false,
                attributes: [],
                operations: [],
                enumLiterals: []
            )
        }
    }
}
