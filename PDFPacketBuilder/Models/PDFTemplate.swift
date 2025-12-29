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
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, pdfData: Data, fields: [PDFField] = [], fieldMappings: [String: String] = [:], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.pdfData = pdfData
        self.fields = fields
        self.fieldMappings = fieldMappings
        self.createdAt = createdAt
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
