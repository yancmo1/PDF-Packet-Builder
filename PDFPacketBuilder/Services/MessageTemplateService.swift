//
//  MessageTemplateService.swift
//  PDFPacketBuilder
//
//  Thin orchestrator around MessageTemplateRenderer.
//

import Foundation

struct MessageTemplateService {
    struct RenderContext {
        var recipient: Recipient
        var templateName: String
        var outputFileName: String
    }

    static let knownTokens: [String] = [
        "FirstName",
        "LastName",
        "FullName",
        "Email",
        "TemplateName",
        "FileName"
    ]

    static func renderSubject(_ template: MessageTemplate, context: RenderContext) -> String {
        let values = tokenValues(context: context)
        return MessageTemplateRenderer.render(template.subjectTemplate, values: values)
    }

    static func renderBody(_ template: MessageTemplate, context: RenderContext) -> String {
        let values = tokenValues(context: context)
        return MessageTemplateRenderer.render(template.bodyTemplate, values: values)
    }

    static func tokenValues(context: RenderContext) -> [String: String?] {
        // Known tokens are present in the dictionary even if unresolved (nil -> empty).
        // Unknown tokens will not appear and therefore will be preserved by the renderer.
        return [
            "FirstName": context.recipient.firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            "LastName": context.recipient.lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            "FullName": context.recipient.fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            "Email": context.recipient.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : context.recipient.email.trimmingCharacters(in: .whitespacesAndNewlines),
            "TemplateName": context.templateName,
            "FileName": context.outputFileName
        ]
    }
}
