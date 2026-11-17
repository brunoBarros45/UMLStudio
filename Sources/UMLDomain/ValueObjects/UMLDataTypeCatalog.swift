import Foundation

/// Provides standard data types ordered strictly from most common to least common,
/// plus model-defined classifiers for attribute types, parameter types, and return types.
public enum UMLDataTypeCatalog {
    /// Standard data types ordered from most common to least common.
    public static let orderedCommonTypes: [String] = [
        "String",
        "Int",
        "Bool",
        "Double",
        "Float",
        "Decimal",
        "UUID",
        "Date",
        "[String]",
        "[Int]",
        "Array<Any>",
        "Set<Any>",
        "Dictionary<String, Any>",
        "Int64",
        "Int32",
        "UInt",
        "Character",
        "Data",
        "URL",
        "Any"
    ]

    /// Returns ordered attribute/parameter types, appending user-defined classifiers
    /// and guaranteeing `currentType` is present so Picker bindings stay valid.
    public static func attributeTypes(
        including classifiers: [UMLClassifier],
        currentType: String? = nil
    ) -> [String] {
        var result = orderedCommonTypes
        for classifier in classifiers {
            let trimmed = classifier.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !result.contains(trimmed) {
                result.append(trimmed)
            }
        }
        if let current = currentType?.trimmingCharacters(in: .whitespacesAndNewlines),
           !current.isEmpty,
           !result.contains(current) {
            result.append(current)
        }
        return result
    }

    /// Returns ordered operation return types starting with `Void`.
    public static func returnTypes(
        including classifiers: [UMLClassifier],
        currentType: String? = nil
    ) -> [String] {
        var result = ["Void"] + attributeTypes(including: classifiers, currentType: nil)
        if let current = currentType?.trimmingCharacters(in: .whitespacesAndNewlines),
           !current.isEmpty,
           !result.contains(current) {
            result.append(current)
        }
        return result
    }
}
