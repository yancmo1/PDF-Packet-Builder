//
//  StorageService.swift
//  PDFPacketSender
//
//  Local storage service for offline-first data persistence
//

import Foundation

class StorageService {
    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let templateBaseDirectoryOverride: URL?

    init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        templateBaseDirectoryOverride: URL? = nil
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.templateBaseDirectoryOverride = templateBaseDirectoryOverride
    }
    
    // Keys
    private let templateKey = "pdfTemplate"
    private let recipientsKey = "recipients"
    private let logsKey = "sendLogs"
    private let proStatusKey = "isProUnlocked"
    private let legacyProStatusKey = "isPro"
    private let csvImportKey = "csvImport"
    private let csvEmailColumnKey = "csvEmailColumn"
    private let csvDisplayNameColumnKey = "csvDisplayNameColumn"
    
    // MARK: - Template Storage
    
    func saveTemplate(_ template: PDFTemplate?) {
        if var template {
            // Ensure we never persist large PDF bytes in UserDefaults once disk-backed.
            // If the PDF is still embedded (legacy/in-memory), write it to disk and set pdfFilePath.
            if (template.pdfFilePath == nil || template.pdfFilePath?.isEmpty == true),
               let data = template.pdfData,
               !data.isEmpty {
                let relativePath = saveTemplatePDFData(data, templateID: template.id)
                template.pdfFilePath = relativePath
            }

            // Persist metadata only (Codable encode omits pdfData when pdfFilePath exists).
            if let encoded = try? JSONEncoder().encode(template) {
                defaults.set(encoded, forKey: templateKey)
            }
        } else {
            defaults.removeObject(forKey: templateKey)
        }
    }
    
    func loadTemplate() -> PDFTemplate? {
        guard let data = defaults.data(forKey: templateKey) else { return nil }
        guard var decoded = try? JSONDecoder().decode(PDFTemplate.self, from: data) else { return nil }

        // One-time migration: legacy templates embedded pdfData in JSON and had no pdfFilePath.
        if (decoded.pdfFilePath == nil || decoded.pdfFilePath?.isEmpty == true),
           let embedded = decoded.pdfData,
           !embedded.isEmpty {
            let relativePath = saveTemplatePDFData(embedded, templateID: decoded.id)
            decoded.pdfFilePath = relativePath
            // Drop embedded bytes after migration to keep memory + UserDefaults lean.
            decoded.pdfData = nil
            // Re-save to persist the new disk-backed reference.
            saveTemplate(decoded)
        }

        return decoded
    }

    // MARK: - Template PDF File Persistence

    /// Returns the base directory where we store app-managed template PDFs.
    /// Preferred location: Application Support/PDFPacketBuilder
    private func templateBaseDirectoryURL() -> URL {
        if let override = templateBaseDirectoryOverride {
            return override
        }

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        // Keep it stable and app-scoped.
        return appSupport.appendingPathComponent("PDFPacketBuilder", isDirectory: true)
    }

    private func templatesDirectoryURL() -> URL {
        templateBaseDirectoryURL().appendingPathComponent("Templates", isDirectory: true)
    }

    private func ensureTemplatesDirectoryExists() {
        let base = templateBaseDirectoryURL()
        if !fileManager.fileExists(atPath: base.path) {
            try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        }

        let templates = templatesDirectoryURL()
        if !fileManager.fileExists(atPath: templates.path) {
            try? fileManager.createDirectory(at: templates, withIntermediateDirectories: true)
        }
    }

    /// Save template PDF data to disk and return a relative file path suitable for persistence.
    /// - Returns: relative path like "Templates/<templateID>.pdf"
    @discardableResult
    func saveTemplatePDFData(_ data: Data, templateID: UUID) -> String {
        ensureTemplatesDirectoryExists()
        let fileName = "\(templateID.uuidString).pdf"
        let destination = templatesDirectoryURL().appendingPathComponent(fileName)

        do {
            try data.write(to: destination, options: [.atomic])
        } catch {
            print("Error saving template PDF: \(error)")
        }

        return "Templates/\(fileName)"
    }

    func loadTemplatePDFData(from relativePath: String) -> Data? {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let url = templateBaseDirectoryURL().appendingPathComponent(trimmed)
        return try? Data(contentsOf: url)
    }

    func deleteTemplatePDF(at relativePath: String) {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let url = templateBaseDirectoryURL().appendingPathComponent(trimmed)
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    func loadTemplatePDFData(for template: PDFTemplate) -> Data? {
        if let data = template.pdfData, !data.isEmpty {
            return data
        }
        if let path = template.pdfFilePath {
            return loadTemplatePDFData(from: path)
        }
        return nil
    }

    func deleteTemplatePDF(for template: PDFTemplate) {
        if let path = template.pdfFilePath {
            deleteTemplatePDF(at: path)
        }
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

    func saveCSVEmailColumn(_ column: String?) {
        let trimmed = column?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            defaults.set(trimmed, forKey: csvEmailColumnKey)
        } else {
            defaults.removeObject(forKey: csvEmailColumnKey)
        }
    }

    func loadCSVEmailColumn() -> String? {
        let value = defaults.string(forKey: csvEmailColumnKey)
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return nil
    }

    func saveCSVDisplayNameColumn(_ column: String?) {
        let trimmed = column?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            defaults.set(trimmed, forKey: csvDisplayNameColumnKey)
        } else {
            defaults.removeObject(forKey: csvDisplayNameColumnKey)
        }
    }

    func loadCSVDisplayNameColumn() -> String? {
        let value = defaults.string(forKey: csvDisplayNameColumnKey)
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return nil
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
