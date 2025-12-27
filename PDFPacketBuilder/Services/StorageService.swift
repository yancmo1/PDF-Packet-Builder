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
    private let proStatusKey = "isPro"
    private let csvImportKey = "csvImport"
    
    // MARK: - Template Storage
    
    func saveTemplate(_ template: PDFTemplate) {
        if let encoded = try? JSONEncoder().encode(template) {
            defaults.set(encoded, forKey: templateKey)
        }
    }
    
    func loadTemplate() -> PDFTemplate? {
        guard let data = defaults.data(forKey: templateKey) else { return nil }
        return try? JSONDecoder().decode(PDFTemplate.self, from: data)
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
    }
    
    func loadProStatus() -> Bool {
        return defaults.bool(forKey: proStatusKey)
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
            try data.write(to: url)
            return url
        } catch {
            print("Error saving PDF: \(error)")
            return nil
        }
    }
}
