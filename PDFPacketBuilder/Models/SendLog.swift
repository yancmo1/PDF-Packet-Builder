//
//  SendLog.swift
//  PDFPacketBuilder
//
//  Model for tracking sent PDFs
//

import Foundation

struct SendLog: Codable, Identifiable {
    let id: UUID
    var recipientName: String
    var templateName: String
    var outputFileName: String
    var sentDate: Date
    var method: SendMethod
    
    enum SendMethod: String, Codable {
        case share = "Share"
        case mail = "Mail"
    }
    
    init(id: UUID = UUID(), recipientName: String, templateName: String, outputFileName: String, sentDate: Date = Date(), method: SendMethod) {
        self.id = id
        self.recipientName = recipientName
        self.templateName = templateName
        self.outputFileName = outputFileName
        self.sentDate = sentDate
        self.method = method
    }
    
    // Helper to format sentDate as MM-DD-YY
    var formattedSentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yy"
        return formatter.string(from: sentDate)
    }
}

/// Tracks a mail draft save (not a send).
struct MailDraft: Codable, Hashable, Identifiable {
    let id: UUID
    let templateID: UUID
    let recipientID: UUID
    let savedDate: Date

    init(id: UUID = UUID(), templateID: UUID, recipientID: UUID, savedDate: Date = Date()) {
        self.id = id
        self.templateID = templateID
        self.recipientID = recipientID
        self.savedDate = savedDate
    }

    var formattedSavedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "MM-dd-yy"
        return formatter.string(from: savedDate)
    }
}
