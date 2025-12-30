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
    /// Relative path to the PDF file stored on disk (Application Support).
    /// Example: "Templates/<uuid>.pdf"
    var pdfFilePath: String?

    /// Legacy storage: some older versions embedded the PDF bytes directly in JSON.
    /// We keep this optional for one-time migration and as a fallback if the disk file is missing.
    var pdfData: Data?
    var fields: [PDFField]
    var fieldMappings: [String: String] // fieldName -> recipientProperty
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        pdfFilePath: String? = nil,
        pdfData: Data? = nil,
        fields: [PDFField] = [],
        fieldMappings: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.pdfFilePath = pdfFilePath
        self.pdfData = pdfData
        self.fields = fields
        self.fieldMappings = fieldMappings
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case pdfFilePath
        case pdfData
        case fields
        case fieldMappings
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.name = (try? container.decode(String.self, forKey: .name)) ?? "Template"
        self.pdfFilePath = try? container.decodeIfPresent(String.self, forKey: .pdfFilePath)
        self.pdfData = try? container.decodeIfPresent(Data.self, forKey: .pdfData)
        self.fields = (try? container.decode([PDFField].self, forKey: .fields)) ?? []
        self.fieldMappings = (try? container.decode([String: String].self, forKey: .fieldMappings)) ?? [:]
        self.createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(pdfFilePath, forKey: .pdfFilePath)
        try container.encode(fields, forKey: .fields)
        try container.encode(fieldMappings, forKey: .fieldMappings)
        try container.encode(createdAt, forKey: .createdAt)

        // IMPORTANT: Do not re-embed large PDF bytes once the template is disk-backed.
        if pdfFilePath == nil {
            try container.encodeIfPresent(pdfData, forKey: .pdfData)
        }
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
