import Foundation

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
        // Computed values are intentionally conservative for auto-mapping.
        // (Still available in the dropdown for manual selection.)
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
        // Never guess signatures.
        if pdfField.hint == .signature { return nil }

        // If we have no signal, don't guess.
        if pdfField.hint == .unknown, pdfField.tokens.count <= 1 {
            return nil
        }

        let scored: [(MappingOption, Double)] = candidates
            .filter { $0.isAutoMappable }
            .map { ($0, score(pdf: pdfField, candidate: $0)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }

        guard let best = scored.first else { return nil }

        // Conservative thresholding. Goal: predictable and reversible.
        let bestScore = best.1
        guard bestScore >= 0.90 else { return nil }

        if scored.count >= 2 {
            let secondScore = scored[1].1
            // Require clear separation so repeated/numbered fields won't get "random" ties.
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

        // Hint match boost.
        if pdf.hint != .unknown, pdf.hint == candidate.normalized.hint {
            score += 0.35
        }

        // Small boosts for common, user-expected mappings.
        switch (pdf.hint, candidate.value) {
        case (.firstName, "FirstName"): score += 0.25
        case (.lastName, "LastName"): score += 0.25
        case (.fullName, "FullName"): score += 0.25
        case (.email, "Email"): score += 0.25
        case (.phone, "PhoneNumber"): score += 0.25
        case (.date, _):
            // Prefer actual date columns/labels over computed Today.
            if candidate.value == ComputedMappingValue.today.rawValue {
                score -= 0.05
            }
        case (.initials, _):
            if candidate.value == ComputedMappingValue.initials.rawValue {
                score += 0.20
            }
        default:
            break
        }

        // Slight penalty for computed values in general (except when strongly hinted).
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
