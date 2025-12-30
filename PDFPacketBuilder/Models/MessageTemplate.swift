//
//  MessageTemplate.swift
//  PDFPacketBuilder
//
//  Pro feature: customizable subject/body templates with token substitution.
//

import Foundation

struct MessageTemplate: Codable, Hashable {
    var isEnabled: Bool
    var subjectTemplate: String
    var bodyTemplate: String

    static let `default` = MessageTemplate(
        isEnabled: false,
        subjectTemplate: "{{TemplateName}} PDF",
        bodyTemplate: "Hi {{FullName}},\n\nAttached is your packet.\n"
    )
}
