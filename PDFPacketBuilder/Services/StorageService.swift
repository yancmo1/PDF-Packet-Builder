//
//  StorageService.swift
//  PDFPacketSender
//
//  Local storage service for offline-first data persistence
//

import Foundation

class StorageService {
    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default
    
    // Keys
    private let templateKey = "pdfTemplate"
    private let recipientsKey = "recipients"
    private let logsKey = "sendLogs"
    private let proStatusKey = "isProUnlocked"
    private let legacyProStatusKey = "isPro"
    private let csvImportKey = "csvImport"
    private let selectedEmailColumnKey = "selectedEmailColumn"
    private let selectedDisplayNameColumnKey = "selectedDisplayNameColumn"
    private let legacyCSVEmailColumnKey = "csvEmailColumn"
    private let legacyCSVDisplayNameColumnKey = "csvDisplayNameColumn"
    private let senderNameKey = "senderName"
    private let senderEmailKey = "senderEmail"
    private let mailDraftsKey = "mailDrafts"
    
    // MARK: - Template PDF File Storage
    
    private func getTemplatesDirectory() -> URL {
        let dir = getDocumentsDirectory()
            .appendingPathComponent("Templates", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    func saveTemplatePDF(data: Data, templateID: UUID) -> String? {
        let filename = "\(templateID.uuidString).pdf"
        let url = getTemplatesDirectory().appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic])
            return url.path
        } catch {
            print("Error saving template PDF to disk: \(error)")
            return nil
        }
    }
    
    func loadTemplatePDF(from path: String) -> Data? {
        let url = URL(fileURLWithPath: path)
        return try? Data(contentsOf: url)
    }
    
    func deleteTemplatePDF(at path: String) {
        let url = URL(fileURLWithPath: path)
        try? fileManager.removeItem(at: url)
    }
    
    // MARK: - Template Storage
    
    func saveTemplate(_ template: PDFTemplate?) {
        guard let template = template else {
            // Remove old PDF file if it exists
            if let existing = loadTemplate(), let path = existing.pdfFilePath {
                deleteTemplatePDF(at: path)
            }
            defaults.removeObject(forKey: templateKey)
            return
        }
        
        var templateToSave = template
        
        // If template has no file path but has PDF data, write to disk first
        if template.pdfFilePath == nil, let pdfData = template.pdfData {
            if let path = saveTemplatePDF(data: pdfData, templateID: template.id) {
                templateToSave = template.withFilePath(path)
            }
        }
        
        if let encoded = try? JSONEncoder().encode(templateToSave) {
            defaults.set(encoded, forKey: templateKey)
        }
    }
    
    func loadTemplate() -> PDFTemplate? {
        guard let data = defaults.data(forKey: templateKey) else { return nil }
        guard var template = try? JSONDecoder().decode(PDFTemplate.self, from: data) else { return nil }
        
        // Migration: if template has legacy embedded data but no file path, migrate to disk
        if template.needsMigration, let legacyData = template.legacyDataForMigration {
            if let path = saveTemplatePDF(data: legacyData, templateID: template.id) {
                template = template.withFilePath(path)
                // Re-save to persist the migration
                if let encoded = try? JSONEncoder().encode(template) {
                    defaults.set(encoded, forKey: templateKey)
                }
            }
        }
        
        return template
    }
    
    // MARK: - Recipients Storage
    
    func saveRecipients(_ recipients: [Recipient]) {
        if let encoded = try? JSONEncoder().encode(recipients) {
            defaults.set(encoded, forKey: recipientsKey)
        }
    }
    
    func loadRecipients() -> [Recipient] {
        guard let data = defaults.data(forKey: recipientsKey) else { return [] }
        return (try? JSONDecoder().decode([Recipient].self, from: data)) ?? []
    }
    
    // MARK: - Logs Storage
    
    func saveLogs(_ logs: [SendLog]) {
        if let encoded = try? JSONEncoder().encode(logs) {
            defaults.set(encoded, forKey: logsKey)
        }
    }
    
    func loadLogs() -> [SendLog] {
        guard let data = defaults.data(forKey: logsKey) else { return [] }
        return (try? JSONDecoder().decode([SendLog].self, from: data)) ?? []
    }

    // MARK: - Mail Drafts Storage

    func saveMailDrafts(_ drafts: [MailDraft]) {
        if let encoded = try? JSONEncoder().encode(drafts) {
            defaults.set(encoded, forKey: mailDraftsKey)
        }
    }

    func loadMailDrafts() -> [MailDraft] {
        guard let data = defaults.data(forKey: mailDraftsKey) else { return [] }
        return (try? JSONDecoder().decode([MailDraft].self, from: data)) ?? []
    }

    func clearMailDrafts() {
        defaults.removeObject(forKey: mailDraftsKey)
    }
    
    // MARK: - Pro Status Storage
    
    func saveProStatus(_ isPro: Bool) {
        defaults.set(isPro, forKey: proStatusKey)
        defaults.set(isPro, forKey: legacyProStatusKey)
    }
    
    func loadProStatus() -> Bool {
        if defaults.object(forKey: proStatusKey) != nil {
            return defaults.bool(forKey: proStatusKey)
        }
        return defaults.bool(forKey: legacyProStatusKey)
    }

    // MARK: - CSV Import Storage

    func saveCSVImport(_ csvImport: CSVImportSnapshot) {
        if let encoded = try? JSONEncoder().encode(csvImport) {
            defaults.set(encoded, forKey: csvImportKey)
        }
    }

    func loadCSVImport() -> CSVImportSnapshot? {
        guard let data = defaults.data(forKey: csvImportKey) else { return nil }
        return try? JSONDecoder().decode(CSVImportSnapshot.self, from: data)
    }

    func clearCSVImport() {
        defaults.removeObject(forKey: csvImportKey)
    }

    func saveSelectedEmailColumn(_ column: String?) {
        let trimmed = column?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            defaults.set(trimmed, forKey: selectedEmailColumnKey)
            defaults.removeObject(forKey: legacyCSVEmailColumnKey)
        } else {
            defaults.removeObject(forKey: selectedEmailColumnKey)
            defaults.removeObject(forKey: legacyCSVEmailColumnKey)
        }
    }

    func loadSelectedEmailColumn() -> String? {
        let current = normalizedNonEmpty(defaults.string(forKey: selectedEmailColumnKey))
        if let current {
            return current
        }

        let legacy = normalizedNonEmpty(defaults.string(forKey: legacyCSVEmailColumnKey))
        if let legacy {
            // Migrate forward.
            defaults.set(legacy, forKey: selectedEmailColumnKey)
            defaults.removeObject(forKey: legacyCSVEmailColumnKey)
            return legacy
        }

        return nil
    }

    func saveSelectedDisplayNameColumn(_ column: String?) {
        let trimmed = column?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            defaults.set(trimmed, forKey: selectedDisplayNameColumnKey)
            defaults.removeObject(forKey: legacyCSVDisplayNameColumnKey)
        } else {
            defaults.removeObject(forKey: selectedDisplayNameColumnKey)
            defaults.removeObject(forKey: legacyCSVDisplayNameColumnKey)
        }
    }

    func loadSelectedDisplayNameColumn() -> String? {
        let current = normalizedNonEmpty(defaults.string(forKey: selectedDisplayNameColumnKey))
        if let current {
            return current
        }

        let legacy = normalizedNonEmpty(defaults.string(forKey: legacyCSVDisplayNameColumnKey))
        if let legacy {
            // Migrate forward.
            defaults.set(legacy, forKey: selectedDisplayNameColumnKey)
            defaults.removeObject(forKey: legacyCSVDisplayNameColumnKey)
            return legacy
        }

        return nil
    }

    @available(*, deprecated, message: "Use saveSelectedEmailColumn")
    func saveCSVEmailColumn(_ column: String?) {
        saveSelectedEmailColumn(column)
    }

    @available(*, deprecated, message: "Use loadSelectedEmailColumn")
    func loadCSVEmailColumn() -> String? {
        loadSelectedEmailColumn()
    }

    @available(*, deprecated, message: "Use saveSelectedDisplayNameColumn")
    func saveCSVDisplayNameColumn(_ column: String?) {
        saveSelectedDisplayNameColumn(column)
    }

    @available(*, deprecated, message: "Use loadSelectedDisplayNameColumn")
    func loadCSVDisplayNameColumn() -> String? {
        loadSelectedDisplayNameColumn()
    }

    private func normalizedNonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return nil
    }

    // MARK: - Sender Settings

    func saveSenderName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: senderNameKey)
        } else {
            defaults.set(trimmed, forKey: senderNameKey)
        }
    }

    func loadSenderName() -> String {
        let value = defaults.string(forKey: senderNameKey) ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func saveSenderEmail(_ email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: senderEmailKey)
        } else {
            defaults.set(trimmed, forKey: senderEmailKey)
        }
    }

    func loadSenderEmail() -> String {
        let value = defaults.string(forKey: senderEmailKey) ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Document Directory Access
    
    func getDocumentsDirectory() -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func importCSVToDocuments(from sourceURL: URL) throws -> CSVFileReference {
        let importsDir = getDocumentsDirectory()
            .appendingPathComponent("Imports", isDirectory: true)
            .appendingPathComponent("CSV", isDirectory: true)

        if !fileManager.fileExists(atPath: importsDir.path) {
            try fileManager.createDirectory(at: importsDir, withIntermediateDirectories: true)
        }

        let originalName = sourceURL.lastPathComponent
        let uniqueName = "\(UUID().uuidString)-\(originalName)"
        let destinationURL = importsDir.appendingPathComponent(uniqueName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            // Fallback for providers that don't support copyItem well.
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: destinationURL, options: [.atomic])
        }

        return CSVFileReference(originalFileName: originalName, localPath: destinationURL.path, importedAt: Date())
    }
    
    func savePDFToDocuments(data: Data, filename: String) -> URL? {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            print("Error saving PDF: \(error)")
            return nil
        }
    }
}
