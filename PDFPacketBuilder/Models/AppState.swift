//
//  AppState.swift
//  PDFPacketSender
//
//  Central app state management
//

import Foundation
import SwiftUI

class AppState: ObservableObject {
    @Published var pdfTemplate: PDFTemplate?
    @Published var recipients: [Recipient] = []
    @Published var sendLogs: [SendLog] = []
    @Published var isPro: Bool = false
    
    private let storageService = StorageService()
    
    init() {
        loadState()
    }
    
    func loadState() {
        self.pdfTemplate = storageService.loadTemplate()
        self.recipients = storageService.loadRecipients()
        self.sendLogs = storageService.loadLogs()
        self.isPro = storageService.loadProStatus()
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
    
    func exportLogsAsCSV() -> String {
        var csv = "Timestamp,Recipient,Status,PDF Name\n"
        for log in sendLogs {
            let timestamp = log.timestamp.ISO8601Format()
            let recipient = log.recipientName.replacingOccurrences(of: ",", with: ";")
            csv += "\(timestamp),\(recipient),\(log.status),\(log.pdfName)\n"
        }
        return csv
    }
}
