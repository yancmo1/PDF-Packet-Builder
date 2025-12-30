//
//  MessageTemplateRenderer.swift
//  PDFPacketBuilder
//
//  Pure rendering engine for token substitution.
//

import Foundation

struct MessageTemplateRenderer {
    /// Renders a template replacing tokens of the form `{{TokenName}}`.
    ///
    /// Rules (per audit spec + tests):
    /// - Unknown tokens are preserved verbatim.
    /// - Known tokens that are unresolved render as an empty string.
    /// - Known tokens are replaced.
    static func render(_ template: String, values: [String: String?]) -> String {
        guard template.contains("{{") else { return template }

        let pattern = #"\{\{\s*([A-Za-z0-9_\-\.]+)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return template
        }

        let ns = template as NSString
        let matches = regex.matches(in: template, options: [], range: NSRange(location: 0, length: ns.length))
        if matches.isEmpty { return template }

        var out = template
        // Replace from end to keep ranges stable.
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }
            let tokenRange = match.range(at: 1)
            let fullRange = match.range(at: 0)
            let token = ns.substring(with: tokenRange)

            guard let maybeValue = values[token] else {
                // Unknown token: preserve as-is.
                continue
            }

            let replacement = maybeValue ?? ""
            if let swiftRange = Range(fullRange, in: out) {
                out.replaceSubrange(swiftRange, with: replacement)
            }
        }

        return out
    }
}
