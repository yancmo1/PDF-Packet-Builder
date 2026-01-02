import Foundation

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

        // Split on any non-alphanumeric.
        let parts = withBoundaries
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Drop purely-numeric tokens (common for "Date 1", "Initials 2", etc.).
        // This helps map repeated fields without requiring CSV header edits.
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
        if set.contains("email") || set.contains("e") && set.contains("mail") {
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

        // A generic single-token "Name" field is usually ambiguous (ParentName, StudentName, etc.).
        // Keep it conservative to prefer false-negatives.
        if set.contains("name") {
            return tokens.count <= 1 ? .unknown : .fullName
        }

        return .unknown
    }

    private static func splitCamelAndDigitBoundaries(_ input: String) -> String {
        guard input.count >= 2 else { return input }

        var out = ""
        out.reserveCapacity(input.count + 8)

        var prev: Character?
        for ch in input {
            if let prev {
                if isBoundary(prev: prev, curr: ch) {
                    out.append(" ")
                }
            }
            out.append(ch)
            prev = ch
        }

        return out
    }

    private static func isBoundary(prev: Character, curr: Character) -> Bool {
        // lower -> Upper (camelCase)
        if prev.isLowercase && curr.isUppercase { return true }
        // letter -> digit or digit -> letter
        if prev.isNumber && curr.isLetter { return true }
        if prev.isLetter && curr.isNumber { return true }
        return false
    }
}
