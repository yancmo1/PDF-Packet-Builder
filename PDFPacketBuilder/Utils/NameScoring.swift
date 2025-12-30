import Foundation

/// Shared utility for scoring whether a string looks like a person's name.
/// Used by CSVService, GenerateView, and RecipientsView for display name detection.
struct NameScoring {
    
    /// Returns a score from 0.0 to 1.0 indicating how likely a string is a person's name.
    /// Higher scores indicate more name-like strings.
    static func personNameScore(_ raw: String) -> Double {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return 0.0 }
        if value.contains("@") { return 0.0 }

        // Reject if it contains digits
        let digitCount = value.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        if digitCount > 0 { return 0.0 }

        // Basic word count
        let words = value
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: { $0.isWhitespace })

        if words.isEmpty { return 0.0 }

        // Penalize long/compound strings
        if words.count > 5 { return 0.20 }

        // Measure letter density
        let letterCount = value.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        let scalarCount = max(1, value.unicodeScalars.count)
        let letterRatio = Double(letterCount) / Double(scalarCount)
        if letterRatio < 0.55 { return 0.0 }

        // Common name shapes
        if words.count == 2 || words.count == 3 { return 1.0 }
        if words.count == 1 { return 0.45 }
        if words.count == 4 { return 0.65 }

        return 0.50
    }
    
    /// Attempts to find the best name-like value from a recipient's custom fields.
    /// Returns nil if no suitable candidate is found.
    static func bestNameFromCustomFields(_ customFields: [String: String]) -> String? {
        let candidates: [(value: String, score: Double)] = customFields.compactMap { key, value in
            let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !v.isEmpty else { return nil }
            guard !v.contains("@") else { return nil }

            let tokens = Set(NormalizedName.from(key).tokens)
            
            // Skip fields that are clearly not names
            if tokens.contains("email") || tokens.contains("phone") || tokens.contains("date") {
                return nil
            }

            var s: Double = 0.0
            
            // Header-based scoring
            if tokens.contains("name") { s += 0.6 }
            if tokens.contains("student") || tokens.contains("parent") || tokens.contains("guardian") { s += 0.2 }
            if tokens.contains("team") || tokens.contains("club") || tokens.contains("org") || tokens.contains("organization") { s -= 0.4 }

            // Value-shape bonus
            s += personNameScore(v) * 0.6
            return (v, s)
        }

        guard let best = candidates.max(by: { $0.score < $1.score }), best.score >= 0.75 else {
            return nil
        }
        return best.value
    }
}
