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
    var fields: [PDFField]
    var fieldMappings: [String: String] // fieldName -> recipientProperty
    var messageTemplate: MessageTemplate
    var createdAt: Date
    
    /// File path to PDF stored on disk (preferred storage)
    var pdfFilePath: String?
    
    /// Legacy: embedded PDF data (used only for migration)
    private var legacyPdfData: Data?
    
    /// Returns PDF data, loading from disk if available
    var pdfData: Data? {
        // Prefer disk-based storage
        if let filePath = pdfFilePath {
            let url = URL(fileURLWithPath: filePath)
            return try? Data(contentsOf: url)
        }
        // Fall back to legacy embedded data
        return legacyPdfData
    }
    
    /// Whether this template needs migration (has embedded data but no file path)
    var needsMigration: Bool {
        return legacyPdfData != nil && pdfFilePath == nil
    }
    
    /// The legacy embedded data for migration purposes
    var legacyDataForMigration: Data? {
        return legacyPdfData
    }
    
    init(id: UUID = UUID(), name: String, pdfData: Data, fields: [PDFField] = [], fieldMappings: [String: String] = [:], messageTemplate: MessageTemplate = .emptyDisabled, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.legacyPdfData = pdfData
        self.pdfFilePath = nil
        self.fields = fields
        self.fieldMappings = fieldMappings
        self.messageTemplate = messageTemplate
        self.createdAt = createdAt
    }
    
    init(id: UUID = UUID(), name: String, pdfFilePath: String, fields: [PDFField] = [], fieldMappings: [String: String] = [:], messageTemplate: MessageTemplate = .emptyDisabled, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.pdfFilePath = pdfFilePath
        self.legacyPdfData = nil
        self.fields = fields
        self.fieldMappings = fieldMappings
        self.messageTemplate = messageTemplate
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case pdfData // legacy key, read-only for migration
        case pdfFilePath
        case fields
        case fieldMappings
        case messageTemplate
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.pdfFilePath = try container.decodeIfPresent(String.self, forKey: .pdfFilePath)
        self.legacyPdfData = try container.decodeIfPresent(Data.self, forKey: .pdfData)
        self.fields = (try container.decodeIfPresent([PDFField].self, forKey: .fields)) ?? []
        self.fieldMappings = (try container.decodeIfPresent([String: String].self, forKey: .fieldMappings)) ?? [:]
        self.messageTemplate = (try container.decodeIfPresent(MessageTemplate.self, forKey: .messageTemplate)) ?? .emptyDisabled
        self.createdAt = (try container.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        // Only encode pdfFilePath; never write legacyPdfData back
        try container.encodeIfPresent(pdfFilePath, forKey: .pdfFilePath)
        try container.encode(fields, forKey: .fields)
        try container.encode(fieldMappings, forKey: .fieldMappings)
        try container.encode(messageTemplate, forKey: .messageTemplate)
        try container.encode(createdAt, forKey: .createdAt)
    }
    
    /// Returns a copy with the file path set (used after migration)
    func withFilePath(_ path: String) -> PDFTemplate {
        var copy = self
        copy.pdfFilePath = path
        copy.legacyPdfData = nil
        return copy
    }
    
    /// Clears the legacy data after successful migration
    mutating func clearLegacyData() {
        self.legacyPdfData = nil
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
