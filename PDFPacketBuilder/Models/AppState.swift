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
    @Published var selectedEmailColumn: String? = nil
    @Published var selectedDisplayNameColumn: String? = nil
    @Published var senderName: String = ""
    @Published var senderEmail: String = ""
    @Published var mailDrafts: [MailDraft] = []
    
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
        self.selectedEmailColumn = storageService.loadSelectedEmailColumn()
        self.selectedDisplayNameColumn = storageService.loadSelectedDisplayNameColumn()
        self.senderName = storageService.loadSenderName()
        self.senderEmail = storageService.loadSenderEmail()
        self.mailDrafts = storageService.loadMailDrafts()
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

    func saveSelectedEmailColumn(_ column: String?) {
        let trimmed = column?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, trimmed.isEmpty {
            selectedEmailColumn = nil
            storageService.saveSelectedEmailColumn(nil)
        } else {
            selectedEmailColumn = trimmed
            storageService.saveSelectedEmailColumn(trimmed)
        }
    }

    func saveSelectedDisplayNameColumn(_ column: String?) {
        let trimmed = column?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, trimmed.isEmpty {
            selectedDisplayNameColumn = nil
            storageService.saveSelectedDisplayNameColumn(nil)
        } else {
            selectedDisplayNameColumn = trimmed
            storageService.saveSelectedDisplayNameColumn(trimmed)
        }
    }

    @available(*, deprecated, message: "Use saveSelectedEmailColumn")
    func saveCSVEmailColumn(_ column: String?) {
        saveSelectedEmailColumn(column)
    }

    @available(*, deprecated, message: "Use saveSelectedDisplayNameColumn")
    func saveCSVDisplayNameColumn(_ column: String?) {
        saveSelectedDisplayNameColumn(column)
    }

    func saveSenderName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        senderName = trimmed
        storageService.saveSenderName(trimmed)
    }

    func saveSenderEmail(_ email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        senderEmail = trimmed
        storageService.saveSenderEmail(trimmed)
    }
    
    func addSendLog(_ log: SendLog) {
        self.sendLogs.insert(log, at: 0)
        storageService.saveLogs(sendLogs)
    }

    func saveMailDraft(templateID: UUID, recipientID: UUID, date: Date = Date()) {
        // Overwrite any existing draft for this template+recipient.
        mailDrafts.removeAll(where: { $0.templateID == templateID && $0.recipientID == recipientID })
        mailDrafts.insert(MailDraft(templateID: templateID, recipientID: recipientID, savedDate: date), at: 0)
        storageService.saveMailDrafts(mailDrafts)
    }

    func clearMailDraft(templateID: UUID, recipientID: UUID) {
        let before = mailDrafts.count
        mailDrafts.removeAll(where: { $0.templateID == templateID && $0.recipientID == recipientID })
        if mailDrafts.count != before {
            storageService.saveMailDrafts(mailDrafts)
        }
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

        // Clear email/name column preferences
        self.selectedEmailColumn = nil
        storageService.saveSelectedEmailColumn(nil)

        self.selectedDisplayNameColumn = nil
        storageService.saveSelectedDisplayNameColumn(nil)
        
        // Clear logs
        self.sendLogs = []
        storageService.saveLogs([])
    }

    /// Clears app data for a clean slate.
    /// - Important: Does not modify Pro entitlement state and does not delete user-exported PDFs.
    func resetAllData() {
        // Template removal clears the disk-backed template PDF (app-managed) via StorageService.
        self.pdfTemplate = nil
        storageService.saveTemplate(nil)

        // Clear recipients + CSV import snapshot
        self.recipients = []
        storageService.saveRecipients([])

        self.csvImport = nil
        storageService.clearCSVImport()

        self.selectedEmailColumn = nil
        storageService.saveSelectedEmailColumn(nil)

        self.selectedDisplayNameColumn = nil
        storageService.saveSelectedDisplayNameColumn(nil)

        // Clear logs
        self.sendLogs = []
        storageService.saveLogs([])

        // Clear draft state (drafts are not sends)
        self.mailDrafts = []
        storageService.clearMailDrafts()

        // Clear sender settings
        self.senderName = ""
        storageService.saveSenderName("")

        self.senderEmail = ""
        storageService.saveSenderEmail("")
    }
}
