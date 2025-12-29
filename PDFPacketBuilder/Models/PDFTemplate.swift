//
//  PDFTemplate.swift
//  PDFPacketSender
//
//  Model for PDF template and field mappings
//

import Foundation

struct PDFTemplate: Codable, Identifiable {
    let id: UUID
    var name: String
    var pdfData: Data
    var fields: [PDFField]
    var fieldMappings: [String: String] // fieldName -> recipientProperty
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, pdfData: Data, fields: [PDFField] = [], fieldMappings: [String: String] = [:], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.pdfData = pdfData
        self.fields = fields
        self.fieldMappings = fieldMappings
        self.createdAt = createdAt
    }
}

struct PDFField: Codable, Identifiable {
    let id: UUID
    var name: String
    var type: FieldType
    var defaultValue: String?
    var normalized: NormalizedName?
    
    enum FieldType: String, Codable {
        case text
        case number
        case date
        case checkbox
    }
    
    init(id: UUID = UUID(), name: String, type: FieldType = .text, defaultValue: String? = nil, normalized: NormalizedName? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.normalized = normalized
    }
}

// MARK: - Mapping + normalization support

enum NormalizedFieldHint: String, Codable {
    case firstName
    case lastName
    case fullName
    case email
    case phone
    case date
    case initials
    case signature
    case unknown
}

struct NormalizedName: Hashable, Codable {
    var original: String
    var tokens: [String]
    var hint: NormalizedFieldHint

    var tokenSet: Set<String> { Set(tokens) }

    init(original: String, tokens: [String], hint: NormalizedFieldHint) {
        self.original = original
        self.tokens = tokens
        self.hint = hint
    }

    static func from(_ raw: String) -> NormalizedName {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = NameNormalizer.tokenize(trimmed)
        let hint = NameNormalizer.hint(forTokens: tokens)
        return NormalizedName(original: raw, tokens: tokens, hint: hint)
    }
}

enum NameNormalizer {
    private static let stopwords: Set<String> = [
        "the", "a", "an", "and", "or", "of", "to", "for", "in", "on", "at",
        "field", "value", "text"
    ]

    static func tokenize(_ input: String) -> [String] {
        guard !input.isEmpty else { return [] }

        let withBoundaries = splitCamelAndDigitBoundaries(input)

        let parts = withBoundaries
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let filtered = parts.filter { token in
            if stopwords.contains(token) { return false }
            return token.range(of: "^[0-9]+$", options: .regularExpression) == nil
        }

        return filtered
    }

    static func hint(forTokens tokens: [String]) -> NormalizedFieldHint {
        let set = Set(tokens)

        if set.contains("signature") || set.contains("sign") || set.contains("signed") {
            return .signature
        }
        if set.contains("initial") || set.contains("initials") {
            return .initials
        }
        if set.contains("email") || (set.contains("e") && set.contains("mail")) {
            return .email
        }
        if set.contains("phone") || set.contains("tel") || set.contains("mobile") {
            return .phone
        }
        if set.contains("date") || set.contains("dated") {
            return .date
        }
        if set.contains("first") && set.contains("name") {
            return .firstName
        }
        if set.contains("last") && set.contains("name") {
            return .lastName
        }
        if (set.contains("full") && set.contains("name")) || set.contains("fullname") {
            return .fullName
        }
        if set.contains("name") {
            return .fullName
        }

        return .unknown
    }

    private static func splitCamelAndDigitBoundaries(_ input: String) -> String {
        guard input.count >= 2 else { return input }

        var out = ""
        out.reserveCapacity(input.count + 8)

        var prev: Character?
        for ch in input {
            if let prev, isBoundary(prev: prev, curr: ch) {
                out.append(" ")
            }
            out.append(ch)
            prev = ch
        }

        return out
    }

    private static func isBoundary(prev: Character, curr: Character) -> Bool {
        if prev.isLowercase && curr.isUppercase { return true }
        if prev.isNumber && curr.isLetter { return true }
        if prev.isLetter && curr.isNumber { return true }
        return false
    }
}

struct MappingOption: Hashable, Identifiable {
    enum Kind: Hashable {
        case builtIn
        case csvHeader
        case computed
    }

    var id: String { value }

    let value: String
    let label: String
    let normalized: NormalizedName
    let kind: Kind

    var isAutoMappable: Bool {
        if value == ComputedMappingValue.blank.rawValue { return false }
        if value == ComputedMappingValue.today.rawValue { return false }
        return true
    }
}

enum ComputedMappingValue: String {
    case initials = "__computed__:initials"
    case today = "__computed__:today"
    case blank = "__computed__:blank"
}

enum AutoMapper {
    static func suggest(pdfField: NormalizedName, candidates: [MappingOption]) -> String? {
        if pdfField.hint == .signature { return nil }
        if pdfField.hint == .unknown, pdfField.tokens.count <= 1 { return nil }

        let scored: [(MappingOption, Double)] = candidates
            .filter { $0.isAutoMappable }
            .map { ($0, score(pdf: pdfField, candidate: $0)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }

        guard let best = scored.first else { return nil }
        let bestScore = best.1
        guard bestScore >= 0.90 else { return nil }

        if scored.count >= 2 {
            let secondScore = scored[1].1
            guard (bestScore - secondScore) >= 0.15 else { return nil }
        }

        return best.0.value
    }

    private static func score(pdf: NormalizedName, candidate: MappingOption) -> Double {
        let a = pdf.tokenSet
        let b = candidate.normalized.tokenSet

        let base = jaccard(a, b)
        if base == 0 { return 0 }

        var score = base

        if pdf.hint != .unknown, pdf.hint == candidate.normalized.hint {
            score += 0.35
        }

        switch (pdf.hint, candidate.value) {
        case (.firstName, "FirstName"): score += 0.25
        case (.lastName, "LastName"): score += 0.25
        case (.fullName, "FullName"): score += 0.25
        case (.email, "Email"): score += 0.25
        case (.phone, "PhoneNumber"): score += 0.25
        case (.initials, _):
            if candidate.value == ComputedMappingValue.initials.rawValue {
                score += 0.20
            }
        default:
            break
        }

        if candidate.kind == .computed, pdf.hint != .initials {
            score -= 0.05
        }

        return max(0, min(score, 2.0))
    }

    private static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        if a.isEmpty || b.isEmpty { return 0 }
        let intersection = a.intersection(b).count
        if intersection == 0 { return 0 }
        let union = a.union(b).count
        guard union > 0 else { return 0 }
        return Double(intersection) / Double(union)
    }
}
