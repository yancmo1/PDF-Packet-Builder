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
    var messageTemplate: MessageTemplate
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, pdfData: Data, fields: [PDFField] = [], fieldMappings: [String: String] = [:], messageTemplate: MessageTemplate = .emptyDisabled, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.pdfData = pdfData
        self.fields = fields
        self.fieldMappings = fieldMappings
        self.messageTemplate = messageTemplate
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case pdfData
        case fields
        case fieldMappings
        case messageTemplate
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.pdfData = try container.decode(Data.self, forKey: .pdfData)
        self.fields = (try container.decodeIfPresent([PDFField].self, forKey: .fields)) ?? []
        self.fieldMappings = (try container.decodeIfPresent([String: String].self, forKey: .fieldMappings)) ?? [:]
        self.messageTemplate = (try container.decodeIfPresent(MessageTemplate.self, forKey: .messageTemplate)) ?? .emptyDisabled
        self.createdAt = (try container.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(pdfData, forKey: .pdfData)
        try container.encode(fields, forKey: .fields)
        try container.encode(fieldMappings, forKey: .fieldMappings)
        try container.encode(messageTemplate, forKey: .messageTemplate)
        try container.encode(createdAt, forKey: .createdAt)
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
