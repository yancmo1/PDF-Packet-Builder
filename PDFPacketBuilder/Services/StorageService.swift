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
    
    // MARK: - Template Storage
    
    func saveTemplate(_ template: PDFTemplate?) {
        if let template = template {
            if let encoded = try? JSONEncoder().encode(template) {
                defaults.set(encoded, forKey: templateKey)
            }
        } else {
            defaults.removeObject(forKey: templateKey)
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
    
    // MARK: - Document Directory Access
    
    func getDocumentsDirectory() -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
