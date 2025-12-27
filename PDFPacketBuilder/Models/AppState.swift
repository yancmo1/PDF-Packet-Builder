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
    @Published var isPro: Bool = false
    
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
        self.isPro = storageService.loadProStatus()
    }
    
    func canAddTemplate() -> Bool {
        return isPro || pdfTemplate == nil
    }
    
    func canGenerateWithRecipientCount(_ count: Int) -> Bool {
        return isPro || count <= Self.freeMaxRecipients
    }
    
    func saveTemplate(_ template: PDFTemplate) {
        self.pdfTemplate = template
        storageService.saveTemplate(template)
    }
    
    func saveRecipients(_ recipients: [Recipient]) {
        self.recipients = recipients
        storageService.saveRecipients(recipients)
    }
    
    func addSendLog(_ log: SendLog) {
        self.sendLogs.insert(log, at: 0)
        storageService.saveLogs(sendLogs)
    }
    
    func updateProStatus(_ isPro: Bool) {
        self.isPro = isPro
        storageService.saveProStatus(isPro)
    }
    
    func cleanOldLogs() {
        if !isPro {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -Self.freeLogRetentionDays, to: Date()) ?? Date()
            sendLogs = sendLogs.filter { $0.timestamp > cutoffDate }
            storageService.saveLogs(sendLogs)
        }
    }
    
    func exportLogsAsCSV() -> String {
        var csv = "Timestamp,Recipient,Status,PDF Name\n"
        for log in sendLogs {
            let timestamp = log.timestamp.ISO8601Format()
            let recipient = log.recipientName.replacingOccurrences(of: ",", with: ";")
            csv += "\(timestamp),\(recipient),\(log.status),\(log.pdfName)\n"
        }
        return csv
    }
    
    func removeTemplate() {
        self.pdfTemplate = nil
        storageService.saveTemplate(nil)
        
        // Clear related data for free tier
        if !isPro {
            clearMappingAndHistory()
        }
    }
    
    func replaceTemplate(_ newTemplate: PDFTemplate) {
        // For free tier, clear old data before replacing
        if !isPro {
            clearMappingAndHistory()
        }
        
        self.pdfTemplate = newTemplate
        storageService.saveTemplate(newTemplate)
    }
    
    private func clearMappingAndHistory() {
        // Clear recipients (CSV snapshot)
        self.recipients = []
        storageService.saveRecipients([])
        
        // Clear logs
        self.sendLogs = []
        storageService.saveLogs([])
    }
}
