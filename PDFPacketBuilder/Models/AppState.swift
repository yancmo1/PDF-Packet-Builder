//
//  AppState.swift
//  PDFPacketBuilder
//

import Foundation
import SwiftUI

class AppState: ObservableObject {
    @Published var pdfTemplate: PDFTemplate?
    @Published var recipients: [Recipient] = []
    @Published var sendLogs: [SendLog] = []
    @Published var isProUnlocked: Bool = false
    @Published var csvImport: CSVImportSnapshot? = nil
    @Published var csvEmailColumn: String? = nil
    @Published var csvDisplayNameColumn: String? = nil
    
    private let storageService = StorageService()
    
    static let freeMaxTemplates = 1
    static let freeMaxRecipients = 10
    static let freeLogRetentionDays = 7
    
    init() {
        loadState()
        cleanOldLogs()
    }
    
    func loadState() {
        self.pdfTemplate = storageService.loadTemplate()
        self.recipients = storageService.loadRecipients()
        self.sendLogs = storageService.loadLogs()
        self.isProUnlocked = storageService.loadProStatus()
        self.csvImport = storageService.loadCSVImport()
        self.csvEmailColumn = storageService.loadCSVEmailColumn()
        self.csvDisplayNameColumn = storageService.loadCSVDisplayNameColumn()
    }
    
    func canAddTemplate() -> Bool {
        return isProUnlocked || pdfTemplate == nil
    }
    
    func canGenerateWithRecipientCount(_ count: Int) -> Bool {
        return isProUnlocked || count <= Self.freeMaxRecipients
    }
    
    func saveTemplate(_ template: PDFTemplate) {
        self.pdfTemplate = template
        storageService.saveTemplate(template)
    }
    
    func saveRecipients(_ recipients: [Recipient]) {
        self.recipients = recipients
        storageService.saveRecipients(recipients)
    }

    func saveCSVImport(_ csvImport: CSVImportSnapshot) {
        self.csvImport = csvImport
        storageService.saveCSVImport(csvImport)
    }

    func clearCSVImport() {
        self.csvImport = nil
        storageService.clearCSVImport()
    }

    func saveCSVEmailColumn(_ column: String?) {
        let trimmed = column?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, trimmed.isEmpty {
            csvEmailColumn = nil
            storageService.saveCSVEmailColumn(nil)
        } else {
            csvEmailColumn = trimmed
            storageService.saveCSVEmailColumn(trimmed)
        }
    }

    func saveCSVDisplayNameColumn(_ column: String?) {
        let trimmed = column?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, trimmed.isEmpty {
            csvDisplayNameColumn = nil
            storageService.saveCSVDisplayNameColumn(nil)
        } else {
            csvDisplayNameColumn = trimmed
            storageService.saveCSVDisplayNameColumn(trimmed)
        }
    }
    
    func addSendLog(_ log: SendLog) {
        self.sendLogs.insert(log, at: 0)
        storageService.saveLogs(sendLogs)
    }
    
    func updateProStatus(_ isPro: Bool) {
        self.isProUnlocked = isPro
        storageService.saveProStatus(isPro)
        cleanOldLogs()
    }
    
    func cleanOldLogs() {
        if !isProUnlocked {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -Self.freeLogRetentionDays, to: Date()) ?? Date()
            sendLogs = sendLogs.filter { $0.sentDate > cutoffDate }
            storageService.saveLogs(sendLogs)
        }
    }
    
    func exportLogsAsCSV() -> String {
        var csv = "Recipient Name,Template Name,Output Filename,Sent Date,Method\n"
        for log in sendLogs {
            let recipientName = escapeCSVField(log.recipientName)
            let templateName = escapeCSVField(log.templateName)
            let outputFileName = escapeCSVField(log.outputFileName)
            let sentDate = escapeCSVField(log.formattedSentDate)
            let method = escapeCSVField(log.method.rawValue)
            csv += "\(recipientName),\(templateName),\(outputFileName),\(sentDate),\(method)\n"
        }
        return csv
    }
    
    private func escapeCSVField(_ field: String) -> String {
        // Wrap field in quotes if it contains comma, quote, or newline
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            // Escape internal quotes by doubling them
            let escapedField = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escapedField)\""
        }
        return field
    }
    
    func removeTemplate() {
        self.pdfTemplate = nil
        storageService.saveTemplate(nil)
        
        // Clear related data for free tier
        if !isProUnlocked {
            clearMappingAndHistory()
        }
    }
    
    func replaceTemplate(_ newTemplate: PDFTemplate) {
        // For free tier, clear old data before replacing
        if !isProUnlocked {
            clearMappingAndHistory()
        }
        
        self.pdfTemplate = newTemplate
        storageService.saveTemplate(newTemplate)
    }
    
    private func clearMappingAndHistory() {
        // Clear recipients (CSV snapshot)
        self.recipients = []
        storageService.saveRecipients([])
        
        // Clear CSV import snapshot
        self.csvImport = nil
        storageService.clearCSVImport()

        // Clear CSV email column preference
        self.csvEmailColumn = nil
        storageService.saveCSVEmailColumn(nil)

        // Clear CSV display name column preference
        self.csvDisplayNameColumn = nil
        storageService.saveCSVDisplayNameColumn(nil)
        
        // Clear logs
        self.sendLogs = []
        storageService.saveLogs([])
    }
}
