import Foundation

struct MessageTemplateValidation: Hashable {
    var unknownTokens: Set<String>
    var unresolvedTokens: Set<String>
    var requiredFieldIssues: [String]

    static var empty: MessageTemplateValidation {
        MessageTemplateValidation(unknownTokens: [], unresolvedTokens: [], requiredFieldIssues: [])
    }
}

struct MessageTemplateRenderResult: Hashable {
    var subject: String
    var body: String
    var validation: MessageTemplateValidation
}

struct MessageTemplateRenderer {
    /// Tokens that do not come from CSV headers.
    static let systemTokens: Set<String> = [
        "recipient_name",
        "recipient_email",
        "packet_title",
        "date",
        "sender_name",
        "sender_email"
    ]

    private static let tokenRegex: NSRegularExpression = {
        // {{token_name}} with optional whitespace inside braces.
        // Tokens are lower_snake_case in v1.
        let pattern = #"\{\{\s*([a-z0-9_]+)\s*\}\}"#
        return (try? NSRegularExpression(pattern: pattern, options: [])) ?? NSRegularExpression()
    }()

    static func extractTokens(from text: String) -> Set<String> {
        let ns = text as NSString
        let matches = tokenRegex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        var tokens: Set<String> = []
        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let token = ns.substring(with: match.range(at: 1))
            if !token.isEmpty {
                tokens.insert(token)
            }
        }
        return tokens
    }

    static func validate(tokens: Set<String>, allowedTokens: Set<String>, resolvedValues: [String: String], requiredFieldIssues: [String]) -> MessageTemplateValidation {
        let unknown = tokens.subtracting(allowedTokens)

        var unresolved: Set<String> = []
        for token in tokens.intersection(allowedTokens) {
            let value = resolvedValues[token]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if value.isEmpty {
                unresolved.insert(token)
            }
        }

        return MessageTemplateValidation(
            unknownTokens: unknown,
            unresolvedTokens: unresolved,
            requiredFieldIssues: requiredFieldIssues
        )
    }

    static func render(template: MessageTemplate, allowedTokens: Set<String>, resolvedValues: [String: String], requiredFieldIssues: [String] = []) -> MessageTemplateRenderResult {
        let subjectTokens = extractTokens(from: template.subject)
        let bodyTokens = extractTokens(from: template.body)
        let allTokens = subjectTokens.union(bodyTokens)

        let validation = validate(tokens: allTokens, allowedTokens: allowedTokens, resolvedValues: resolvedValues, requiredFieldIssues: requiredFieldIssues)

        let renderedSubject = renderText(template.subject, allowedTokens: allowedTokens, resolvedValues: resolvedValues)
        let renderedBody = renderText(template.body, allowedTokens: allowedTokens, resolvedValues: resolvedValues)

        return MessageTemplateRenderResult(subject: renderedSubject, body: renderedBody, validation: validation)
    }

    static func renderText(_ text: String, allowedTokens: Set<String>, resolvedValues: [String: String]) -> String {
        let ns = text as NSString
        let matches = tokenRegex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        if matches.isEmpty { return text }

        var result = text

        // Replace from end to start to keep ranges stable.
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }

            let tokenRange = match.range(at: 1)
            let fullRange = match.range(at: 0)
            guard tokenRange.location != NSNotFound, fullRange.location != NSNotFound else { continue }

            let token = ns.substring(with: tokenRange)

            guard allowedTokens.contains(token) else {
                // Unknown tokens are preserved as-is.
                continue
            }

            let replacement = resolvedValues[token] ?? ""
            result = (result as NSString).replacingCharacters(in: fullRange, with: replacement)
        }

        return result
    }
}
