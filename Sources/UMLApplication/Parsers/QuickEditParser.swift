import Foundation
import UMLDomain

/// Parses and formats StarUML-inspired QuickEdit UML expressions for attributes, operations, and headers.
public enum QuickEditParser {
    /// Parses `[+|-|#|~] name [: Type] [[mult]] [= defaultValue] [{static, readOnly}]`.
    public static func parseAttribute(_ rawInput: String) -> UMLAttribute? {
        var text = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        var isStatic = false
        var isReadOnly = false

        if let modifierMatch = extractTrailingBraces(&text) {
            let tokens = modifierMatch
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            isStatic = tokens.contains("static")
            isReadOnly = tokens.contains("readonly") || tokens.contains("readOnly".lowercased())
        }

        var visibility: UMLVisibility = .private
        if let first = text.first, let parsedVis = UMLVisibility(symbol: first) {
            visibility = parsedVis
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        var defaultValue: String?
        if let eqIndex = findTopLevelCharacter("=", in: text) {
            let rhs = String(text[text.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
            if !rhs.isEmpty {
                defaultValue = rhs
            }
            text = String(text[..<eqIndex]).trimmingCharacters(in: .whitespaces)
        }

        var multiplicity: String?
        if text.hasSuffix("]"), let openBracket = text.lastIndex(of: "[") {
            let inner = String(text[text.index(after: openBracket)..<text.index(before: text.endIndex)])
                .trimmingCharacters(in: .whitespaces)
            let before = String(text[..<openBracket]).trimmingCharacters(in: .whitespaces)
            // Treat trailing `[...]` as multiplicity only if a name precedes it (avoid stripping `[Type]` when used as array type).
            if !before.isEmpty && !before.hasSuffix(":") {
                multiplicity = inner.isEmpty ? nil : inner
                text = before
            }
        }

        var name = text
        var typeName = "String"
        if let colonIndex = findTopLevelCharacter(":", in: text) {
            name = String(text[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let parsedType = String(text[text.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            typeName = parsedType.isEmpty ? "Any" : parsedType
        }

        guard !name.isEmpty else { return nil }
        return UMLAttribute(
            visibility: visibility,
            name: name,
            typeName: typeName,
            multiplicity: multiplicity,
            defaultValue: defaultValue,
            isStatic: isStatic,
            isReadOnly: isReadOnly
        )
    }

    /// Parses `[+|-|#|~] name(p1: Type1 = def, p2: Type2) [: ReturnType] [{static, abstract}]`.
    public static func parseOperation(_ rawInput: String) -> UMLOperation? {
        var text = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        var isStatic = false
        var isAbstract = false

        if let modifierMatch = extractTrailingBraces(&text) {
            let tokens = modifierMatch
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            isStatic = tokens.contains("static")
            isAbstract = tokens.contains("abstract")
        }

        var visibility: UMLVisibility = .public
        if let first = text.first, let parsedVis = UMLVisibility(symbol: first) {
            visibility = parsedVis
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        guard let openParen = text.firstIndex(of: "("),
              let closeParen = matchingClosingParen(in: text, from: openParen) else {
            // Allow typing just a method name without parentheses
            let cleanName = text.trimmingCharacters(in: .whitespaces)
            guard !cleanName.isEmpty else { return nil }
            return UMLOperation(
                visibility: visibility,
                name: cleanName,
                parameters: [],
                returnType: "Void",
                isStatic: isStatic,
                isAbstract: isAbstract
            )
        }

        let name = String(text[..<openParen]).trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        let paramsChunk = String(text[text.index(after: openParen)..<closeParen])
        let parameters = parseParameters(paramsChunk)

        let remainder = String(text[text.index(after: closeParen)...]).trimmingCharacters(in: .whitespaces)
        var returnType: String? = "Void"
        if remainder.hasPrefix(":") {
            let parsedReturn = String(remainder.dropFirst()).trimmingCharacters(in: .whitespaces)
            returnType = parsedReturn.isEmpty ? nil : parsedReturn
        } else if !remainder.isEmpty {
            returnType = remainder
        }

        return UMLOperation(
            visibility: visibility,
            name: name,
            parameters: parameters,
            returnType: returnType,
            isStatic: isStatic,
            isAbstract: isAbstract
        )
    }

    /// Parses `<<stereotype>> ClassifierName` or `ClassifierName`.
    public static func parseClassifierHeader(_ rawInput: String) -> (stereotype: String?, name: String) {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<<"), let endRange = trimmed.range(of: ">>") {
            let stereotype = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let name = String(trimmed[endRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (stereotype.isEmpty ? nil : stereotype, name)
        }
        return (nil, trimmed)
    }

    // MARK: - Private Helpers

    private static func parseParameters(_ chunk: String) -> [UMLParameter] {
        let trimmed = chunk.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        return splitTopLevel(trimmed, by: ",").compactMap { segment in
            var item = segment.trimmingCharacters(in: .whitespaces)
            guard !item.isEmpty else { return nil }

            var defaultValue: String?
            if let eqIdx = findTopLevelCharacter("=", in: item) {
                let rhs = String(item[item.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
                if !rhs.isEmpty { defaultValue = rhs }
                item = String(item[..<eqIdx]).trimmingCharacters(in: .whitespaces)
            }

            if let colonIdx = findTopLevelCharacter(":", in: item) {
                let pName = String(item[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let pType = String(item[item.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                guard !pName.isEmpty else { return nil }
                return UMLParameter(
                    name: pName,
                    typeName: pType.isEmpty ? "Any" : pType,
                    defaultValue: defaultValue
                )
            } else {
                return UMLParameter(name: item, typeName: "Any", defaultValue: defaultValue)
            }
        }
    }

    private static func extractTrailingBraces(_ text: inout String) -> String? {
        guard text.hasSuffix("}"), let openBrace = text.lastIndex(of: "{") else {
            return nil
        }
        let inner = String(text[text.index(after: openBrace)..<text.index(before: text.endIndex)])
        text = String(text[..<openBrace]).trimmingCharacters(in: .whitespaces)
        return inner
    }

    private static func matchingClosingParen(in text: String, from openIndex: String.Index) -> String.Index? {
        var depth = 0
        var idx = openIndex
        while idx < text.endIndex {
            let ch = text[idx]
            if ch == "(" { depth += 1 }
            if ch == ")" {
                depth -= 1
                if depth == 0 { return idx }
            }
            idx = text.index(after: idx)
        }
        return nil
    }

    private static func findTopLevelCharacter(_ target: Character, in text: String) -> String.Index? {
        var angleDepth = 0
        var bracketDepth = 0
        var parenDepth = 0
        var inQuotes = false

        for idx in text.indices {
            let ch = text[idx]
            if ch == "\"" { inQuotes.toggle() }
            guard !inQuotes else { continue }
            switch ch {
            case "<": angleDepth += 1
            case ">": angleDepth = max(0, angleDepth - 1)
            case "[": bracketDepth += 1
            case "]": bracketDepth = max(0, bracketDepth - 1)
            case "(": parenDepth += 1
            case ")": parenDepth = max(0, parenDepth - 1)
            default:
                if ch == target && angleDepth == 0 && bracketDepth == 0 && parenDepth == 0 {
                    return idx
                }
            }
        }
        return nil
    }

    private static func splitTopLevel(_ text: String, by separator: Character) -> [String] {
        var result: [String] = []
        var current = ""
        var angleDepth = 0
        var bracketDepth = 0
        var parenDepth = 0
        var inQuotes = false

        for ch in text {
            if ch == "\"" { inQuotes.toggle() }
            if !inQuotes {
                switch ch {
                case "<": angleDepth += 1
                case ">": angleDepth = max(0, angleDepth - 1)
                case "[": bracketDepth += 1
                case "]": bracketDepth = max(0, bracketDepth - 1)
                case "(": parenDepth += 1
                case ")": parenDepth = max(0, parenDepth - 1)
                default: break
                }
                if ch == separator && angleDepth == 0 && bracketDepth == 0 && parenDepth == 0 {
                    result.append(current)
                    current = ""
                    continue
                }
            }
            current.append(ch)
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result
    }
}
